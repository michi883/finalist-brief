# Finalist Brief

Finalist Brief turns a set of hackathon submissions into an explorable visual field. Judges can see how the competition differs, open a submission, compare what it claims with how it was built, inspect why Finalist Brief believes each part exists, and take away questions for the team.

## Context

Hackathon judges have limited time to understand a diverse set of projects. Submission descriptions, repositories, and demos contain useful information, but comparing them requires repeatedly reconstructing what each project is trying to do and how it works.

Finalist Brief explores a visual way to support that first pass: help judges notice differences, understand project structure, and decide where to spend more attention. Human judges retain responsibility for evaluation and decisions.

The project is being built for the Serverpod hackathon. Its current prototype uses the existing **Humor Genome: Build with Gemma** submission dataset to test the exploration experience. A second dataset tests triage at scale: all 117 submissions to the Serverpod hackathon itself, **Build your Flutter Butler with Serverpod**.

## Objectives

The current iteration helps a judge answer five questions:

1. **How does the competition differ?** Two purposeful views: Idea × Integration, and Sponsor Tech.
2. **What does this project claim, and how is it actually built?** Idea and Integration diagrams side by side, with the relationships between them.
3. **Why does Finalist Brief believe this?** Every node opens its evidence: a one-line explanation, a demo frame where one exists, source references, and an evidence status.
4. **Where are the gaps?** Mismatches, unclear relationships, unverified claims and open implementation questions are marked in place.
5. **What should I ask the team?** Each marked gap opens one concise judge question and the reason it arises.

## One information space, two scales

### Competition View

The deep-reviewed submissions appear as dots (six for Humor Genome, 31 for Serverpod) in a two-dimensional field. Switching modes animates the dots into a new arrangement.

| Mode | Horizontal | Vertical | Question it answers |
|---|---|---|---|
| Idea × Integration | Integration depth | Idea distinctiveness | How unusual is the concept, and how much implementation stands behind it? |
| Sponsor Tech (Gemma) | Gemma centrality | Gemma evidence | How important is Gemma to the project, and how clearly can that use be verified? |

Hovering a dot only highlights it and its label. Selecting a dot (or its label) fills a persistent **Project Preview** beside the plot: one plain sentence each on why it sits where it does along the two axes (Idea and Integration, or Centrality and Evidence), and an **Open project** button. The preview stays until another project is chosen or Esc clears it, and nothing depends on where the pointer is. Corner captions name combinations, such as "Central · hard to verify", without ranking them. Positions are descriptive interpretations, **not judge scores or rankings**. The earlier preset lenses and custom axes are removed for now.

### Submission View

Selecting a dot expands it into the project. Returning collapses the structure back into its original position in the competition.

