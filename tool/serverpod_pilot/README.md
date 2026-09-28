# Serverpod triage pilot

Builds the Serverpod triage data from all 117 submissions to *Build your Flutter Butler with Serverpod* (<https://serverpod.devpost.com/project-gallery>). The app bundles only the output. It makes no network calls.

```sh
cd tool/serverpod_pilot
python3 fetch_devpost.py          # sample + Devpost pages      → data/devpost.json
python3 deterministic_signals.py  # links, git, repo analysis   → data/deterministic.json
                                  # existing rows are kept; --refresh-code re-reads their repos at the snapshot
python3 jev_extract.py            # Jev extraction (cached)     → data/jev.json
python3 build_dataset.py          # merge                       → finalist_brief_flutter/assets/triage/
```

Python standard library only. Raw pages, clones, templates and Jev responses are cached in `.cache/`, which git ignores. Re-running a step reuses the cache.

## Sample

The sample is every gallery slug, ordered by SHA-1 (`SAMPLE_SIZE` in `common.py` is 117; it started at 15 and grew in batches to 64 and then the full field, keeping every existing row). That order is reproducible and does not depend on gallery order, prizes or likes. Winner badges, likes and comments are never recorded. Submissions with no repository, a 404, no or a private demo, or a placeholder writeup stay in the dataset; the app names the missing evidence instead.

## Deterministic signals (`deterministic_signals.py`)

- **Access:** the repository link (`git ls-remote`), the demo video (YouTube/Vimeo oEmbed status) and any live links, checked on 2026-09-24.
- **Snapshot:** the last commit on the default branch before the deadline (2026-01-30 16:00 UTC). All repository signals come from this commit, even when later commits exist.
- **Commit timing:** commits before the submission window opened, during it and after the deadline; active days; how long the history spans.
- **Scaffold delta:** non-blank code lines beyond the exact `serverpod create` template for the pinned Serverpod version, downloaded from pub.dev as `serverpod_templates`. The mini and full variants are both compared. Generated code, migrations and Flutter platform runners are excluded. Template files left untouched count zero; edited template files count only their added lines.
- **Serverpod footprint:** models and tables (from `.spy`, `.spy.yaml` and `.spy.yml` files, the extensions Serverpod reads), endpoint classes and methods, streaming methods, future calls, Serverpod auth, file uploads, caching, migrations, and whether generated protocol code is committed. It also records which `endpoint.method` calls the Flutter app makes against this server's own endpoints (`endpoint_calls`, shared with `tool/deep_review`). A call counts when the client's endpoint is used directly (`client.summary.listSummaries(`, across line breaks too) or through a holder: a variable or provider typed as the generated `Endpoint<Name>` class, assigned from the client, or read from such a provider, and only for a method of that endpoint. A provider read into a local variable (`final endpoint = ref.read(goalEndpointProvider);`) binds only in that file, and a call uses the nearest earlier binding, since teams reuse one name such as `endpoint` for different endpoints. Calls in app files that nothing reachable from `lib/main*.dart` imports do not count, because that code never runs. Relative imports resolve as Dart does for files under `lib/`: `..` stops at `lib/`, so `lib/screens` + `../../widgets/x.dart` is `lib/widgets/x.dart`.
- **Composition:** lines by area (server, app, other) and by language. Also records test files and cases, model-provider SDKs or endpoints referenced in code, other backends such as Firebase, and Serverpod dependencies missing from pub.dev.

README length, writing quality, stars, forks and popularity are never read.

## Jev extraction (`jev_extract.py`)

[Jev](https://docs.typesafe.ai) answers typed Choice and Noul questions. It does not generate text. Code splits each writeup into numbered lines (`L000|`), keeping the section headings. Jev then answers:

- a profile: area, how the butler helps, the AI's role and provider, and how specifically Serverpod is described;
- whether the writeup mentions databases, real-time updates, scheduling, sign-in, uploads, Serverpod Cloud or tests;
- whether it admits unfinished work, and on which line;
- a classification for every line: capability, implementation, outcome, plan or context.

Every question asks what the writeup *says*. None asks whether the project is good. Counting, thresholds and all comparison with the repository happen in code. The model is pinned to `jev-1.13.0`; the 117 writeups used about 2.0M input tokens.

## What the app derives

Lanes (Substantial build, Distinctive idea, Under-told, Unresolved) and the judge questions are computed in `finalist_brief_flutter/lib/triage/lanes.dart`. They use named thresholds, so every assignment can explain itself in the UI. No composite score exists.

## Deep reviews

`finalist_brief_flutter/assets/representations/serverpod.json` holds 31 deep reviews: four written by hand, like the Humor Genome data (Bitcoin Butler, DOBY, Elderly and Social Fabric), and twenty-seven generated by [`tool/deep_review/`](../deep_review/README.md). Each is based on the writeup, the repository at its deadline snapshot (source links pin that commit), and public demo frames checked at the cited timestamps. Frames live in `assets/evidence/serverpod/`.

Known blind spots: third-party packages copied into an app's `lib/` count as repository lines, since nothing tells copied code from the team's own. Crewboard vendors an image editor (about 148k of its +211k lines); its lanes do not depend on that, but its line count is inflated. Also, the scaffold delta skips Flutter platform runner files by name, so custom native code written into `MainActivity.kt` is not counted. Contextual LifeFlow Butler's 424-line `MainActivity.kt` holds its alarm and ringer logic. The triage data is unchanged; `tool/deep_review/repo_facts.py` reads such files.
