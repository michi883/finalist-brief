# Cheap breadth, expensive judgement: a lower-cost deep-review architecture

*Design only, 2026-09-26. Nothing here is implemented, and routing is unchanged.*

**Question.** How can Finalist Brief use Gemini for cheap breadth and Claude for expensive, judgement-critical synthesis, without losing the findings that matter to judges?

**Baseline to preserve.** The Claude pipeline: measured at $2.63 on Pulse, $2.12 on Butler (repriced at the 5-minute cache-write price).

**Target.** Under $1 per review ideally; under $1.50 if quality is essentially unchanged. List prices only, and no development-agent usage or promotional credit is counted.

## 1. What the evidence says

**From the Pulse A/Bs** ([A/B 1](../experiments/2026-09-26-pulse-ab.md), [A/B 2](../experiments/2026-09-26-pulse-ab-2-gemini-high.md)):

| Observation | Implication |
|---|---|
| Gemini `observe` matched Claude frame by frame, but copied less on-screen text (1 of 3 pairs at t=16; missed a sentence at t=46). | Gemini suits narrow, literal work. Text fidelity matters if demo text is matched against code. |
| Gemini `generate` produced accurate claims but found none of the three cross-file findings, at medium or at high thinking. High thinking produced 51% more output and no more insight. | The failure is not reasoning budget. The open-ended task (read about 80k tokens, decide what matters) is the problem. |
| Gemini-high's summary presented alert-only demo actions as features. | Framing and judge-relevance are judgement. Keep them with Claude. |
| The Opus verifier caught every unsupported claim in all arms, but it can only lower a status. | Verification protects correctness, not coverage. Omission is the risk to design against. |
| Every Claude verifier objection was of the kind "the cited range doesn't include the body or callee". | Most repairs come from citation scope, not from content. |

**Where the money goes** (Claude arm, Pulse):

| Item | Cost | Share |
|---|---|---|
| Two repairs, each re-sending 104–111k tokens uncached | $1.44 | 55% |
| First draft | $0.75 | 29% |
| Verifier | $0.34 | 13% |
| Observation | $0.10 | 4% |

**What the generation context is made of:**

| Submission | Share that is raw source excerpts | Excerpts |
|---|---|---|
| Butler | 77% | 147k characters |
| Pulse | 83% | 213k characters |

**Measured fixed costs of Opus in the loop:**

- about $0.20 of output per full review written;
- about $0.25 of verification per review.

Any design that keeps Opus writing the review and verifying it has a floor of about $0.65 before input and before any Gemini work. **Under $1 is reachable only if Claude's input shrinks to about 30–40k tokens and repairs become rare and small.**

## 2. Decomposing the generate stage (Q1, Q2, Q7)

