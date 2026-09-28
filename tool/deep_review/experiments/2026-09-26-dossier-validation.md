# Multi-turn repairs and the evidence dossier (2026-09-26)

**Question.** Can Jev claims, static analysis and narrow Gemini investigations preserve Claude-quality findings at lower cost, with Claude used only for synthesis?

**Answer.**

- **Phase 1:** multi-turn repairs cut the Claude baseline by 42% with no quality regression.
- **Phases 2–4:** the evidence dossier recovered Pulse's known findings during development. On the one unseen project (skinaware), frozen, it **failed the gate**: 3 important Claude findings were missed, 25% of its findings were false or overstated, and it found nothing important that Claude missed.

Stop the dossier path. Nothing was published, and the default routing is unchanged.

## Phase 1: Claude repairs as turns of one conversation

The context is sent once. Repair requests are later turns in the same live `claude -p` session (`common.ClaudeSession`), so the context is read from the prompt cache. Re-verification sends only claims whose note or cited evidence changed; verdicts are stored per claim fingerprint (verifier model + note + evidence shown).

Unchanged: prompts, content rules, evidence tiers, grounding, readability rules, and the verifier's prompt, inputs per claim and lower-only authority.

**Not practical: returning only changed items.** The JSON schema is part of the cached prefix, so a smaller repair schema would invalidate the cache. Repairs still return the full review. Their output (6–8k tokens, about $0.15) is now the main repair cost.

| Pulse | A/B 1 baseline (resend) | Multi-turn |
|---|---|---|
| Draft | $0.748 | $0.809 (13.0k output vs 11.3k) |
| Repair 1 | $0.709 (110.8k written) | **$0.223** (109.9k read from cache, 13.5k written) |
| Repair 2 | $0.729 | **$0.221** (123.5k read) |
| Verification | $0.343 (3 calls, all claims each time) | **$0.179** (12 claims, then 5 changed + 7 reused, then 0 in grounding) |
| Observation | $0.095 | $0.095 (cached) |
| **Total** | **$2.63** · 295 s | **$1.53 (−42%)** · 246 s |

**Quality.** The multi-turn review found all three known Pulse findings: demo actions with no code behind them, the `decision` node type, and the unscheduled processing plus the `.gz`. It added one the earlier baseline missed: MySQL-style `INDEX` inside `CREATE TABLE`. Its 18 evidence items were 12 Found in code and 6 Described; the earlier review had one Demonstrated. No regression.

**Skinaware** (unseen, optimized pipeline), **$1.62**:

| Item | Cost |
|---|---|
| Observation (40 frames) | $0.191 |
| Draft | $0.890 |
| Repair 1 | $0.212 (135k cache read) |
| Repair 2 | $0.196 (147k cache read) |
| Verification | $0.128 (13, then 2 changed, then 0) |

The run took 239 s.

## Phase 2: the dossier, developed on Pulse

The architecture and the ten development changes are in [`../design/2026-09-26-dossier-frozen.md`](../design/2026-09-26-dossier-frozen.md). In short:

- Jev labels each writeup line with a claim topic.
- Static checks emit candidates.
- Five Gemini 3.8 Flash investigators (claims, candidates, paths, dataflow, demo) each answer one fixed proposition per item, with citations checked by `ground.resolve()`.

On Pulse (frozen version):

| Known finding | Result |
|---|---|
| Demo alerts not produced by repository code | recovered |
| Chat-reply wording mismatch | not recovered |
| `decision` node type | recovered |
| GitHub events never become nodes (unscheduled processing, `.gz`) | recovered |

It also produced several true extras: `markAsRead` is never invoked, the stream is never posted to, the isolates are unused, and test coverage is missing from the debt score.

Pulse dossier cost: about $0.70–0.80. The development iterations spent about $2.0 in Gemini calls.

## Phase 3: frozen

Frozen as `static-5`, `claims-1` and `dossier-6`, with the file hashes recorded in the frozen spec. Nothing was changed after the unseen project ran.

## Phase 4: one unseen project (skinaware)

**Selection.** The next eligible project in the pilot's SHA-1 sample order after Pulse:

- Bitcoin Butler and Contextual LifeFlow Butler already have reviews.
- course-craft-ai and group-chat-butler have no repository.

Skinaware has a public repository (snapshot `990e103f8bc2`), a 397 s demo with captions, and a 623-line writeup. It had no prior review.

**Disclosure.** The design round's static prototype had printed skinaware's check hits; no review or model output about it had been seen.

**Runs.** Both were independent and started together from the same acquisition:

| Arm | Cost | Time |
|---|---|---|
| Claude baseline (optimized) | $1.62 | 239 s |
| Frozen dossier | $0.95 | 74 s |

The dossier never saw Claude's output.

**Adjudication.** A fresh reader received the Claude review (A), the dossier's findings (B: 43 entries, i.e. contradicted answers plus confirmed candidates) and the sources. It extracted, adjudicated and matched every finding.

