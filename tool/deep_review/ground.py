"""Stage 5: evidence and provenance.

Turns the draft's citations into Finalist Brief source references and makes
sure no status claims more than its sources support:

1. Deterministic resolution. A writeup citation must quote its line; a code
   citation must quote text that exists in that file at the deadline
   snapshot (line numbers are corrected to where the quote actually is);
   a demo citation must name a frame the observer saw; narration must quote
   the captions near its timestamp. Anything else is dropped and logged.
2. Status ceilings. demonstrated needs a demo frame (narration never
   counts); foundInCode needs a verified code quote; described needs a
   writeup or narration quote. Unsupported statuses fall to the strongest
   supported tier.
3. Independent verification. A second model call sees only each claim and
   the exact cited frames and code lines, and answers whether they show it.
   A "no" removes that tier. This pass can only lower a status.

`check()` is also used by generate.py's repair loop.

Output: .cache/<id>/grounded.json (the representation) and provenance.json
"""

import os
import re
import sys

import redact
from common import (
    ask, digest, image_block, load_stage, read_json, route, stage_path,
    workspace, write_json,
)

TIERS = ['inferred', 'described', 'foundInCode', 'demonstrated']
LIMITS = {'summary': 159, 'nodes': 6, 'label': 22, 'detail': 18, 'edge': 18,
          'mapping': 4, 'mappingLabel': 40, 'note': 139, 'questions': 4,
          'description': 110}
PITCH = re.compile(
    r'\b(seamless(ly)?|revolutionar\w*|cutting[- ]edge|powerful|effortless(ly)?|'
    r'empower\w*|intelligent(ly)?|smart|game[- ]chang\w*|next[- ]gen\w*|'
    r'AI[- ]powered|robust|state[- ]of[- ]the[- ]art|magic\w*)\b', re.I)
NARRATION_WINDOW = 15


def norm(text):
    text = (text or '').replace('’', "'").replace('‘', "'")
    text = text.replace('“', '"').replace('”', '"').replace('—', '-').replace('–', '-')
    return re.sub(r'\s+', ' ', text).strip().lower()


class Context:
    def __init__(self, sources, facts, extract):
        self.lines = {l['id']: l for l in extract['writeup']}
        self.frames = {f['t']: f for f in extract['demo']['frames']}
        self.frame_paths = {f['t']: f['path'] for f in sources['demo'].get('frames', [])}
        self.step = sources['demo'].get('step', 3)
        self.cues = extract['narration']['cues']
        self.root = sources['repo'].get('path')
        self._files = {}

    def file_lines(self, path):
        if path not in self._files:
            full = os.path.normpath(os.path.join(self.root or '', path))
            ok = self.root and full.startswith(self.root) and os.path.isfile(full)
            try:
                self._files[path] = open(full, encoding='utf-8').read().splitlines() if ok else None
            except UnicodeDecodeError:
                self._files[path] = None
        return self._files[path]