The generate stage today does detection (find what's true, absent or contradictory across sources) and judgement (decide what matters, frame it, shape the graphs, ask). Pulse shows Gemini fails at the combination, not necessarily at detection when the question is narrow. The proposal: turn detection into **deterministic candidates plus local Gemini adjudication**, and keep judgement with Claude.

| Task | Who | Why |
|---|---|---|
| Endpoint defined vs called by the app; models, tables, channels, permissions, markers | deterministic (exists in `repo_facts.py`) | Already static |
| Future call registered vs ever scheduled | **deterministic** (new) | Two regexes. The prototype flagged only Pulse among 10 repos. |
| Service/client class declared vs ever referenced | **deterministic** (new) | Flags on 4 of 10 repos (see below). A lead, not a finding: Gemini adjudicates "unused" vs "reflection or dead code". |
| Value compared in an ORM `where` vs values ever written to that field (producer ↔ consumer) | **deterministic candidate → Gemini adjudicates** | Hits on 4 repos. Interpolated strings and enum writes make false positives, so each needs a local look. |
| Empty UI callbacks bound to actions | **deterministic** (new) | Hits on 6 repos; Pulse's carry their button labels ("Search Knowledge", "Resolve Conflict") |
| Optional credential never passed at any construction site (so the fallback always runs) | **deterministic candidate → Gemini** | Hits on Pulse. `copyWith` noise is easy to exclude. |
| Demo on-screen text vs repository string literals | **deterministic candidates → Gemini classifies** each unmatched string (user input / runtime data / library UI / app text that should be in the code) | Rates alone don't separate demos: Butler 30% vs Pulse 42% unmatched. Classification does. |
| Writeup claim → implementing location or "not found" (claim ledger) | **Gemini**, one claim batch per call, with Jev's line kinds and a file/symbol index | Local lookup per claim; Jev already marks the capability and implementation lines |
| Feature entry point → reachable runtime path (UI action → client call → endpoint → service → storage) | **Gemini**, one call per entry-point group, given the call graph facts and the relevant method bodies | Local tracing |
| Artifact produced → consumed downstream (tables, files, graph nodes) | **deterministic** writes and reads per table, then **Gemini** on gaps | |
| Background jobs, external APIs, model calls: configured vs executed | deterministic facts, then **Gemini** to confirm | |
| Sponsor-technology role | deterministic (exists) + Gemini one-liner | |
| Candidate Idea nodes from the writeup | **Gemini** | Grounded in Jev-classified lines |
| Candidate Integration nodes and Idea → Integration mappings | Gemini *may propose*; **Claude decides** | Topology and compression are judgement; Gemini-high's graph drifted |
| Which findings matter to a judge; contradictions ranked | **Claude** | Pulse: the decisive difference |
| Summary, final topology (≤ 6 nodes), observations, judge questions | **Claude** | Framing failures were Gemini's worst errors |
| Resolving disagreements between investigators, or between an investigator and a deterministic fact | **Claude** | Needs cross-source weighing |
| Verification (claim vs cited frames and lines) | **Claude Opus, unchanged** | The trust gate |

**Prototype of the new static checks.** These are regexes over the 10 pilot clones (HEAD, not deadline snapshots). They're a feasibility check, not pipeline code. Several were inspired by Pulse, so Pulse hits prove nothing; hits elsewhere and quiet repos matter more.

| Check | Repos with hits | Notes |
|---|---|---|
| Future call registered, never scheduled | 1 (Pulse) | No noise seen |
| Service class never referenced | 4 | Includes glowcare's `GeminiIngredientExtractionService` and skinaware's `OllamaService`: potential AI claims with no wiring. These are leads. |
| Empty labelled UI callbacks | 6 | lifesync 15, skinaware 18: needs grouping per screen |
| Compared value never written | 4 | One false positive (an interpolated URL). doby `triggerType==email`, lifesync `status==completed` and vaultnbinder `filingStatus==unfiled` need adjudication. |
| Optional credential never passed | 3 | 2 were `copyWith` false positives; exclude those |
| Contextual LifeFlow Butler, Social Fabric | nothing | Quiet on the two repos whose reviews found no such gaps |

Conclusion for Q7: static checks generate **candidates** cheaply and generically. About a third need a local look to rule out false positives, which is exactly Gemini's strength. None of them decides relevance to a judge.

## 3. Candidate architectures

The costs below are Pulse-sized at list price, and derived from measured unit costs:

| Unit | Price or measured cost |
|---|---|
| Opus input, 5-minute write | $5/M |
| Opus cache read | $0.20/M |
| Opus output | $20/M |
| Gemini 3.8 Flash input | $1.50/M |
| Gemini implicit-cache read | $0.15/M |
| Gemini output | $7.50/M |
| Opus review output | about 11k tokens |
| Opus repair output | about 8k tokens |
| Opus verification | about $0.10 per call |
| Gemini observation | $0.045 |

### A. Lean Claude: the same generator, engineering savings only

deterministic facts (+ new candidates) → Gemini `observe` → **Claude generate on the full context** → checks → **repairs as cached multi-turn turns, returning only changed items** → **incremental Opus verification** (only claims whose note or references changed).

- **Cost:** about **$1.35–1.60** on Pulse, $1.10–1.30 on Butler.
- **Quality:** essentially the baseline by construction: the same model sees the same full context. Deterministic candidates can only add.
- **Failure modes:**
  - multi-turn or patch repairs subtly change the model's behaviour;
  - larger repositories scale the cost linearly;
  - it can't go below about $1.2 on large repositories.

### B. Evidence dossier → Claude synthesis (recommended target)

deterministic analysers and candidates → Gemini `observe` → **Gemini narrow investigators** in parallel, sharing one cached context:

- claims ledger;
- demo ↔ repository;
- runtime reachability;
- data lifecycle;
- jobs, external APIs and models;
- an "anything that contradicts the writeup" catch-all.

Every finding carries verbatim citations, which `ground.resolve()` checks deterministically. Unverifiable findings are dropped before Claude sees them.

→ **Evidence matrix** (deterministic merge: claim × evidence × status candidate × conflicts)

→ **Claude synthesis** on a compact context of about 30–40k tokens:

- writeup lines;
- frame observations;
- repository facts;
- the matrix with cited code windows;
- a file/symbol index;
- one optional retrieval turn in which Claude asks for up to 8 line ranges.

→ checks → cached, targeted repairs → incremental Opus verification (unchanged rules).

| Step | Cost |
|---|---|
| Gemini investigators | $0.20–0.45 (cache hit or miss on the shared prefix) |
| Claude synthesis, including retrieval | $0.40–0.47 |
| Repairs | $0.08–0.30 |
| Verification | $0.20–0.25 |
| Observation | $0.045 |
| **Total** | **about $0.95–1.45**. Under $1 needs a shared-cache hit and at most one small repair. |

- **Quality:** Claude keeps every judgement task (summary, topology, observations, questions, prioritisation), and the verifier is unchanged. The new risk is **recall**: Claude can find only what the dossier, the index and its retrieval turn put in front of it.
- **Failure modes:**
  1. A finding that no investigator or check covers is lost silently (omission again).
  2. Claude over-trusts a plausible Gemini finding. Mitigated because findings are marked as leads, citations are quote-checked, and the verifier still sees raw lines.
  3. Code windows without their surroundings get misread. Mitigated by the retrieval turn.
  4. The checks drift toward Pulse-shaped patterns (overfitting). Mitigated by the catch-all investigator and unseen test submissions.
  5. A Gemini cache miss doubles investigator cost.
  6. More parts and more latency (parallel, so small).

### C. Gemini draft → Claude editor

deterministic candidates → Gemini `observe` → **Gemini full draft** (as in `gemini-first`) → **Claude editor** receives:

- the draft;
- the deterministic candidates;
- cited code windows (about 30k tokens);

and rewrites the summary, topology, observations and questions → cached repairs → Opus verification.

- **Cost:** about **$0.90–1.30**.
- **Quality:** Claude corrects framing and adds candidate-backed findings, but tends to **anchor on the draft's structure and framing**. Gemini-high's misleading summary and drifting graph are exactly what an editor may polish instead of rethink.
- **Failure modes:** anchoring; findings outside the draft and candidates are lost, as in B, but without the investigators' breadth; two authors produce mixed style.

### D. Conditional escalation

deterministic triggers (candidate count, demo-provenance candidates, AI or sponsor claims, low coverage) → Gemini-first review when quiet, full Claude (A) when triggered.

- **Cost:** with 8 of 10 pilot repos showing at least one candidate (after excluding `copyWith` noise), the trigger rate is about 80%. That gives about 0.2 × $0.60 + 0.8 × $1.45 ≈ **$1.28**, barely below A.
- **Quality:** two tiers of review for finalists whom judges compare side by side. The quiet tier fails silently, because a quiet trigger is not the same as nothing to find.
- Rejected as the primary design. It may fit a labelled "screening review" of the whole field, which is not the deep-review use case.

**Also considered and rejected: E. claim-level Claude only.** Gemini writes; Claude adjudicates individual uncertain claims in small contexts. The verifier already does this, and it can't fix omission, which is the observed failure.

| | Cost (Pulse-size) | Quality vs baseline | Main risk |
|---|---|---|---|
| Baseline (measured) | $2.63 | = | none |
| A. Lean Claude | $1.35–1.60 | ≈ by construction | cost floor about $1.2 |
| **B. Evidence dossier** | **$0.95–1.45** | ≈ if dossier recall holds | silent omission |
| C. Gemini draft + Claude editor | $0.90–1.30 | below B (anchoring) | framing and structure inherited from Gemini |
| D. Conditional escalation | about $1.28 | two tiers | quiet-tier misses; little saving |

## 4. Answers to the specific questions

- **Q3, cascade:** yes, B is a cascade. The ordering that matters is that **detection happens before Claude and is cheap to over-generate**. False positives cost Gemini tokens and a Claude sentence, but a miss costs the finding.
- **Q4, conditional Claude:**
  - "Only for projects entering deep review" is already the policy: triage selects them.
  - Inside a review, the useful conditional calls are the **retrieval turn** (only when the matrix leaves Claude uncertain) and **targeted repair** (only the failing items).
  - Escalating the whole review (D) saves little and hides misses.
- **Q5, avoiding 100k-token resends**, in order of certainty:
  1. multi-turn repairs, so the prefix is read from cache: measured miss today, hit in probes on an exact prefix;
  2. repairs return only changed items;
  3. incremental verification;
  4. a compact dossier with cited windows instead of raw excerpts;
  5. a file/symbol index with on-demand retrieval.

  Persistent server-side context (Gemini explicit caches) only pays off for the investigator fan-out.
- **Q6, many narrow Gemini calls vs one large one:**
  - Pulse suggests narrow calls, because observation (narrow) matched Claude while generation (broad) failed at both thinking levels.
  - It is a hypothesis, and the first experiment below tests exactly this.
  - Narrow calls sharing one cached prefix cost about the same as one large call plus outputs.
- **Q8, the quality gate:** see section 6.

## 5. Recommendation

**Target architecture: B (evidence dossier → Claude synthesis), built on A's no-regret levers.**

Gemini and static analysis do the breadth, turning "read everything and notice" into many local, checkable questions. Claude reads a compact, verified dossier and does what only it did well on Pulse: connecting weak signals, deciding what matters, framing, asking. Verification stays exactly as strict. Expected cost is **about $1.0–1.3 on Pulse-sized repositories and under $1 on Butler-sized ones**. If B's recall doesn't hold, A is the fallback, at essentially baseline quality for about $1.35–1.6.

**Do the Claude multi-turn repair optimisation first, regardless (Q8 of the brief).**

- **It pays off in any design.** Every architecture that keeps Claude in the loop (A, B, C) repairs, and on Pulse repairs are 55% of the cost: about $1.0 saved there, about $0.7 on Butler.
- **It carries almost no quality risk.** The model sees the same context, draft and problems, only as conversation turns.
- **It makes every future experiment cheaper,** because the Claude reference arm gets cheaper too.
- **Scope:** first cached multi-turn repairs alone. Patch-style repair output and incremental verification come next, each checked for unchanged grounding outcomes.

## 6. The quality gate

A candidate architecture is adopted only if, on the test set, a blind reader finds all of the following:

1. **Evidence correctness.** No unsupported claim in the final review (at least 8 references spot-checked per arm). Grounding's dropped, capped and lowered counts are no higher than the baseline's.
2. **Findings recall.** The reader builds a **findings inventory**: every gap, mismatch, contradiction or absence asserted by any arm, adjudicated true, false or overstated against the sources, and marked *important* if it would change a judge's view of the entry. The candidate loses **at most one important true finding across the whole test set** relative to the baseline, and asserts no false important finding. New true findings the baseline missed count in its favour.
3. **No misleading framing.** The summary and demo statements never present unimplemented behaviour as working.
4. **Structure.** The readability limits pass (enforced), and the reader does not prefer the baseline on a majority of summary, Idea graph, Integration graph and observations.
5. **Questions.** At least as large a share of questions is rated specific, evidence-backed and useful as the baseline's.
6. **Cost.** The ledger shows the per-submission cost under the target.

The gate is defined by the inventory, not by Pulse's three findings, so it works on submissions nobody has studied.

## 7. The smallest experiment that could falsify B

B stands or falls on one hypothesis: **narrow Gemini investigators plus static candidates recover the important findings that full-context Claude finds.** If they don't, Claude synthesis on the dossier can't recover them either, and B fails before any synthesis is built.

1. **Freeze first.** Write the static checks and the investigator prompts from the generic list in section 2 before looking at any test submission. Do not edit them afterwards.
2. **Test set.** Butler, which already has a published Claude review, and two unseen pilot submissions with a repository and a demo (for example lifesync-ai and glowcare). Pulse runs only as a regression check; the checks were partly inspired by it, so it proves nothing.
3. **References.** Claude-baseline reviews for the two unseen submissions (after the multi-turn repair change: about $1.6–2 each).
4. **Run the investigators only**, not the synthesis: about $0.2–0.45 per submission.
5. **Blind comparison.** The reader gets two unlabelled lists (findings asserted by the Claude reference; the dossier's findings) plus the sources. It builds the inventory, adjudicates it and matches items across the lists.
6. **Falsified if** the dossier misses two or more important true findings that Claude found across the three submissions, or if more than about 20% of its findings are false. The second would push filtering work, and risk, onto Claude.
7. **If it survives,** build B's synthesis and run the full gate (section 6) on the same three submissions: about $1–1.5 each.

The first step costs about $4–6 of pipeline calls at list price (mostly the two Claude references) and involves no Claude synthesis prompt engineering.

## 8. What changes and what stays

| Stage | Change under B |
|---|---|
| `acquire.py` | none |
| `repo_facts.py` | + static candidates (section 2) with file and line, + a file/symbol index |
| `extract.py` | none (the `observe` route is chosen by the experiment). Optionally one verbatim-text pass at higher media resolution if demo-text matching needs it. |
| **new** `investigate.py` | Gemini narrow investigators on a shared cached prefix. Findings are quote-checked with `ground.resolve()`; output `investigations.json`. |
| `generate.py` | builds the compact dossier and adds the retrieval turn. Repairs become multi-turn and cached (first, regardless) and later return only changed items. |
| `ground.py` | verification becomes incremental: only claims whose note or references changed are re-sent. Rules, tiers, ceilings, resolution and the verifier's inputs are unchanged. |
| `publish.py`, `costs.py`, `run.py` | `origin` records the new stages; the ledger gains `investigate` |

**Stays untouched:**

- the evidence tiers and ceilings;
- citation resolution;
- the verifier's model (Opus), its independence (it sees only the claim and its cited frames and lines) and its lower-only authority;
- the readability limits;
- the content rules in the generation prompt (literal summary, ≤ 6 nodes, observations, question kinds);
- Jev triage, and the rules against scores, rankings and outcome data;
- the "Generated automatically" label;
- the `claude-baseline` profile, which stays the reference arm for every experiment.

## 9. Not proposed now

- Effort tuning on Opus: output is about $0.20 per review, but lowering effort risks exactly the synthesis we pay for.
- Other models.
- Gemini for structural-only repairs.
- A direct Anthropic API path with explicit cache breakpoints (no key on this machine).

Each can be its own later A/B once B's recall question is answered.