- **Idea and Integration side by side.** The left diagram shows what the submission presents; the right shows how it is built. A focused single-diagram mode remains available.
- **The delta, stated.** A strip headed *How the idea is built* states each Idea → Integration relationship as a plain observation: "4 audiences → 1 runtime", "6 tools → 1 pipeline", "Popular issues rise → newest first". Hovering or clicking one draws its nodes converging through the gutter between the diagrams. Both diagrams share one scale, so node size never suggests one side matters more; neither shrinks below its natural size to match the other.
- **Evidence on every node.** Clicking a node opens a compact card: a one-line explanation, a demo frame at its timestamp where available, sources (repo paths and video timestamps link out), and its counterparts in the other diagram.
- **Evidence status.** ● Demonstrated (seen working in a recording), ◐ Found in code, ○ Described (stated by the team), ◌ Inferred (Finalist Brief's structural reading). Inferred nodes are drawn with a dotted outline and no fill, so they never carry the authority of verified evidence.
- **Judge questions.** A small **?** marks a gap. Clicking it shows the question, why Finalist Brief asks it, its sources, and the nodes it concerns. Questions are authored from specific structural or evidence gaps, never generated generically.

A small competition map preserves context, and judges can jump directly between submissions. Esc closes an open card, then returns to the field.

## The submission determines the topology

**The submission determines the topology. Finalist Brief determines the visual grammar.**

Different projects need different shapes. A creative workbench can form a hub; an audience experiment can branch and merge; a rehearsal tool can form a feedback loop. Every submission should reveal its own structure.

The prototype uses a shared language for humans, product surfaces, AI models, transformations, external systems, observed signals, and artifacts. Directed edges express relationships; dashed edges express iteration. Short edge labels carry verbs ("posts", "appears on", "saved as user 1"), so node sublabels are optional and nodes can stay short. Semantic project data is separate from rendering, so reusable layouts determine positions from relationships and structural hints. Side by side, flows run top to bottom so both diagrams stay readable.

### Evidence model

One `Evidence` type (status, one-line note, source references, optional frame) is shared by nodes, edges, and Idea ↔ Integration mappings, so relationships can carry the same provenance as the elements they connect. The status is a trust tier, not a calibrated probability; no numeric confidence is stored. Judge questions anchor to nodes or edges in either diagram.

The loader rejects data that claims more than its sources support: "demonstrated" requires a video timestamp, "found in code" requires a repository path, and "described" requires at least one source.

The design test is whether judges perceive meaningful differences across projects and lenses while remaining able to read the shared visual language.

## Current prototype

The desktop-oriented Flutter app includes a Hackathons entry and, per hackathon, a persistent workspace (Overview, Submissions, Competition), two competition modes, animated movement, reversible zoom, side-by-side Idea and Integration diagrams with cross-highlighting, node evidence cards, and judge questions.

The six contestants are **Crowdwork Copilot**, **Humor Genome Studio**, **Killjoy**, **LaughLensAI**, **Room Sense Text**, and **Why'd They Laugh?**. The additional `laughlens-platform` entry in the historical dataset is excluded from the visual experience.

The demo is deterministic. Placements, graphs, evidence and questions were authored by hand from each contestant's writeup, public repository and demo recording, checked on 2026-09-24. Demo frames in `assets/evidence/` were extracted at the cited timestamps. LaughLensAI's frames come from the recording in its repository (`submission/laughlens.mov`). Room Sense Text has no repository or recording, so its structure is marked described or inferred. These are explanatory interpretations, not automatically extracted architecture or calibrated measurements. The visual experience loads bundled data and makes no live analysis requests.

Live model analysis in the app, automatic topology extraction in the app, automated judging, finalist ranking, and production mobile support are outside the current scope.

The Serverpod backend, cached analyses, and earlier video-generation infrastructure remain available for future work. The visual exploration experience is now the product centerpiece.

## Two hackathons, one grammar

Every hackathon follows one hierarchy: **Hackathons → Hackathon → Overview | Submissions | Competition → Project**. Anything else is view state, not another level of navigation.

- **Persistent header.** Inside a hackathon, a header stays on every screen: a breadcrumb (`Hackathons / Serverpod / Submissions`), the hackathon's title, and three tabs with counts (**Overview**, **Submissions 117**, **Competition 31**). The active tab is filled. *Hackathons* returns to the list; there is no hackathon switch inside a workspace. Serverpod and Humor Genome use the same shell.
- **Overview** says what was acquired, counted from the data: submissions, writeups, repositories inspected, demo videos available and deep reviews. It offers **Browse submissions** and **Explore competition**. Choosing a hackathon from the list always opens its Overview.
- **Submissions** is the table of every submission. Its filters (for Serverpod the six review questions, below), search, sort and row selection are controls inside the tab, drawn as small chips and never added to the breadcrumb. **View N in Competition** compares the selection.
- **Competition** is the field. Its modes (*Idea × Integration*, *Sponsor Tech*) are chips inside the tab, and the selected-project spotlight sits beside the plot.
- **Project** is the only level below Submissions and Competition. Opening one adds it to the breadcrumb (`… / Competition / Naggy` or `… / Submissions / Naggy`, according to where it was opened from), keeps that origin tab highlighted, and shows **← Back to Competition** or **← Back to Submissions**. Back, Esc and the breadcrumb return to the exact view left behind: filters, search, selection, mode and the open detail panel.

Opened workspaces stay alive, so state survives switching tabs or hackathons. The address follows the hierarchy: `#/hackathons/serverpod`, `.../submissions`, `.../competition`, and `.../competition/naggy` or `.../submissions/naggy` for a project. These links open directly, and `?hackathon=serverpod` and `?hackathon=humor-genome` still work. The address is replaced rather than pushed, so the browser's Back button leaves the app.

Each hackathon is a self-contained unit (`lib/hackathon/hackathon.dart`): its sponsor technology, its deep-review representations for the Competition and Submission views, and optionally a triage dataset. Their assets never mix. A workspace is built the first time it is opened and then kept alive.

Humor Genome is a cached study of six submissions. Its Submissions tab is a plain table (project, sources, deep-review status) with no lanes or filters; the Competition View, Submission View, evidence and judge questions are as before.

## Serverpod triage

A hundred and seventeen submissions are too many to compare as dots. The Serverpod workspace therefore puts a **Triage Table** (its Submissions tab) in front of the Competition View. Its purpose is not to rank. It tests whether messy submissions can be cheaply turned into signals judges can trust when deciding what deserves a deeper look.

**Coverage.** All 117 gallery entries are in triage, including those with no repository, a 404, a private or missing demo, or a placeholder writeup; missing evidence is named in the *Unresolved* lane and in judge questions instead of dropping the row. Entries are ordered by SHA-1 of their slug, which fixed the order in which the sample grew (15 → 64 → 117) and in which deep reviews were batched. Prizes, likes, comments and gallery order are never read.

**A question first.** The tab is six review questions shown as filter chips (`lib/triage/review_lens.dart`), a search box and the table. The questions are *All*, *Substantial builds*, *Distinctive ideas*, *Under-told*, *Needs verification* and *Sponsor tech*. Each one chooses its rows, two or three columns that answer it, and a stated order, and is explained in one sentence. For example, *Needs verification* shows Claim · What we found · Judge question, most fundamental gap first. *All* shows Project, Why look and Evidence. *Sponsor tech*'s *Why it matters* column shows one Serverpod fact taken from the lanes and questions: what blocks checking the server, then Serverpod features described but not found, then what the writeup leaves out. Questions are views over the lanes and open questions below; they add no signal and no score. There are no other filters to configure.

**Detail on request.** Clicking a row opens a drawer. It first shows why the project is here, what Finalist Brief verified (code, demo, Serverpod role), one judge question and, where one exists, **Open deep review**. One quiet toggle, *More evidence and technical details*, reveals the other questions, links, repository details (scaffold delta, endpoints, models, tables, tests), Jev's extraction, all claims and commit history. Selecting rows that have a deep review shows **View N in Competition**. Triage finds projects worth examining, the Competition View compares the selected set, and the Submission View inspects one project. Search covers titles, teams, tech and reasons. Rows render lazily with a fixed height, and writeup lines load only when requested, so the same table can hold 117 or 1,000+ rows.

**Three sources, never merged.** Every signal is labelled with where it comes from:

- **Links:** whether the repository, demo video and live app respond (checked 2026-09-24; rows added later carry their own date, up to 2026-09-28).
- **Repository:** deterministic, from the last commit before the deadline. Scaffold delta against the exact `serverpod create` template, the Serverpod footprint (endpoints the app actually calls, tables, streams, future calls, auth), tests, model-provider calls in code, commit timing.
- **Jev:** TypeSafe's System One model (`jev-1.13.0`), used only for structured extraction from the writeup: area, how the butler helps, the AI's role, how Serverpod is described, which capabilities are mentioned, unfinished work, and a per-line claim classification. It is never asked to rank, score quality or pick winners.

**Lanes, not scores.** Four explainable lanes: *Substantial build*, *Distinctive idea*, *Under-told*, *Unresolved*. Each has a visible rule and names the fact that triggered it, such as "16 endpoint methods used by the app · 9 tables · +5.3k lines" or "Central AI claim; no model call in code". A submission can sit in several lanes or in none, and no composite exists. A writeup that states no capability, implementation or outcome ("WIP", an empty template) gives Jev nothing to place, so it never counts toward *Distinctive idea* or the area counts; it raises its own judge question instead. Line counts are *repository* lines beyond the template: code a team copied in (a vendored package) counts too, so a count can overstate what the team wrote. Crewboard is the known case (about 148k of +211k lines are a copied image editor); its lanes do not depend on it. Questions for the team come from specific gaps, including cross-checks between what Jev found in the writeup and what code found in the repository.

**Into the deeper views.** Thirty-one submissions have full Idea + Integration representations. Four are written by hand like Humor Genome's: Bitcoin Butler (Distinctive idea), Elderly (Substantial build), Social Fabric (Under-told and Unresolved) and DOBY (Unresolved). Each shows only the essential structure: five or six nodes per diagram, short titles, at most four Idea → Integration observations, and a summary in plain, literal language rather than the team's pitch. Social Fabric is the reference case. The other twenty-seven, starting with **Contextual LifeFlow Butler**, were generated automatically from their writeup, repository and demo by [`tool/deep_review/`](tool/deep_review/README.md) and not edited by hand. Their evidence statuses are checked against the cited sources and by an independent verifier, and the Submission View labels each **Generated automatically**. "Open deep review" on a row zooms straight into its Submission View. Selecting rows narrows the Competition View to those submissions. Repository evidence links pin the deadline commit. DOBY's demo video is private, so none of its nodes claim more than "found in code".

The pipeline that produced this data, with its caches and limits, is in [`tool/serverpod_pilot/`](tool/serverpod_pilot/README.md).

## Operating cost

The question is whether a deep review of Social Fabric's quality can be produced for a per-submission cost low enough to scale. Three experiments answered it. Gemini 3.8 Flash writing the review, at medium or high thinking, missed the cross-file findings a judge most needs. An evidence dossier (Jev claims, static checks and narrow Gemini investigations) also failed on an unseen project, and it would not have been cheaper. What did work is making Claude's repairs cheap: the Claude baseline now measures **$1.53–1.62 per review**, about $15–32 for the 10–20 finalists a hackathon deep-reviews.

### Deterministic vs model-based work

Most of the pipeline is code. Models are used only where a judgement about language or images is needed, and every model output that reaches a judge passes deterministic checks.

| Pipeline | Stage | Runs on | Model calls per submission |
|---|---|---|---|
| Triage | Devpost pages, sample (`fetch_devpost.py`) | code | 0 |
| Triage | Links, deadline snapshot, scaffold delta, Serverpod footprint, tests, commit timing (`deterministic_signals.py`) | code | 0 |
| Triage | Writeup profile and per-line claim kinds (`jev_extract.py`) | Jev `jev-1.13.0` | 1 profile + 1 per 90 lines (2–8, mean 2.7) |
| Triage | Merge; lanes and judge questions (`build_dataset.py`, `lib/triage/lanes.dart`) | code | 0 |
| Deep review | Writeup, repository at the deadline, demo, captions, frames (`acquire.py`) | code | 0 |
| Deep review | Endpoints, calls, models, channels, permissions, markers, excerpts (`repo_facts.py`) | code | 0 |
| Deep review | Writeup lines | Jev's triage output, reused | 0 |
| Deep review | Blind demo-frame description (`extract.py`) | `observe` route | 1 |
| Deep review | Draft review, then repairs when checks fail (`generate.py`); on Claude the repairs are later turns of one cached conversation | `generate` route | 1 + up to 3 |
| Deep review | Citation resolution, status ceilings, readability limits (`ground.py`) | code | 0 |
| Deep review | Independent evidence check (`ground.py`); only new or changed claims are sent | `verify` route | 1 per well-formed draft (up to 4), 0 when nothing changed |
| Deep review | Hand-off to the app asset (`publish.py`) | code | 0 |

A deep review therefore makes 4 to 9 model calls: 6 for Contextual LifeFlow Butler.

### Model routing by stage

Each model stage of the deep-review pipeline is routed on its own in [`tool/deep_review/routing.json`](tool/deep_review/routing.json), by profile or by per-stage override (see the [deep-review README](tool/deep_review/README.md#model-routing)). Jev stays the only model in triage.

| Stage | `claude-baseline` (default, kept) | `gemini-first` / `gemini-high` (tested, not adopted) | Finding |
|---|---|---|---|
| Triage extraction | Jev | Jev | Narrow, calibrated typed answers for about $0.001 per submission; no reason to change. |
| observe | Claude Opus 5.5 | Gemini 3.8 Flash, medium thinking | Equivalent on Pulse: both literal and in agreement on every frame. It is only 2–8% of the cost, so switching saves little. |
| generate | Claude Opus 5.5 | Gemini 3.8 Flash, medium / high thinking | **Where quality was lost.** At both thinking levels Gemini stayed at the level of single files and found none of the three cross-file findings; its repairs narrowed claims instead. At high thinking the summary also presented alert-only demo actions as features. This stage is 70–83% of the cost. |
| verify | Claude Opus 5.5 | Claude Opus 5.5 | The trust gate, kept on the strongest model. Before anything reached a final review it rejected 8 Claude claims, 8 from Gemini-medium and 11 from Gemini-high. It costs $0.12–0.34. |

### Measured: Contextual LifeFlow Butler

From the run ledger (`python3 costs.py contextual-lifeflow-butler`). These numbers were replayed from cache with no new calls, and the outputs are byte-identical to the published review.

| Stage | Calls | Input tokens | Output tokens | Cost |
|---|---|---|---|---|
| observe (39 frames) | 1 | 21,268 | 3,883 | $0.25 |
| generate (draft + 2 repairs) | 3 | 252,016 | 25,158 | $2.43 |
| verify | 2 | 24,730 | 5,688 | $0.30 |
| **Total** | **6** | **298,014** | **34,729** | **$2.98** |

The first draft broke three readability limits (one-sentence summary, two labels over 22 characters). The verifier rejected three code citations in the second draft. The third draft passed. Developing the pipeline on this submission left 14 cached responses worth $7.28 in total, from the final run and two earlier pipeline versions. That is a one-off development cost, not a per-submission cost.

Triage used 434k Jev input tokens for 15 writeups: **$0.018 in total, $0.0012 per submission**. Jev charges $0.042 per million input tokens and nothing for output. Every Jev response ever cached (853k tokens, including development) cost $0.04.

### Measured: Pulse A/Bs (Claude baseline vs Gemini)

Two clean A/Bs were run on an unseen submission with the pipeline frozen and `--no-publish`. All arms shared acquisition and repository facts. Gemini-high reused Gemini-medium's cached observation and was compared against the frozen Claude run, which was not repeated. Full records, including the blind reviews: [A/B 1, Gemini medium thinking](tool/deep_review/experiments/2026-09-26-pulse-ab.md) and [A/B 2, Gemini high thinking](tool/deep_review/experiments/2026-09-26-pulse-ab-2-gemini-high.md).

| | Claude baseline | Gemini-medium | Gemini-high |
|---|---|---|---|
| observe | $0.095 · 10.3k in / 2.2k out | $0.045 · 18.9k in / 2.2k out | reused (cached, $0) |
| generate | $2.186 · 3 calls · 343.7k in / 27.6k out | $0.389 · 3 calls · 264.1k in / 28.7k out | $0.477 · 2 calls · 175.5k in / 43.3k out |
| verify (Opus 5.5 in all) | $0.343 · 3 calls | $0.120 · 2 calls | $0.143 · 2 calls |
| **Total (list)** | **$2.63 · 7 calls · 295 s** | **$0.55 · 6 calls · 119 s** | **$0.67 · 5 calls · 155 s** |
| Repairs | 2 | 2 | 1 |
| Claims rejected by the verifier during repairs | 8 | 8 (10 objections) | 11 (12 objections) |
| Final: dropped / capped / lowered | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| Final: Demonstrated / Found in code / Described / Inferred | 1 / 10 / 6 / 0 | 1 / 7 / 5 / 0 | 2 / 7 / 4 / 3 |
| Cross-file findings surfaced (of 3) | **3** | 0 (1 only in a placement note) | 0 (1 only in a placement note; 1 contradicted) |
| Blind review, overall | 1st | 2nd: thinner but accurate | 3rd: "mildly misleading" |

**Blind reviews.** Each reader saw only the reviews under random labels, plus the sources, and was told which was which only after its verdict. Both preferred Claude on every criterion. Most references checked were accurate in all arms; what separated them was omission. Only Claude found that:

- the demo's browser alerts and chat reply are not in the repository;
- conflict detection looks for a node type no importer writes;
- GitHub events never become graph nodes.

Gemini-medium's summary repeated the team's "AI assistant" framing. Gemini-high's summary said the user "triggers conflict and debt reports", but those are alert dialogs with no code behind them. It also described "future calls for scraping, processing, and embeddings" when only scraping is ever scheduled. High thinking produced 51% more output tokens but no deeper synthesis. The readers were themselves Claude models, but the deciding points are checkable omissions and contradictions, not style.

**Decision.** Both Gemini arms fail the pass conditions; Gemini-high needed 2 of 3 findings and got none. **Keep `claude-baseline` for `generate` and stop trying to replace it for now.** The default routing is unchanged.

### Measured: multi-turn repairs and the evidence dossier

Full record: [`tool/deep_review/experiments/2026-09-26-dossier-validation.md`](tool/deep_review/experiments/2026-09-26-dossier-validation.md).

**Multi-turn repairs (built, now the pipeline's behaviour).** Claude gets the context once; repair requests are later turns of the same live CLI conversation, so the context is read from the prompt cache. Verification sends only claims whose note or evidence changed. Prompts, rules, evidence tiers and the verifier are unchanged. Repairs still return the full review, because a smaller repair schema would change the cached prefix.

| | Before (Pulse, A/B 1) | Multi-turn (Pulse) | Multi-turn (skinaware, unseen) |
|---|---|---|---|
| Draft | $0.75 | $0.81 | $0.89 |
| Each repair | $0.71–0.73 | **$0.22** (110–123k tokens read from cache) | **$0.20–0.21** (135–147k read) |
| Verification | $0.34 | **$0.18** | **$0.13** |
| **Total** | **$2.63** | **$1.53 (−42%)** | **$1.62** |

The Pulse review kept all three cross-file findings and added one more, so there is no quality regression.

**Evidence dossier (tested, stopped).** Discovery was done without Claude:

- Jev labelled the writeup claims.
- Static checks produced candidates.
- Five Gemini 3.8 Flash investigators answered narrow cited propositions.

Developed and then frozen on Pulse, it recovered Pulse's known findings. On the unseen skinaware it failed the gate:

- It missed 3 of Claude's important findings: a fixed diagnosis whatever the model says, no auth or session check, and profile access for any `userId`.
- 5 of its 20 findings were false or overstated, against Claude's 0.
- It found no important finding Claude lacked.

The causes were structural: a 45-item cap (249 claims existed), the same 19-file evidence window as Claude, and no proposition about output fidelity or access control. The dossier alone cost $0.70–0.95, so dossier plus Claude synthesis would cost about $1.45–1.70, no less than the optimized baseline. The frozen specification is in [`tool/deep_review/design/2026-09-26-dossier-frozen.md`](tool/deep_review/design/2026-09-26-dossier-frozen.md), and the original design in [`tool/deep_review/design/2026-09-26-cascade-architecture.md`](tool/deep_review/design/2026-09-26-cascade-architecture.md).

### Caching and retries

- **Response caches.** Every model response is stored under a hash of its full request (model, prompt, content, schema): `tool/serverpod_pilot/.cache/jev_responses.json` for Jev, `tool/deep_review/.cache/<id>/llm/` for deep reviews. A re-run with unchanged inputs makes no calls and gives the same output. `DEEP_REVIEW_CACHE_ONLY=1` turns an uncached call into an error.
- **Provider prompt caching.** The Claude CLI wrote every Butler prompt to a 1-hour cache at 2× the input price, and nothing ever read it back. Even the repair calls, which repeat the 79k-token context, got no cache hit. Deep-review calls now run with `DISABLE_PROMPT_CACHING=1`, which turns that into a 5-minute write at 1.25×. The Pulse run confirmed this on Opus: every call matched the 5-minute price to four decimals. Outputs are unchanged. On Gemini, the repair loop's repeated prefix is discounted automatically: 164.6k of Pulse's 264.1k generation input tokens were implicit-cache hits.
- **Retries.** Jev: up to 5 attempts on 429/529, with backoff of 1–8 s. Gemini: up to 5 attempts on 429, 5xx, timeouts or unparseable JSON, with backoff of 2–16 s. Claude CLI: the CLI retries API errors itself, and the ledger counts any retry events it reports; a failed call stops the stage, and a re-run resumes from the cache. Page fetches: 3 attempts. The Pulse A/Bs needed no transport retries in any arm.
- **Quality retries.** At most 3 repairs are made, each followed by a verifier call once the draft passes the deterministic checks. On Claude each repair is a later turn of the draft's conversation and reads the context from cache (measured: 110–147k tokens read per repair); on Gemini each repair re-sends the context, which implicit caching discounts. Verification reuses stored verdicts for unchanged claims.

### Projected production cost

Per submission and for 10, 20 and all 117 submissions, at list prices:

| | Per submission | 10 | 20 | 117 |
|---|---|---|---|---|
| Triage (deterministic + Jev) | $0.001 | $0.01 | $0.02 | $0.14 |
| Deep review, `claude-baseline` with multi-turn repairs (measured: Pulse $1.53, skinaware $1.62) | $1.5–1.6 | $15–16 | $30–32 | $176–189 |
| — worst case (3 repairs, 4 verifier calls) | ~$2.0 | $20 | $40 | $234 |
| Deep review, `claude-baseline` before multi-turn repairs (Pulse, A/B 1) | $2.63 | $26 | $53 | $308 |
| Deep review, Gemini 3.8 Flash medium / high (measured on Pulse; not adopted) | $0.55 / $0.67 | $6 / $7 | $11 / $13 | $65 / $78 |

How the rows are derived:

- Both Claude rows are measured runs at the 5-minute cache-write price. Pulse and skinaware both hit the 240k-character excerpt budget, so they are near the top of the field's size range. Butler's older $2.98 was measured with 1-hour writes and resend-style repairs.
- The worst case scales the multi-turn per-call costs to 3 repairs ($0.22 each) and 4 verifier calls.

Triage runs on every submission; deep reviews are for the 10–20 it surfaces. At that scale the Claude baseline costs $15–32 per hackathon, which is sustainable without switching models. Only deep reviews of the whole field would make cost a real argument. Even there, Gemini's $65–78 against Claude's $176–189 does not justify reviews that miss or misstate what judges need.

### Production pipeline vs development usage

The rows above are **production pipeline cost**: the model calls one submission needs, recorded per call in `.cache/<id>/runs/<profile>/calls.jsonl` and priced at list price. They exclude **development usage**:

- the Claude Code sessions (local and cloud) that built the app, wrote the four hand-authored deep reviews, developed both pipelines, ran this audit and both A/Bs, and did the blind quality reviews;
- pipeline-development reruns, such as Butler's earlier drafts ($7.28 across pipeline versions).

Development usage is paid from session and promotional credits, including the $100 of cloud-session credit set aside for this round. It recurs per iteration, not per submission, and is not part of any operating-cost estimate.

The A/Bs' own pipeline calls cost $3.80 at list price: $2.63 Claude, $0.55 Gemini-medium, and $0.62 new spend for Gemini-high. Probe calls added about $0.07 during the audit and $0.72 for the cache diagnosis. The multi-turn and dossier round's pipeline calls cost about $6.2 at list price. That covers the Pulse Claude run, about $2.0 of dossier development on Pulse, both skinaware arms and a $0.18 session probe. `claude -p` reports list-price cost even when the CLI is signed in to a subscription, and the estimates use that list price so that they hold on a pay-as-you-go API key.

Left out of every estimate:

- Gemini 3.6–3.8 Flash cost half their list price until 31 December 2026; the 2027 price is used.
- The Gemini free tier is not used; it has other rate limits and data-use terms.
- Promotional, trial or cloud-session credits on any provider are not counted.

A sustainable estimate has to survive once those end.

## Run the demo

From the repository root:

```sh
serverpod start
```

Open **http://localhost:9998/**. The Hackathons list opens first. Choose a hackathon to see its Overview, then use the tabs: **Submissions** to filter, search and select, **Competition** to pick a mode and a dot, **Open project** to inspect a submission. Click nodes, mapping chips and **?** hints; use **← Back**, the breadcrumb or **Esc** to return. **http://localhost:9998/?hackathon=serverpod** (or `humor-genome`) opens a hackathon directly.

The Flutter launch configuration pins port 9998. An existing session started before that setting may use the port printed in its launch output.

## Development

The app uses Flutter and Serverpod. Representations live in [`finalist_brief_flutter/assets/representations/`](finalist_brief_flutter/assets/representations/), one file per hackathon, and the Serverpod triage data in `assets/triage/`. Semantic types are in `lib/representation/`, hackathon loading in `lib/hackathon/`, triage signals, lane rules and queries in `lib/triage/`, shared rendering in `lib/visualization/`. The workspace shell and header, Overview, triage table, exploration screen, side-by-side comparison and inspector cards are in `lib/views/`.

Tests cover representation integrity, the evidence rules, question anchoring, wide and compact layouts, animation continuity, mode switching, cross-highlighting, the inspector and question flows, and competition-context restoration. For the Serverpod triage they also cover: the absence of outcome, popularity and score fields; separation of Jev and repository signals; lane reasons; each review question's rows, columns and order; sorting and search; the sponsor finding; layered row detail; the Competition hand-off; deep-review integrity; data isolation between hackathons; state preserved across switches; and triage-to-deep-review navigation without overflow. Run `dart analyze` from the root, `flutter test` in `finalist_brief_flutter`, and `dart test` in `finalist_brief_server`. Server tests use embedded PostgreSQL without Docker.

See [PLAN.md](PLAN.md) for the current build contract and archived video plan, and [AGENTS.md](AGENTS.md) for the development workflow. [INSTRUCTIONS.md](INSTRUCTIONS.md) preserves the original project brief.

## Deployment

The production app runs on Serverpod Cloud at **https://michi-test1.serverpod.space** (project `michi-test1`, configured in `finalist_brief_server/scloud.yaml`). The Flutter web app is built into the server's `web/app` by a pre-deploy script (`serverpod run flutter_build`) and served by the same server. From `finalist_brief_server`, run `scloud deploy`. The visual experience is fully bundled and makes no live analysis requests, so a deploy needs no data pipeline or API keys.