def resolve(cite, ctx):
    """(ref, tier, problem, fix): a Finalist Brief SourceRef or None."""
    source = cite.get('source')
    # Quotation marks around the quote are added on display, never doubled.
    quote = (cite.get('quote') or '').strip().strip('“”"\'‘’').strip()
    if source == 'writeup':
        line = ctx.lines.get(cite.get('line', ''))
        if not quote:
            if not line:
                return None, None, f'writeup line {cite.get("line")} does not exist', None
            return {'source': 'writeup', 'detail': f'{line["id"]}'}, 'described', None, None
        if line and norm(quote) in norm(line['text']):
            return ({'source': 'writeup', 'detail': f'“{quote}”'}, 'described', None, None)
        for other in ctx.lines.values():
            if norm(quote) in norm(other['text']):
                return ({'source': 'writeup', 'detail': f'“{quote}”'}, 'described', None,
                        f'writeup quote is on {other["id"]}, not {cite.get("line")}')
        return None, None, f'writeup quote not found: “{quote[:60]}”', None
    if source == 'repo':
        path = (cite.get('path') or '').strip().lstrip('./')
        lines = ctx.file_lines(path) if path else None
        if lines is None:
            return None, None, f'repository file does not exist: {path}', None
        if not quote:
            return ({'source': 'repo', 'at': path}, 'pathOnly',
                    f'code citation of {path} has no verbatim quote', None)
        hits = [i + 1 for i, l in enumerate(lines) if norm(quote) in norm(l)]
        if not hits:
            # A quote may span lines; match against the joined file.
            joined = norm(' '.join(lines))
            if norm(quote) not in joined:
                return None, None, f'quote not found in {path}: “{quote[:60]}”', None
            hits = [cite.get('from') or 1]
        start, end = cite.get('from'), cite.get('to') or cite.get('from')
        fix = None
        if start and end and end >= start and end - start <= 60 and any(start <= h <= end for h in hits):
            first, last = start, end
        else:
            target = start or hits[0]
            first = last = min(hits, key=lambda h: abs(h - target))
            if start:
                fix = f'{path}: quote is at line {first}, cited {start}-{end}'
        anchor = f'{path}#L{first}' + (f'-L{last}' if last != first else '')
        return {'source': 'repo', 'at': anchor, 'detail': f'{quote[:80]}'}, 'foundInCode', None, fix
    if source == 'demo':
        t = cite.get('t')
        if t in ctx.frames:
            return {'source': 'video', 't': t}, 'demonstrated', None, None
        near = [f for f in ctx.frames if t is not None and abs(f - t) <= ctx.step // 2 + 1]
        if near:
            return ({'source': 'video', 't': near[0]}, 'demonstrated', None,
                    f'demo t={t} moved to observed frame t={near[0]}')
        return None, None, f'no observed demo frame at t={t}', None
    if source == 'narration':
        t = cite.get('t')
        if t is None or not quote:
            return None, None, 'narration citation needs t and a verbatim quote', None
        window = [c for c in ctx.cues if abs(c['start'] - t) <= NARRATION_WINDOW]
        if norm(quote) in norm(' '.join(c['text'] for c in window)):
            start = next((int(c['start']) for c in window if norm(c['text'])[:20] in norm(quote)
                          or norm(quote)[:20] in norm(c['text'])), t)
            return ({'source': 'video', 't': start, 'detail': f'narration: “{quote}”'},
                    'described', None, None)
        return None, None, f'narration quote not found near t={t}: “{quote[:60]}”', None
    return None, None, f'unknown source {source}', None


def supported_tier(tiers):
    best = 'inferred'
    for tier in tiers:
        if tier in TIERS and TIERS.index(tier) > TIERS.index(best):
            best = tier
    return best


def evidence_items(draft):
    """(where, evidence) for every evidence block in the draft."""
    for lens in ('idea', 'integration'):
        for n in draft[lens]['nodes']:
            yield f'{lens}.{n["id"]}', n['evidence']
        for e in draft[lens]['edges']:
            if e.get('evidence'):
                yield f'{lens}.{e["from"]}>{e["to"]}', e['evidence']
    for m in draft['mapping']:
        yield f'mapping “{m["label"]}”', m['evidence']


def graph_problems(lens, graph):
    problems = []
    ids = [n['id'] for n in graph['nodes']]
    if len(set(ids)) != len(ids):
        problems.append(f'{lens}: node IDs must be unique')
    if not 2 <= len(ids) <= LIMITS['nodes']:
        problems.append(f'{lens}: {len(ids)} nodes; use 3 to {LIMITS["nodes"]}')
    if graph['topology'] == 'hub' and graph.get('focus') not in ids:
        problems.append(f'{lens}: a hub needs focus set to one of its node IDs')
    for e in graph['edges']:
        if e['from'] not in ids or e['to'] not in ids or e['from'] == e['to']:
            problems.append(f'{lens}: edge {e["from"]}→{e["to"]} must join two different existing nodes')
    flow = [(e['from'], e['to']) for e in graph['edges'] if e.get('kind', 'flow') == 'flow']
    remaining = set(ids)
    while remaining:
        roots = {i for i in remaining if not any(t == i and f in remaining for f, t in flow)}
        if not roots:
            problems.append(f'{lens}: flow edges form a cycle; mark the closing edge "feedback"')
            break
        remaining -= roots
    reached, changed = {ids[0]} if ids else set(), True
    while changed:
        changed = False
        for e in graph['edges']:
            if (e['from'] in reached) != (e['to'] in reached):
                reached |= {e['from'], e['to']}
                changed = True
    if ids and reached != set(ids):
        problems.append(f'{lens}: disconnected nodes {sorted(set(ids) - reached)}')
    if len(graph['description']) > LIMITS['description']:
        problems.append(f'{lens}: description is {len(graph["description"])} characters; '
                        f'at most {LIMITS["description"]}, or it is cut off on screen')
    if graph['topology'] in ('flow', 'layers') and not any('cycle' in p for p in problems):
        # The renderer draws an edge that skips a rank as a long curve on a
        # side rail; two of them cross and make the diagram hard to follow.
        ranks, pending = {}, list(ids)
        while pending:
            for i in list(pending):
                parents = [f for f, t in flow if t == i]
                if all(p in ranks for p in parents):
                    ranks[i] = max((ranks[p] + 1 for p in parents), default=0)
                    pending.remove(i)
        skipping = [f'{f}→{t}' for f, t in flow if ranks[t] - ranks[f] > 1]
        if len(skipping) > 1:
            problems.append(
                f'{lens}: edges {", ".join(skipping)} each jump over other nodes and would be '
                f'drawn as long crossing curves; restructure so at most one edge skips a '
                f'step (drop an edge that repeats another, merge nodes, or reorder)')
    for n in graph['nodes']:
        if len(n['label']) > LIMITS['label']:
            problems.append(f'{lens}.{n["id"]}: label “{n["label"]}” over {LIMITS["label"]} characters')
        if len(n.get('detail', '')) > LIMITS['detail']:
            problems.append(f'{lens}.{n["id"]}: detail “{n["detail"]}” over {LIMITS["detail"]} characters')
    for e in graph['edges']:
        if len(e.get('label', '')) > LIMITS['edge']:
            problems.append(f'{lens}: edge label “{e["label"]}” over {LIMITS["edge"]} characters')
    return problems


def check(draft, sources, facts, extract):
    """Everything the model should fix itself: structure, limits, citations."""
    ctx = Context(sources, facts, extract)
    problems = []
    if len(draft['summary']) > LIMITS['summary']:
        problems.append(f'summary is {len(draft["summary"])} characters; keep it under 150')
    if draft['summary'].count('. ') > 0:
        problems.append('summary must be one sentence')
    for lens in ('idea', 'integration'):
        problems += graph_problems(lens, draft[lens])
    ids = {lens: {n['id'] for n in draft[lens]['nodes']} for lens in ('idea', 'integration')}
    if len(draft['mapping']) > LIMITS['mapping']:
        problems.append(f'{len(draft["mapping"])} mapping observations; at most {LIMITS["mapping"]}')
    for m in draft['mapping']:
        if len(m['label']) > LIMITS['mappingLabel']:
            problems.append(f'mapping “{m["label"]}” over {LIMITS["mappingLabel"]} characters')
        if not m['idea'] or not set(m['idea']) <= ids['idea'] or not set(m['integration']) <= ids['integration']:
            problems.append(f'mapping “{m["label"]}” refers to unknown node IDs')
    if not 1 <= len(draft['questions']) <= LIMITS['questions']:
        problems.append(f'{len(draft["questions"])} questions; ask 1 to {LIMITS["questions"]}')
    if len({q['id'] for q in draft['questions']}) != len(draft['questions']):
        problems.append('question IDs must be unique')
    for q in draft['questions']:
        anchors = q['anchors']
        if not anchors or not anchors[0].get('node'):
            problems.append(f'question {q["id"]}: the first anchor must be a node')
        for a in anchors:
            lens = a.get('lens')
            if a.get('node') and a['node'] not in ids.get(lens, ()):
                problems.append(f'question {q["id"]}: anchor {lens}.{a["node"]} does not exist')
            if a.get('edge') and not any(
                    e['from'] == a['edge'][0] and e['to'] == a['edge'][-1]
                    for e in draft.get(lens, {}).get('edges', [])):
                problems.append(f'question {q["id"]}: anchor edge {a["edge"]} does not exist')
        if q['kind'] == 'mismatch' and {a.get('lens') for a in anchors} != {'idea', 'integration'}:
            problems.append(f'question {q["id"]}: a mismatch needs anchors in both graphs')
        if not q['question'].strip().endswith('?'):
            problems.append(f'question {q["id"]} must end with “?”')
        if len(q['question']) > 200:
            problems.append(f'question {q["id"]} is {len(q["question"])} characters; at most 200')
        if len(q['basis']) > 280:
            problems.append(f'question {q["id"]}: basis is {len(q["basis"])} characters; at most 280')
        for c in q['cites']:
            ref, _, problem, _ = resolve(c, ctx)
            if problem and not ref:
                problems.append(f'question {q["id"]}: {problem}')
    texts = [('summary', draft['summary'])] + [
        (f'{lens}.{n["id"]}', f'{n["label"]} {n.get("detail", "")} {n["evidence"]["note"]}')
        for lens in ('idea', 'integration') for n in draft[lens]['nodes']]
    for where, text in texts:
        hit = PITCH.search(text)
        if hit:
            problems.append(f'{where}: pitch word “{hit[0]}”; describe literally')
    for where, evidence in evidence_items(draft):
        if len(evidence['note']) > LIMITS['note']:
            problems.append(f'{where}: note over 130 characters')
        tiers = []
        for c in evidence['cites']:
            ref, tier, problem, _ = resolve(c, ctx)
            if problem:
                problems.append(f'{where}: {problem}')
            if ref:
                tiers.append(tier)
        if TIERS.index(evidence['status']) > TIERS.index(supported_tier(tiers)):
            problems.append(f'{where}: status {evidence["status"]} is not supported by its '
                            f'valid citations ({", ".join(tiers) or "none"})')
        frame = evidence.get('frame')
        if frame is not None and frame not in ctx.frames:
            problems.append(f'{where}: frame t={frame} is not an observed frame')
    problems += absence_problems(draft, ctx)
    problems += attribution_problems(draft, ctx, facts)
    return problems


DEMO_WORD = re.compile(r'\b(demo|video|frames?|recording|screencast)\b', re.I)
ABSENCE = re.compile(
    r"\b(not|never|n't|no longer)\s+(?:\w+\s+){0,2}?(show\w*|visible|seen|appear\w*|"
    r"demonstrated|observed|captured|included)\b|\b(starts|begins|opens|jumps)\s+"
    r"(at|on|with|straight)\b|\bskip\w*\b|\bwithout showing\b", re.I)
UNUSED_WORD = re.compile(
    r'\b(unused|dead code|unreachable|never (imported|used|called|runs?|reached)|'
    r'not (imported|used|called|reached|wired)|nothing (imports|calls)|no callers?)\b', re.I)


def judge_texts(draft):
    """(where, text) for everything a judge reads."""
    yield 'summary', draft['summary']
    for lens in ('idea', 'integration'):
        yield f'{lens} description', draft[lens].get('description', '')
    for where, evidence in evidence_items(draft):
        yield where, evidence['note']
    for m in draft['mapping']:
        yield f'mapping “{m["label"]}”', m['label']
    for q in draft['questions']:
        yield f'question {q["id"]}', f'{q["question"]} {q["basis"]}'
    for key, d in draft.get('dimensions', {}).items():
        yield f'dimension {key}', d.get('note', '')


def absence_problems(draft, ctx):
    """Frames are samples, so "the demo does not show X" is never evidence."""
    if not ctx.frames:
        return []
    problems = []
    for where, text in judge_texts(draft):
        for sentence in re.split(r'(?<=[.;?!])\s+|,\s+so\s+', text):
            if DEMO_WORD.search(sentence) and ABSENCE.search(sentence) and 'sampled' not in sentence:
                problems.append(
                    f'{where}: claims something is absent from the demo (“{sentence.strip()[:90]}”). '
                    f'Frames are samples every {ctx.step} s, so it may have happened between them. '
                    f'Write "not observed in the sampled frames", or drop the point.')
    return problems


def attribution_problems(draft, ctx, facts):
    """Citations of code that never runs must say so."""
    never_imported = {f['at'] for f in facts.get('files', []) if f.get('reachable') is False}
    uncalled = [m for m in facts.get('endpointMethods', [])
                if not m['method'].startswith('_')
                and not m.get('calledByApp') and not m.get('calledNatively')]
    items = [(where, ev['note'], ev['cites']) for where, ev in evidence_items(draft)]
    items += [(f'question {q["id"]}', f'{q["question"]} {q["basis"]}', q['cites'])
              for q in draft['questions']]
    problems = []
    for where, text, cites in items:
        if UNUSED_WORD.search(text):
            continue
        for c in cites:
            ref, _, _, _ = resolve(c, ctx) if c.get('source') == 'repo' else (None,) * 4
            if not ref or '#L' not in ref.get('at', ''):
                continue
            path, lines = ref['at'].split('#L')
            first, _, last = lines.partition('-L')
            first, last = int(first), int(last or first)
            if path in never_imported:
                problems.append(
                    f'{where}: cites {path}, which nothing reachable from the app\'s main.dart '
                    f'imports, so it never runs. Cite the code the app actually runs, or say '
                    f'plainly that this file is unused.')
            for m in uncalled:
                if m['at'] == path and first <= m['endLine'] and last >= m['line']:
                    problems.append(
                        f'{where}: cites {m["endpoint"]}.{m["method"]}, which the app never '
                        f'calls. Cite the code that actually runs, or say plainly that this '
                        f'method is never called.')
    return problems


# ---------------------------------------------------------------- verify

VERIFIER = """You check evidence for a hackathon review tool. For each claim \
you get a one-line note and the exact evidence cited for it: demo video \
frames and/or source code lines. Judge each kind of evidence separately and \
strictly:
- demo: "yes" only if the cited frames themselves visibly show what the note \
claims (a behaviour working, not merely a screen or button existing, unless \
the note only claims the screen exists). Narration is not provided and does \
not count.
- code: "yes" only if the cited lines implement or directly contain what the \
note claims, and are the code the note attributes it to. A note about what \
the app or a screen does needs lines that show that screen or caller \
reaching the cited code; code that merely exists, or serves another screen, \
is a "no".
A claim labelled "question" is a judge question with its basis. Check the \
factual statements in the basis and any premise in the question; the \
question itself may leave things open.
Answer "na" when that kind of evidence was not cited. Give a short reason \
naming what is missing when you answer "no"."""

VERDICT = {
    'type': 'object',
    'properties': {'results': {'type': 'array', 'items': {
        'type': 'object',
        'properties': {
            'id': {'type': 'string'},
            'demo': {'type': 'string', 'enum': ['yes', 'no', 'na']},
            'code': {'type': 'string', 'enum': ['yes', 'no', 'na']},
            'reason': {'type': 'string'},
        },
        'required': ['id', 'demo', 'code', 'reason'],
    }}},
    'required': ['results'],
}


def claim_blocks(cid, evidence, refs, ctx):
    """What the verifier sees for one claim: its note and the exact cited
    frames and code lines (with two lines of context either side)."""
    blocks = [{'type': 'text', 'text': f'\n### Claim {cid}\nNote: {evidence["note"]}'}]
    for ref in refs:
        if ref['source'] == 'video' and 'narration' not in ref.get('detail', ''):
            blocks.append({'type': 'text', 'text': f'Demo frame at t={ref["t"]}:'})
            blocks.append(image_block(ctx.frame_paths[ref['t']]))
        elif ref['source'] == 'repo' and '#L' in ref.get('at', ''):
            path, lines = ref['at'].split('#L')
            first, _, last = lines.partition('-L')
            first, last = int(first), int(last or first)
            text = ctx.file_lines(path)
            lo, hi = max(1, first - 2), min(len(text), last + 2)
            blocks.append({'type': 'text', 'text': f'Code {path} lines {lo}-{hi}:\n' + '\n'.join(
                f'{i:4d}| {text[i - 1]}' for i in range(lo, hi + 1))})
    return blocks


def id_slug(text):
    return re.sub(r'[^a-z0-9]+', '-', norm(text).replace('"', '')).strip('-')


def match_ids(returned, cids):
    """Maps each verifier result ID to the claim it clearly means.

    The verifier sometimes rewrites an ID: "q1" for "question q1", or
    "mapping-offline" for mapping “Offline-first → online client only”.
    Accepted, in order: the exact ID; the same ID ignoring case, quotes and
    punctuation; a question's short form; the full ID without its kind
    word; and a kind prefix plus words that
    occur in exactly one claim of that kind. Anything ambiguous stays
    unmatched. Returns ({result ID: claim ID}, [unmatched result IDs])."""
    slugs = {cid: id_slug(cid) for cid in cids}
    matched, unmatched, taken = {}, [], set()
    for rid in returned:
        cid = rid if rid in cids else None
        if cid is None:
            same = [c for c, sl in slugs.items() if sl == id_slug(rid)]
            cid = same[0] if len(same) == 1 else None
        if cid is None and f'question {rid}' in cids:
            cid = f'question {rid}'
        if cid is None:
            # The whole ID with its kind word ("mapping", "node …") left off.
            bare = [c for c, sl in slugs.items() if sl.partition('-')[2] == id_slug(rid)]
            cid = bare[0] if len(bare) == 1 else None
        if cid is None:
            kind, _, rest = id_slug(rid).partition('-')
            words = [w for w in rest.split('-') if len(w) > 2]
            hits = [c for c, sl in slugs.items() if sl.startswith(kind + '-')
                    and words and all(w in sl.split('-') or w in sl for w in words)]
            cid = hits[0] if len(hits) == 1 else None
        if cid is None or cid in taken:
            unmatched.append(rid)
        else:
            matched[rid] = cid
            taken.add(cid)
    return matched, unmatched


NO_VERDICT = {'demo': 'no', 'code': 'no', 'missing': True,
              'reason': 'The verifier returned no verdict for this claim, even after a retry.'}


def verify(sid, claims, ctx, log=None):
    """claims: [(id, evidence, resolved refs)] with demo or code support.

    A verdict depends only on the verifier model, the claim's note and the
    evidence it is shown, so it is stored under a fingerprint of exactly
    those. Claims whose fingerprint already has a verdict (unchanged since an
    earlier check in this or a previous run) are not sent again; everything
    new or changed is checked in one call.

    Fails closed: a claim that gets no verdict is sent once more on its own
    call; if it still has none, it gets NO_VERDICT, which lowers it like a
    refutation. NO_VERDICT is never stored, so a later run asks again.
    Recovered and unmatched IDs are printed and appended to [log]."""
    if not claims:
        return {}
    log = log if log is not None else []
    r = route('verify')
    store_path = workspace(sid, 'llm', 'verdicts.json')
    store = read_json(store_path) if os.path.exists(store_path) else {}
    blocks = {cid: claim_blocks(cid, evidence, refs, ctx) for cid, evidence, refs in claims}
    # The claim ID only labels the block; it is not part of the fingerprint.
    prints = {cid: digest({'provider': r['provider'], 'model': r['model'],
                           'blocks': [b if b['type'] != 'text' or not b['text'].startswith('\n### Claim')
                                      else {'note': b['text'].split('Note: ', 1)[1]} for b in blocks[cid]]})
              for cid in blocks}
    todo = [cid for cid, _, _ in claims if prints[cid] not in store]
    for attempt, name in enumerate(('verify', 'verify-retry')):
        pending = [cid for cid in todo if prints[cid] not in store]
        if not pending:
            break
        if attempt:
            note = f'no verdict for {", ".join(pending)}; asking once more'
            print(f'  verifier: {note}', flush=True)
            log.append(note)
        content = [{'type': 'text', 'text': f'{len(pending)} claims follow.'}]
        for cid in pending:
            content += blocks[cid]
        verdict = ask(sid, name, 'verify', VERIFIER, content, VERDICT)
        results = verdict['results']
        matched, unmatched = match_ids([x['id'] for x in results], pending)
        for result in results:
            cid = matched.get(result['id'])
            if cid:
                if cid != result['id']:
                    note = f'verifier ID “{result["id"]}” read as {cid}'
                    print(f'  {note}', flush=True)
                    log.append(note)
                store[prints[cid]] = {k: result[k] for k in ('demo', 'code', 'reason')}
        if unmatched:
            note = f'verifier IDs matching no claim: {", ".join(unmatched)}'
            print(f'  {note}', flush=True)
            log.append(note)
        write_json(store_path, store)
    missing = [cid for cid, _, _ in claims if prints[cid] not in store]
    if missing:
        note = f'no verdict after retry, treated as refuted: {", ".join(missing)}'
        print(f'  verifier: {note}', flush=True)
        log.append(note)
    print(f'  verifier: {len(todo)} claims checked, {len(claims) - len(todo)} unchanged', flush=True)
    return {cid: {'id': cid, **(store[prints[cid]] if prints[cid] in store else NO_VERDICT)}
            for cid, _, _ in claims}


def question_claim(q, refs):
    """A judge question as a verifiable claim: its basis against its evidence."""
    return (f'question {q["id"]}', {'note': f'Question: {q["question"]} Basis: {q["basis"]}'},
            [r for r in refs if r['source'] == 'video' and 'narration' not in r.get('detail', '')
             or r['source'] == 'repo' and '#L' in r.get('at', '')])


def claims_to_verify(draft, ctx):
    """Resolved demo and code support for every demonstrated/foundInCode
    claim and every judge question."""
    claims = []
    for where, evidence in evidence_items(draft):
        if evidence['status'] not in ('demonstrated', 'foundInCode'):
            continue
        refs = [ref for ref, tier, _, _ in (resolve(c, ctx) for c in evidence['cites'])
                if ref and tier in ('demonstrated', 'foundInCode')]
        if refs:
            claims.append((where, evidence, refs))
    for q in draft['questions']:
        claim = question_claim(q, [ref for ref, _, _, _ in (resolve(c, ctx) for c in q['cites']) if ref])
        if claim[2]:
            claims.append(claim)
    return claims


def verification_problems(sid, draft, sources, facts, extract):
    """The verifier's objections, phrased for the generator's repair loop."""
    ctx = Context(sources, facts, extract)
    problems = []
    for where, verdict in verify(sid, claims_to_verify(draft, ctx), ctx).items():
        # The generator cannot fix a missing verdict; grounding asks again
        # and lowers the claim if there is still none.
        if verdict.get('missing'):
            continue
        for kind in ('demo', 'code'):
            if verdict[kind] == 'no':
                problems.append(
                    f'{where}: an independent check of the cited {kind} evidence says it does '
                    f'not show the ' + ('basis' if where.startswith('question ') else 'note') +
                    f': {verdict["reason"]} Cite evidence that shows it (for code, the full '
                    f'range and the code actually reached), ' + (
                        'correct the basis, or drop the question.' if where.startswith('question ')
                        else 'narrow the note to what is shown, or lower the status.'))
    return problems


def main(sid):
    sources = load_stage(sid, 'sources')
    facts = load_stage(sid, 'repo_facts')
    extract = load_stage(sid, 'extract')
    draft = load_stage(sid, 'draft')['draft']
    ctx = Context(sources, facts, extract)
    log = {'dropped': [], 'fixed': [], 'capped': [], 'verified': [], 'lowered': [],
           'unresolved': check(draft, sources, facts, extract)}
    print(f'· grounding {sid}')

    # 1–2: resolve citations and cap statuses.
    resolved = []
    for where, evidence in evidence_items(draft):
        refs, tiers = [], []
        for c in evidence['cites']:
            ref, tier, problem, fix = resolve(c, ctx)
            if fix:
                log['fixed'].append(f'{where}: {fix}')
            if ref is None or tier == 'pathOnly':
                log['dropped'].append(f'{where}: {problem}')
                continue
            refs.append(ref)
            tiers.append(tier)
        ceiling = supported_tier(tiers)
        if TIERS.index(evidence['status']) > TIERS.index(ceiling):
            log['capped'].append(f'{where}: {evidence["status"]} → {ceiling}')
            evidence['status'] = ceiling
        resolved.append((where, evidence, refs, tiers))

    # 3: independent verification of demo and code support.
    claims = [(where, ev, refs) for where, ev, refs, tiers in resolved
              if ev['status'] in ('demonstrated', 'foundInCode')]
    log['verifier'] = []
    verdicts = verify(sid, claims, ctx, log['verifier'])
    for where, evidence, refs, tiers in resolved:
        verdict = verdicts.get(where)
        if verdict:
            log['verified'].append({'claim': where, **{k: verdict[k] for k in ('demo', 'code', 'reason')}})
            allowed = set(t for t in tiers if t == 'described')
            if verdict['demo'] == 'yes':
                allowed.add('demonstrated')
            if verdict['code'] == 'yes':
                allowed.add('foundInCode')
            ceiling = supported_tier(allowed)
            if TIERS.index(evidence['status']) > TIERS.index(ceiling):
                log['lowered'].append(f'{where}: {evidence["status"]} → {ceiling} ({verdict["reason"]})')
                evidence['status'] = ceiling
        # A frame illustrates only a demonstrated element. Without the
        # model's choice, the first cited (and verified) frame is shown.
        frame = evidence.pop('frame', None)
        if frame is None:
            frame = next((r['t'] for r in refs if r['source'] == 'video'
                          and 'narration' not in r.get('detail', '')), None)
        if frame is not None and evidence['status'] == 'demonstrated' and frame in ctx.frames:
            evidence['frame'] = {'image': f'assets/evidence/serverpod/{sid}-{frame}.jpg',
                                 'source': 'video', 't': frame}
            if not any(r.get('t') == frame and r['source'] == 'video' for r in refs):
                refs.append({'source': 'video', 't': frame})
        evidence['refs'] = refs
        evidence.pop('cites', None)

    for q in draft['questions']:
        refs = []
        for c in q.pop('cites'):
            ref, tier, problem, fix = resolve(c, ctx)
            if ref and tier != 'pathOnly':
                refs.append(ref)
            else:
                log['dropped'].append(f'question {q["id"]}: {problem}')
        q['refs'] = refs

    # A question whose basis the verifier refutes, or never confirms, is not
    # shown to judges.
    question_claims = [c for c in (question_claim(q, q['refs']) for q in draft['questions']) if c[2]]
    refuted = {}
    for where, verdict in verify(sid, question_claims, ctx, log['verifier']).items():
        log['verified'].append({'claim': where, **{k: verdict[k] for k in ('demo', 'code', 'reason')}})
        if 'no' in (verdict['demo'], verdict['code']):
            refuted[where] = ('no verdict from the verifier' if verdict.get('missing')
                              else 'basis refuted by the verifier')
    for q in list(draft['questions']):
        why = refuted.get(f'question {q["id"]}')
        if why and len(draft['questions']) > 1:
            log['dropped'].append(f'question {q["id"]}: {why}')
            draft['questions'].remove(q)

    # Last, after every citation was checked against the original source:
    # judge-facing text never repeats a secret value.
    known = redact.secrets_in([e['text'] for e in facts.get('excerpts', [])]
                              + [sources.get('writeup', '')])
    log['redacted'] = [f'{where}: {n}' for where, n in redact.redact_review(draft, known)]
    # Incidental personal contact details seen in the demo are not repeated.
    allowed = redact.contacts_allowed([e['text'] for e in facts.get('excerpts', [])]
                                      + [sources.get('writeup', '')])
    log['contacts'] = [f'{where}: {n}' for where, n in redact.mask_contacts(draft, allowed)]

    write_json(stage_path(sid, 'grounded'), draft)
    # The log quotes verifier reasons, which may repeat a value too.
    redact.redact_review(log, known)
    write_json(stage_path(sid, 'provenance'), log)
    for key in ('unresolved', 'dropped', 'fixed', 'capped', 'lowered', 'redacted', 'contacts',
                'verifier'):
        print(f'  {key}: {len(log[key])}')
        for item in log[key]:
            print(f'    - {item}')


if __name__ == '__main__':
    main(sys.argv[1])
