# Evidence dossier: frozen specification (2026-09-26)

This document freezes the discovery layer (Jev claims, static candidates and narrow Gemini investigators) after developing it on Pulse. From here on, nothing below changes in response to the unseen validation project.

## Frozen files and settings

| Item | Value |
|---|---|
| `static_checks.py` | `VERSION = static-5`, sha256 `70e118617aaa5b9e` |
| `claims.py` | `VERSION = claims-1`, sha256 `6255ea847822e90c` |
| `dossier.py` | `VERSION = dossier-6`, sha256 `f348fd0c49496474` |
| `generate.py` (supplies the shared context `facts_text` and the `CITE` schema) | sha256 `1d80c75630ef238e` |
| `ground.py` (supplies `resolve`, which checks citations) | sha256 `5348c5157fe74e00` |
| `routing.json`, profile `dossier` | sha256 `4cbc14701a3e0e8d`:<br>`observe`: Gemini 3.8 Flash, medium thinking<br>`investigate`: Gemini 3.8 Flash, low thinking<br>`investigate-deep`: Gemini 3.8 Flash, medium thinking |
| Limits | `MAX_ITEMS = 45` per investigator; `MAX_PER_CHECK = 25` candidates per static check; medium thinking (`DEEP`) for `paths` and `dataflow` |

## Layers

1. **Jev: what the team says** (`claims.py`). The pilot's numbered writeup lines, with Jev's existing kind and one new Choice per non-context line: the topic the line makes a claim about. Topics: core_capability, user_workflow, ai_model, sponsor_tech, integration, data_or_scale, unfinished, other. Jev only classifies; it never judges importance or truth.
2. **Static: what the code contains** (`static_checks.py`). Candidates, not conclusions, each with file and line:
   - `jobs.registeredNeverScheduled`, `jobs.scheduledNeverRegistered`
   - `values.comparedNeverWritten`: a literal compared in an ORM `where`, never written to a field of that name
   - `classes.unreferenced`: a *Service/*Client/*Repository/... class no other file refers to
   - `ui.emptyHandlers`: grouped per file, with button labels where visible
   - `endpoints.neverCalled`: public endpoint methods the app never calls
   - `config.optionalNeverSupplied`: an optional key or token parameter no construction site passes
   - `tables.writtenNeverRead`, `tables.readNeverWritten`: Serverpod 1.x and 2.x ORM and raw SQL; "never written" is claimed only if every write resolved
   - `external.calls`: outbound hosts
   - `demo.textNotInRepo`: on-screen demo text with no matching string literal

   An inventory (jobs, table writes and reads, unresolved writes, hosts) feeds the investigators' item lists.
3. **Gemini: narrow investigations** (`dossier.py`). Five investigators. Each answers a fixed proposition per given item: supported, contradicted or unresolved, with verbatim citations and one neutral sentence. There is no merit judgement and no judge-facing prose.

   | Investigator | Items | Proposition | Thinking |
   |---|---|---|---|
   | claims | Jev claims, excluding plans and unfinished | the claim is implemented, all of it | low |
   | candidates | static candidates, except demo text | the candidate is real at runtime (contradicted = false positive) | low |
   | paths | each app call with every call site; each scheduled job | a call site is reached, and the path reaches its endpoint, services and storage, and the data it needs exists | medium |
   | dataflow | each table or model (write and read sites), each external host | what is produced is produced by code that runs and consumed with compatible types and values | medium |
   | demo | each changed frame; each unmatched on-screen string, as a neutral subject | code in the repository produces what is shown | low |

   All five share one context: the same writeup, frame observations, repository facts and excerpts the Claude generator sees. The first call runs alone so Gemini's implicit cache can serve that context to the other four, which run in parallel. Every citation goes through `ground.resolve()`. A non-unresolved answer without a valid citation becomes unresolved, and an unanswered item is recorded as unresolved.

## What changed during Pulse development

All changes are generic; none names Pulse's files or identifiers.

| # | Change | Why |
|---|---|---|
| 1 | Private `_methods` excluded from `endpoints.neverCalled` | They are not endpoints; 3 false positives |
| 2 | Table names normalized (case, `_`, plural) | ORM model name ≠ SQL table name gave a false "read never written" |
| 3 | Serverpod 1.x ORM patterns (`db.find<T>`, `db.insertRow(x)` with the declared type) | 1.x repositories showed no writes at all |
| 4 | "Never written" claimed only when every write resolved | A loop-variable insert can't be typed statically |
| 5 | 2.x pattern requires a capitalized model (`Model.db`) | `session.db` was read as a table |
| 6 | Path items list every call site | With only the first site (a provider wrapper), Gemini reported "never invoked" while the drawer calls the endpoint directly |
| 7 | Unanswered items recorded; echoed item text normalized to its ID | Gemini returned 12 of 13 dataflow items once, and full item lines as IDs |
| 8 | Thinking: low for claims, candidates and demo; medium for paths and dataflow | All-medium cost $0.87. All-low cost $0.41 but lost cross-item consequences ("conflicts can never fire", "graph never filled") and contradicted its own candidate findings. |
| 9 | Paths proposition: tried wiring-only, reverted to wiring plus data | Wiring-only was cleaner but lost the `.gz` finding and "stream never posted to". Recall is preferred over repetition, which synthesis can dedupe. |
| 10 | Demo text items stated as neutral subjects | Worded as the check's claim, Gemini inverted the polarity ("supported" meaning the text is absent) |

## Pulse regression result (frozen version)

| Known finding (from the Claude baseline) | Recovered | Where |
|---|---|---|
| Demo behaviour not represented in the repository | **Mostly.** The quick-action alerts are, via their empty handlers. The chat reply's wording mismatch is not (found at medium thinking in development, not at low). | demo F010, F013, F016, F022, S28, S29, S31 |
| Conflict detection expects a `decision` node type no importer writes | **Yes** | candidate S02 confirmed; paths P08; dataflow T04 ("detectConflicts always returns an empty list") |
| GitHub events never become graph nodes | **Yes**, both causes | S00 confirmed (`processKnowledgeGraph` never scheduled); T01; J00 (`.json.gz` split as text) |

**Findings neither Claude run made:**

- `markAsRead` is never invoked (P10).
- The notification stream is never posted to (P11).
- The debt report's `as double` cast throws on the integer 0 (development run only).
- The claimed isolates are not used by the scraper.
- Test coverage is claimed but not part of the debt score.

**Found by Claude and not by the dossier:** the MySQL-style `INDEX` clauses inside `CREATE TABLE`. No investigator is asked about schema validity.

**Noise seen:**

- Two path findings say an endpoint "is never called from any UI" when the command palette calls it; the verdict holds (no data) but the sentence is partly wrong.
- One demo string was attributed to a dashboard card although it appeared inside a browser alert.
- Results vary from run to run: the `.gz` finding appeared in 3 of 4 paths runs.

**Cost of the frozen configuration on Pulse (list price):**

| Item | Cost |
|---|---|
| Jev | $0.001 |
| Gemini observation | $0.045 |
| claims | $0.18 (the first call, which fills the cache) |
| candidates | $0.05 |
| demo | $0.08 on an implicit-cache hit, $0.19 on a miss |
| paths | about $0.21 |
| dataflow | $0.13 |
| **Dossier total** | **about $0.70–0.80** |

That is above the $0.20–0.45 assumed in the design; thinking tokens dominate.
