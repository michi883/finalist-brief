# A/B 2: Gemini 3.8 Flash at high thinking on Pulse (2026-09-26)

**Question.** Does high thinking fix the synthesis weakness Gemini showed at medium thinking in [A/B 1](2026-09-26-pulse-ab.md)?

**Answer.** No. Gemini-high surfaced none of the three cross-file findings. Its summary also presents demo behaviour that has no code behind it as working product features. It fails the pass condition, and Gemini is no longer being evaluated for `generate`.

## Setup

- **Frozen pipeline.** No prompts, rules, schemas or verification were changed.
- **Profile `gemini-high`** in `routing.json` (not the default):
  - `observe`: Gemini 3.8 Flash at medium thinking. This is the same route as A/B 1, so it reused A/B 1's cached observation (key `30aa5dcc1bb14e19`), identical and costing nothing.
  - `generate` and repairs: Gemini 3.8 Flash at **high** thinking.
  - `verify`: Claude Opus 5.5.
- `--no-publish`.
- **Baseline.** The frozen Claude run from A/B 1, not re-run.
- **Pass condition.** Surface at least 2 of 3 findings:
  - F1: the demo's alerts and chat reply are not in the repository.
  - F2: conflict detection expects a `decision` node type that no importer writes.
  - F3: GitHub events never become graph nodes, because processing is never scheduled and the `.json.gz` is never decompressed.

  It must also introduce no evidence errors and keep a clear summary, useful graphs and specific questions.

## Measurements

| | Claude baseline (A/B 1) | Gemini-medium (A/B 1) | **Gemini-high** |
|---|---|---|---|
| observe | $0.095 · 10.3k in / 2.2k out | $0.045 · 18.9k / 2.2k | cached from Gemini-medium: $0 spent ($0.045 list) |
| generate | $2.186 · 3 calls · 343.7k in / 27.6k out | $0.389 · 3 calls · 264.1k (164.6k cached) / 28.7k | **$0.477 · 2 calls · 175.5k in (82.3k implicit cache) / 43.3k out** |
| verify (Opus 5.5) | $0.343 · 3 calls | $0.120 · 2 calls | **$0.143 · 2 calls · 14.0k in / 3.7k out** |
| **Total (list)** | **$2.63** | **$0.55** | **$0.67 ($0.62 new spend)** |
| Calls · repairs · retries | 7 · 2 · 0 | 6 · 2 · 0 | **5 · 1 · 0** |
| Elapsed | 295 s | 119 s | **155 s** (plus the cached observation) |
| Verifier objections | 4 + 4 | 10 (8 claims) | **12 (11 claims) on draft 1, 0 on draft 2** |
| Final: dropped / capped / lowered | 0 / 0 / 0 | 0 / 0 / 0 | **0 / 0 / 0** |
| Final: Demonstrated / Found in code / Described / Inferred | 1 / 10 / 6 / 0 | 1 / 7 / 5 / 0 | **2 / 7 / 4 / 3** |
| Shape | 6 + 6 nodes, 4 obs, 4 questions | 5 + 5, 3, 3 | **5 + 6, 4, 4** |

High thinking produced 51% more output tokens than medium. The review that came out was different, but it went no deeper.

## Blind three-way review

A fresh reader saw only the three reviews under random labels (P = Gemini-medium, Q = Claude, R = Gemini-high), plus the sources and Social Fabric as the clarity reference. It first verified F1–F3 against the repository and frames and found all three true. The labels were unsealed after the verdict.

| | F1 demo ≠ repo | F2 `decision` type | F3 graph never filled |
|---|---|---|---|
| Claude | **Yes.** Judge question on empty sidebar handlers, browser alerts and the chat format. | **Yes.** Integration node and judge question. | **Yes.** Judge question; node detail "Raw events only". |
| Gemini-medium | Partly, in a placement note only | No | No |
| Gemini-high | Partly, in a placement note only | No | **No, and contradicted.** "background future calls for scraping, processing, and embeddings" and the edge "schedules jobs". |

