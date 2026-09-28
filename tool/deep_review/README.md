# Automatic deep reviews

Generates one Finalist Brief deep review (summary, Idea and Integration graphs, Idea → Integration observations, evidence, judge questions) from a Serverpod submission's writeup, repository and demo, with no hand-authoring.

```sh
cd tool/deep_review
python3 run.py contextual-lifeflow-butler   # all stages
python3 ground.py contextual-lifeflow-butler  # or any single stage
python3 run.py <id> --profile gemini-first --no-publish --from extract   # an A/B variant
python3 costs.py contextual-lifeflow-butler   # tokens and cost of the latest run
```

Needs Python 3 (standard library), `git`, `yt-dlp`, `ffmpeg`, the `claude` CLI signed in, and `GEMINI_API_KEY` in the root `.env` for Gemini routes. It reuses the pilot's Devpost data, clones and Jev line classification in `tool/serverpod_pilot/`. Everything else is cached in `.cache/<id>/`, which git ignores: deterministic outputs (sources, repository facts, frames) at the top, model-dependent ones (extract, draft, grounded, provenance, representation, the call ledger) in `runs/<profile>/`. Model responses are cached in `llm/` by a hash of the full request including the model, so a re-run with unchanged inputs makes no calls and gives the same result. `DEEP_REVIEW_CACHE_ONLY=1` turns any uncached call into an error, which replays a run at no cost.

## Stages