| | Claude review (A) | Dossier (B) |
|---|---|---|
| Findings | 18 | 20 (grouped from 43 entries) |
| False / overstated | **0 / 0** | **1 / 4** |
| Important true findings (distinct facts) | 9 | 4 in common with A (+2 partial); **0 important ones A lacks** |
| Citation spot-checks | 5 strong, 1 weak | 4 strong, 2 weak, 2 wrong |

**Important Claude findings the dossier missed:**

1. The server returns a fixed diagnosis ("Further evaluation needed", confidence 0.75, empty differential) whatever the model says. The model text only fills recommendations.
2. Login returns the user row; there is no session and no auth check anywhere.
3. The profile methods act on any client-supplied `userId`.

Also missed: the demo's "Confidence 0.85" contradicting the 0.75 returned by the server, and the offline mode not being used in the demo.

**The dossier's false and overstated findings:**

- **False:** it rejected the static candidate "ProfileService unreferenced", which is in fact unreferenced.
- **Overstated:** "plain HTTP" (both hosts are https); "streaming exists for the AI" (the app never calls the stream); "`updateUser` never called" (called from a screen nothing opens); a "previousTreatments collected" detail.

**Important facts neither arm found**, all per the reader:

- The password hash and encryption key are returned to any client.
- The LLaVA-Med/OpenBioLLM client (`OllamaService`) is dead code with a hard-coded IP, and the Cloudinary secret is in the app. The static check flagged `OllamaService` as unreferenced, but the investigator could not see the file.
- The home "79%" skin score is a constant.
- The offline `.tflite` model is excluded by `.gitignore`.

**Why it failed** (causes, not fixes; the system stays frozen):

1. **Item cap.** 249 eligible claims, 45 checked (`MAX_ITEMS = 45`, first 45 in writeup order). The auth, session and encryption claims (L077–L087, L138–L139) were never investigated.
2. **Evidence window.** The investigators see the same 19 excerpted files as Claude; 68 files were over budget. 12 of 20 candidates, 9 of 12 paths and 6 dataflow items came back "not in the excerpts"; 14 demo items went unanswered. The static layer was right about `OllamaService`, but nothing could confirm it.
3. **Findings no proposition asks for.** The fixed diagnosis, the missing auth and the any-`userId` access came from Claude reading whole endpoints and asking "what does this actually do?" None of the five fixed propositions covers output fidelity or access control. Narrow questions only find what they are asked.
4. **Gemini's own errors.** It rejected a correct candidate and made overstatements with wrong citations. Its synthesis errors from A/B 1–2 were avoided, but its local judgements were not reliably correct either.

**Did Gemini mostly confirm or reject given items?** Yes, by construction every answer is anchored to an item. But on skinaware 41% of answers were unresolved, and of the 20 candidates 5 were confirmed, 3 rejected (1 wrongly) and 12 unresolved.

## Cost

List prices only; development-agent usage and credits excluded.

| | Pulse | Skinaware |
|---|---|---|
| Jev | $0.001 | $0.007 |
| Static analysis | $0 | $0 |
| Gemini observation (dossier) | $0.045 | $0.095 |
| Gemini investigations | about $0.65–0.75 | $0.85 (no implicit-cache hit for the two medium calls) |
| **Dossier total** | **about $0.70–0.80** | **$0.95** |
| Claude baseline, optimized (observe + draft + repairs) | $1.35 | $1.49 |
| Verification (Opus) | $0.18 | $0.13 |
| **Claude baseline total** | **$1.53** | **$1.62** |

The dossier alone costs 55–60% of the optimized Claude baseline. A cascade would add Claude synthesis (about $0.40), repairs (about $0.20) and verification (about $0.15), for about $1.45–1.70. That is no cheaper than the baseline it would replace, and less complete.

Pipeline calls made this round, at list price: about $6.2.

| Item | Cost |
|---|---|
| Pulse Claude run | $1.43 |
| Pulse dossier development | about $2.0 |
| Skinaware Claude | $1.62 |
| Skinaware dossier | $0.95 |
| Multi-turn probe | $0.18 |

## Recommendation

**Stop the dossier-replacement path.** It fails the stated gate on the first unseen project. Even if fixed, it would not be cheaper than the optimized Claude baseline, which now costs $1.53–1.62, just above the $1.50 acceptable bound.

Keep Phase 1 (multi-turn repairs and incremental verification) as the pipeline's behaviour.

If cost work continues, the next target is inside the Claude arm:

- Repairs are now 25–30% of the cost, most of it re-emitted output (the full review, about twice per run).
- The draft's own output is 13k tokens.

Separately, the static checks cost nothing and produced the one lead both arms missed (`OllamaService`). Whether giving Claude the static candidates improves its findings is a quality question worth a later A/B, not a cost saving.