| Criterion | Ranking |
|---|---|
| Summary | Claude > Gemini-medium > Gemini-high. Gemini-high's "triggers conflict and debt reports" presents alert dialogs with no code behind them as features. |
| Idea graph | Claude ≈ Gemini-medium > Gemini-high. Gemini-high drops the Q&A/RAG feature and puts a `[demonstrated]` node in the idea graph. |
| Integration graph | Claude > Gemini-high > Gemini-medium. Gemini-high's "Slack & Jira code / Not in runtime" node is useful, but its hub node overstates the background jobs. |
| Observations | Claude > Gemini-high ≈ Gemini-medium |
| Judge questions | Claude > Gemini-high > Gemini-medium. Gemini-high's four questions mostly restate its observations; Claude's are cross-file. |
| Overall | **Claude > Gemini-medium > Gemini-high.** Gemini-medium is thinner but accurate. Gemini-high is "mildly misleading, not merely thinner". |

**Evidence spot-checks.**

- Claude: 6 of 7 supported, 1 partial. The scraper node says it "inserts GitHub events", which its own gzip finding undercuts.
- Gemini-medium: 5 of 7 supported, 2 partial.
- Gemini-high: 6 of 9 supported, 2 partial, 1 unsupported. Its placement note says "Demo shows the Flutter app querying knowledge nodes"; the reply matches no template in the repository. It marks the Slack/Jira finding `inferred` although it can be checked directly: understated, not wrong.

**Correction to A/B 1.** A/B 1's reader said the root `init.sql` has no `vector(384)` column, and rated Gemini-medium's Postgres citation partial on that basis. That was wrong: the column is on line 45. This round's reader rated the same citation supported. A/B 1's decision does not depend on it.

## Decision

Gemini-high fails:

- 0 of 3 findings, against a requirement of 2;
- a misleading summary;
- an unsupported placement claim.

A cost of $0.67 against $2.63 does not make up for that. **Stop trying to replace Claude for `generate`.** The default routing is unchanged (`claude-baseline`). The `gemini-first` and `gemini-high` profiles stay in `routing.json` for the record.

## Next cost target inside the Claude pipeline: repair calls

In the Claude arm, repairs are 55% of Pulse's cost ($1.44 of $2.63) and 53% of Butler's. Each repair re-sends the full evidence context (104–111k tokens), paying the 5-minute cache-write price ($5/M) every time, and never reads it back from the cache.

Probes through the pipeline's exact CLI flags, on fresh 27–32k-token prompts:

| Probe | Haiku 4.5 | Opus 5.5 |
|---|---|---|
| Exact repeat of the draft request | cache hit | cache hit (32,380 read) |
| Draft request + one appended block (the repair shape), immediately | **cache hit** (27,544 read) | **miss** (0 read) |
| Same after a 90 s gap and a different-prompt call | not tested | **miss** |

So on Opus 5.5 through the CLI, a repair that extends the draft request pays full price. Only an exact prefix is read back. The mechanism was not verified; the measurement is what matters here.

Proposed next change: run the draft and its repairs as **one multi-turn CLI session**. The first user turn carries the context, the model's draft is the assistant turn, and the problems are the second user turn. The cached prefix then matches exactly, which is how the CLI's own conversations get their cache hits.

- **What it saves:** at Pulse's size, each repair's context read drops from about $0.52 to $0.02. The review falls from about $2.63 to about $1.65 (−37%), and Butler from $2.12 to about $1.40. Nothing the model sees changes: the same context, draft and problems, in turn order.
- **How to test it:** replay-compare on the next unseen submission, looking for no change in the grounding outcome and cache reads on every repair.

A second, independent lever: in both Claude runs, the verifier's objections were mostly "the cited range does not include the body". Widening code citations deterministically to the enclosing method before verification could prevent those repairs. That changes what the verifier sees, so it needs its own A/B on an unseen submission, not Pulse.

## Costs of this round

| Item | Cost |
|---|---|
| Gemini-high arm (new spend) | $0.62 |
| Cache probes (Haiku and Opus) | about $0.72 |
| Blind-review agent session | development usage, not pipeline cost |