| Stage | Module | Model route | Output |
|---|---|---|---|
| Source acquisition | `acquire.py` | no | writeup, repository exported at the last commit before the deadline, demo video, captions, one frame every 3 s |
| Repository analysis | `repo_facts.py` | no | endpoint methods and which the app calls (from Dart, through the triage pipeline's shared `endpoint_calls`, or from native code over HTTP), which app files can run, models, Flutter ↔ native channels, platform permissions, markers (TODO, mock, simulate, hard-coded IDs), line-numbered excerpts |
| Demo and writeup extraction | `extract.py` | `observe` (frames only) | literal per-frame observations from a pass that never sees the writeup or narration; writeup lines reuse the triage pipeline's `L000` IDs |
| Semantic generation | `generate.py` | `generate` (draft and repairs) | a draft that cites writeup lines, code ranges with verbatim quotes, frames and narration. It never writes references directly |
| Evidence and provenance | `ground.py` | `verify` (verifier only) | resolved references, status ceilings, independent verification, `provenance.json` |
| Rendering hand-off | `publish.py` | no | the entry in `assets/representations/serverpod.json` with `origin.method = "generated"`, plus the cited frames |

The prompts are generic: nothing in them describes a particular submission. Tone examples come from the other deep reviews as phrases, never as graphs.

## Model routing

[`routing.json`](routing.json) names a provider and a pinned model for each of the three model stages. Profiles:

| Profile | observe | generate | verify |
|---|---|---|---|
| `claude-baseline` (default) | `claude-opus-5-5` | `claude-opus-5-5` | `claude-opus-5-5` |
| `gemini-first` (not adopted) | `gemini-3.8-flash`, medium thinking | `gemini-3.8-flash`, medium thinking | `claude-opus-5-5` |
| `gemini-high` (not adopted) | `gemini-3.8-flash`, medium thinking (same route, so the cache is shared) | `gemini-3.8-flash`, high thinking | `claude-opus-5-5` |

Two A/Bs on Pulse kept `claude-baseline`: [medium thinking](experiments/2026-09-26-pulse-ab.md) and [high thinking](experiments/2026-09-26-pulse-ab-2-gemini-high.md). Gemini cost $0.55–0.67 against Claude's $2.63, but its generation stage found none of the three cross-file findings a judge needs.

A proposed lower-cost architecture, with Gemini investigators feeding Claude synthesis, is in [`design/2026-09-26-cascade-architecture.md`](design/2026-09-26-cascade-architecture.md).

Select one with `--profile` or `DEEP_REVIEW_PROFILE`, or reroute a single stage with `DEEP_REVIEW_<STAGE>=<provider>:<model>` (for example `DEEP_REVIEW_VERIFY=claude-cli:claude-sonnet-5`). Providers:

- `claude-cli`: `claude -p` with no tools, settings or MCP servers and a replaced system prompt. The draft and its repairs run as one live multi-turn session (`common.ClaudeSession`), so each repair reads the context from the prompt cache instead of re-sending it. The CLI retries API errors itself; the pipeline does not. It runs with `DISABLE_PROMPT_CACHING=1`. No call here is ever read back from the cache (even the repair loop's shared prefix missed), and without the flag the CLI writes every prompt to a 1-hour cache at 2× the input price. With it the write is a 5-minute one at 1.25×.
- `gemini`: the Gemini API over HTTP with a JSON-schema-constrained reply. It retries 429, 5xx and timeouts with exponential backoff (at most 5 attempts). The repair loop's repeated prefix gets Gemini's implicit-cache discount.

Whatever the route, the verifier is the gate: it sees only each claim and its cited frames or lines, and it can only lower a status. The `gemini-first` profile keeps it on Claude, so a cheaper drafting model is still checked by an independent, stronger one from another model family. Citation resolution, status ceilings and readability limits are deterministic code and do not depend on the route.

`publish.py` records the routes in the entry's `origin.models`.

The verifier stores each verdict under a fingerprint of the verifier model, the claim's note and the exact evidence shown (`llm/verdicts.json`); only new or changed claims are sent again.

The `dossier` profile (`static_checks.py`, `claims.py`, `dossier.py`) builds an evidence dossier without writing a review. It was tested and not adopted ([record](experiments/2026-09-26-dossier-validation.md)).

## Cost

Every call, cached or not, is appended to `runs/<profile>/calls.jsonl`. `costs.py <id>` reports the latest run by stage; `--all` also sums every cached response, including those from earlier pipeline versions. Claude costs are the CLI's reported `total_cost_usd`. Gemini costs are computed from the list prices in `routing.json`. The root README's *Operating cost* section has the measured and projected numbers.

## Why a status can be trusted

1. **Citations are checked against the sources.** A writeup quote must appear on its line. A code quote must exist in that file at the deadline snapshot, and its line numbers are corrected to where it actually is. A demo citation must name a frame the observer saw. Narration must quote captions near its timestamp.
2. **Ceilings.** Demonstrated needs a demo frame; narration never counts. Found in code needs a verified quote. Described needs a writeup or narration quote. Anything unsupported falls to the strongest tier that is supported.
3. **Independent verification.** A second call sees only each claim and the exact frames and code lines it cites, and answers yes or no for each. Judge questions are checked too: their basis must match the cited evidence. A "no" goes back to the generator as a repair request: cite the full range, narrow the note, or lower the status. In the final grounding, a "no" can only lower a status, and a question whose basis is refuted is dropped. Verification fails closed: verifier IDs are matched tolerantly ("q1", "mapping-offline"), a claim left without a verdict is sent once more, and if it still has none it is lowered (or its question dropped) as if refuted. Recovered and unmatched IDs are logged in `provenance.json`. `python3 -m unittest discover tests` covers this.
4. **Absence and attribution.** Demo frames are samples, so any judge-facing sentence saying the demo does not show something is sent back for rewording ("not observed in the sampled frames"). `repo_facts.py` marks app files that nothing reachable from `lib/main*.dart` imports, and endpoint methods the app never calls; citing either is sent back unless the text says the code is unused. When there are no frames, the generator is told why in words a review can repeat: no demo linked, the linked video is private, or it is no longer available (from the triage link check, which acquire carries over when the download fails), or the download failed. Live links are shown with the triage check result ("unreachable, HTTP 404 when checked"), so a dead link is never described as a live deployment.
5. **Secrets are never repeated.** After every citation has been checked against the original source, `redact.py` replaces secret-like values in all judge-facing text with `[redacted]`: known credential formats (`AIza…`, `sk-…`, GitHub and AWS tokens, JWTs, private keys), quoted literals assigned to names such as key, secret, token, password or IV, and fallback values (`?? '…'`, a returned literal) in a statement or function named for a key, secret, token, password, credential or encryption. Lookup names (`passwords['k']`, `getPassword('k')`, `'session_token'`), placeholders, mocks, messages, addresses, paths, URLs and interpolated strings are left alone. The provenance log is redacted the same way; `tests/test_redact.py` covers the rules. Separately, incidental personal contact details seen in the demo (a phone number with a country code or in a formatted style, a full email address) are replaced with `[phone number]` or `[email address]` in judge-facing text; addresses the team put in its own code or writeup and placeholder domains stay, and frames are not changed (`tests/test_contacts.py`). The finding stays ("key hard-coded in repo"); the value does not. Verification never sees redacted text.
6. **Readability rules are enforced, not suggested.** These are the limits `test/serverpod_test.dart` checks (≤ 6 nodes, label ≤ 22 characters, ≤ 4 observations, and so on), plus rules derived from the renderer: a graph description of at most 110 characters, and at most one edge that skips a step. Violations go back to the generator, at most three times.

The app labels a generated review **Generated automatically**, with a tooltip saying no person reviewed it.

## Limits

- Placement in the Competition View (the four dimensions) is the model's judgement relative to the other reviews' notes. It is the least grounded part.
- Evidence depends on what the frames show. A behaviour that is only audible (a vibration, a ringer change) cannot be Demonstrated, and statuses fall back to Found in code.
- Automatic captions can mishear names. Narration is cited only as Described.
- Repositories beyond about 240k characters of relevant source are cut to a budget, and anything not shown is listed in the prompt.
