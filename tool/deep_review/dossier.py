"""Evidence dossier: Jev claims + static candidates + narrow Gemini investigations.

The discovery layer that could later feed Claude synthesis. It never writes
judge-facing prose and never decides what matters. Every investigator
answers one fixed proposition about each item it is given:

  claims      is what this writeup line claims implemented?
              (items: Jev-normalized claims; plans excluded)
  candidates  is this static-analysis candidate real at runtime?
              (items: static_checks.py candidates)
  paths       does this entry point reach storage or an external service at
              runtime? (items: app calls into the server, scheduled jobs)
  dataflow    is what is produced actually consumed, with compatible types
              and values? (items: tables, jobs, external data sources)
  demo        does repository code produce this demo behaviour or text?
              (items: observed frames, on-screen text not found in the repo)

Answers are supported / contradicted / unresolved with verbatim citations.
Every citation is resolved by ground.resolve() exactly as in grounding; an
answer other than unresolved without a valid citation is downgraded to
unresolved. All investigators share one context (the same sources the
generator sees), sent first so Gemini's implicit cache serves it to the
later calls.

Output: .cache/<id>/runs/<profile>/dossier.json and dossier.md
"""

import concurrent.futures
import json
import os
import sys

import claims as jev_claims
import ground
import static_checks
from common import ask, image_block, load_stage, stage_path, write_json
from generate import CITE, facts_text

VERSION = 'dossier-6'
# Multi-hop tracing gains from more thinking; per-item checks do not (Pulse development).
DEEP = {'paths', 'dataflow'}
MAX_ITEMS = 45

SYSTEM = """You investigate one narrow question at a time about a hackathon \
software submission, for an evidence file that other steps will use. You \
receive the submission's sources (writeup lines, demo frame observations, \
deterministic repository facts and line-numbered source excerpts) and then a \
task with a list of items. For EACH item, decide whether the stated \
proposition holds, using only these sources:

- supported: the sources show the proposition holds.
- contradicted: the sources show it does not hold (for example the code is \
absent where it would have to be, stubbed, simulated, hard-coded, never \
called, never scheduled, or does something else).
- unresolved: the sources shown do not settle it.

Rules:
- Cite every supported or contradicted answer. For code, give the path, the \
line range that shows it and a verbatim quote from inside that range. For \
an absence, cite the place where the missing thing would have to be (the \
method, the registration, the handler). For the demo, give the frame's t. \
For the writeup, give the line ID and a verbatim quote.
- finding: one literal, neutral sentence (at most 220 characters) stating \
the fact, e.g. "The job is registered in server.dart but no code schedules \
it." No opinions, no importance, no advice, no adjectives about quality.
- Do not judge merit and do not summarize the project. Answer only the \
items given, in order, one answer per item."""

ANSWER = {
    'type': 'object',
    'properties': {'answers': {'type': 'array', 'items': {
        'type': 'object',
        'properties': {
            'item': {'type': 'string'},
            'verdict': {'type': 'string', 'enum': ['supported', 'contradicted', 'unresolved']},
            'finding': {'type': 'string'},
            'cites': {'type': 'array', 'items': CITE},
        },
        'required': ['item', 'verdict', 'finding', 'cites'],
    }}},
    'required': ['answers'],
}

TASKS = {
    'claims': 'Proposition for each item: what this writeup line claims is implemented '
              'in the repository at its deadline snapshot (all of it, as described). '
              'Where only part is implemented, answer contradicted and say which part is missing.',
    'candidates': 'Each item is a candidate produced by a static pattern check, which can be '
                  'a false positive. Proposition for each item: the candidate is real at '
                  'runtime (for example the class really is never used, the job really never '
                  'runs, the value really is never written). Answer contradicted if the code '
                  'shows it is a false positive, and say why.',
    'paths': 'Proposition for each item: at least one of the listed call sites is reached '
             'from a UI action, a screen load or a schedule, and from there the call reaches '
             'its endpoint, the services it relies on and its storage or external service at '
             'runtime, and the data it needs exists. Consider every listed call site and name '
             'the one that is reached. Answer contradicted at the first break you can cite (an '
             'empty handler, a call site nothing reaches, a job never scheduled, a value never '
             'written, data fetched but never parsed or never stored) and name that break.',
    'dataflow': 'Proposition for each item: what is produced here is produced by code that '
                'actually runs, and what consumes it reads it with compatible types, formats '
                'and field values. Answer contradicted at the first mismatch you can cite.',
    'demo': 'Proposition for each item: code in this repository produces what the demo '
            'shows here (the behaviour, or the on-screen text). For on-screen text, typed '
            'user input or values loaded at runtime count as supported only if code that '
            'accepts or loads them exists. Answer contradicted if the code for that control '
            'does something else (for example an empty handler) or if no code could produce it.',
}


def items(claims, static, facts, extract):
    out = {
        'claims': [{'item': c['id'], 'text': f'{c["id"]} [{c["topic"]}]: {c["text"]}'}
                   for c in claims['claims'] if c['kind'] != 'plan' and c['topic'] != 'unfinished'],
        'candidates': [{'item': c['id'], 'text': f'{c["id"]} [{c["check"]}]: {c["detail"]} — at '
                        + '; '.join(f'{e["path"]}:{e["line"]}' if 'path' in e else f't={e["t"]}'
                                    for e in c['evidence'])}
                       for c in static['candidates'] if c['check'] != 'demo.textNotInRepo'],
    }
    calls = {}
    for c in facts.get('appCalls', []):
        calls.setdefault(c['call'], []).append(f'{c["at"]}:{c["line"]}')
    inv = static['inventory']
    out['paths'] = ([{'item': f'P{i:02d}', 'text': f'P{i:02d}: app call {call} (every call site: {", ".join(where)})'}
                     for i, (call, where) in enumerate(sorted(calls.items()))] +
                    [{'item': f'J{i:02d}', 'text': f'J{i:02d}: scheduled job "{name}" ({ev["path"]}:{ev["line"]})'}
                     for i, (name, ev) in enumerate(sorted(inv['jobsScheduled'].items()))])
    out['dataflow'] = ([{'item': f'T{i:02d}', 'text': f'T{i:02d}: table or model "{t}" — written at '
                         f'{", ".join(inv["tableWrites"].get(t, [])) or "no statically resolved site"}; read at '
                         f'{", ".join(inv["tableReads"].get(t, [])) or "no statically resolved site"}'
                         + (f' (writes whose table could not be resolved: {", ".join(inv["unresolvedWrites"][:6])})'
                            if inv['unresolvedWrites'] and t not in inv['tableWrites'] else '')}
                        for i, t in enumerate(sorted(set(inv['tableWrites']) | set(inv['tableReads'])))] +
                       [{'item': f'X{i:02d}', 'text': f'X{i:02d}: external source {host} used at {", ".join(where)}'}
                        for i, (host, where) in enumerate(sorted(inv['hosts'].items()))])
    frames = [f for f in extract['demo']['frames'] if f.get('changed', True)]
    out['demo'] = ([{'item': f'F{f["t"]:03d}', 'text': f'F{f["t"]:03d}: frame t={f["t"]}: {f["shows"]} '
                     f'(on-screen text: {f["text"][:200]})'} for f in frames] +
                   # A neutral subject, not the check's claim, so every demo item is judged
                   # against the same proposition (code produces what is shown).
                   [{'item': c['id'], 'text': f'{c["id"]}: on-screen text at {c["subject"]}: '
                     + ' · '.join(f'"{e["text"][:90]}"' for e in c['evidence'])}
                    for c in static['candidates'] if c['check'] == 'demo.textNotInRepo'])
    return {k: v[:MAX_ITEMS] for k, v in out.items() if v}


def investigate(sid, name, shared, task_items, frames):
    content = shared + [{'type': 'text', 'text':
                         f'# Task: {name}\n{TASKS[name]}\n\nItems:\n' +
                         '\n'.join(i['text'] for i in task_items)}]
    if frames:
        content += [block for f in frames for block in
                    ({'type': 'text', 'text': f'Frame t={f["t"]}:'}, image_block(f['path']))]
    stage = 'investigate-deep' if name in DEEP else 'investigate'
    return ask(sid, f'investigate-{name}', stage, SYSTEM, content, ANSWER)['answers']


def ground_answers(name, answers, task_items, ctx):
    known = {i['item'] for i in task_items}
    out, answered = [], set()
    for a in answers:
        # Models sometimes echo the whole item line; its ID is the part before ':'.
        a['item'] = a['item'].split(':')[0].strip()
        answered.add(a['item'])
        refs, dropped = [], []
        for c in a.get('cites', []):
            ref, tier, problem, _ = ground.resolve(c, ctx)
            if ref and tier != 'pathOnly':
                refs.append(ref)
            else:
                dropped.append(problem or 'no verbatim quote')
        verdict = a['verdict']
        if verdict != 'unresolved' and not refs:
            verdict, dropped = 'unresolved', dropped + ['no valid citation: downgraded to unresolved']
        out.append({'investigator': name, 'item': a['item'], 'known': a['item'] in known,
                    'verdict': verdict, 'modelVerdict': a['verdict'], 'finding': a['finding'],
                    'refs': refs, 'dropped': dropped})
    out += [{'investigator': name, 'item': i, 'known': True, 'verdict': 'unresolved',
             'modelVerdict': None, 'finding': 'No answer was returned for this item.',
             'refs': [], 'dropped': []} for i in sorted(known - answered)]
    return out


def run(sid):
    sources = load_stage(sid, 'sources')
    facts = load_stage(sid, 'repo_facts')
    extract = load_stage(sid, 'extract')
    claims = jev_claims.run(sid)
    write_json(stage_path(sid, 'claims'), claims)
    static = {'version': static_checks.VERSION,
              'candidates': static_checks.run(sources, facts, extract),
              'inventory': static_checks.inventory(sources)}
    write_json(stage_path(sid, 'static'), static)
    tasks = items(claims, static, facts, extract)
    shared = [{'type': 'text', 'text': facts_text(sources, facts, extract)}]
    frame_list = [f for f in sources['demo'].get('frames', [])]
    ctx = ground.Context(sources, facts, extract)
    names = list(tasks)
    results = {}
    # The first call alone, so the shared context is cached for the rest.
    first = names[0]
    results[first] = investigate(sid, first, shared, tasks[first], None)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = {n: pool.submit(investigate, sid, n, shared, tasks[n],
                                  frame_list if n == 'demo' else None) for n in names[1:]}
        for n, f in futures.items():
            results[n] = f.result()
    answers = [a for n in names for a in ground_answers(n, results[n], tasks[n], ctx)]
    return {'version': VERSION, 'staticVersion': static_checks.VERSION,
            'claimsVersion': jev_claims.VERSION, 'items': tasks, 'answers': answers,
            'claims': claims['claims'], 'candidates': static['candidates']}


def render(d):
    lines = [f'# Evidence dossier ({d["version"]})', '']
    for verdict in ('contradicted', 'unresolved', 'supported'):
        group = [a for a in d['answers'] if a['verdict'] == verdict]
        lines.append(f'## {verdict} ({len(group)})')
        for a in group:
            refs = '; '.join(r.get('at') or f't={r.get("t")}' if r['source'] != 'writeup'
                             else r.get('detail', '')[:60] for r in a['refs'])
            lines.append(f'- [{a["investigator"]} {a["item"]}] {a["finding"]}  ⟨{refs}⟩'
                         + (f'  (model said {a["modelVerdict"]})' if a['modelVerdict'] != verdict else ''))
        lines.append('')
    return '\n'.join(lines)


def main(sid):
    print(f'· building evidence dossier for {sid}')
    d = run(sid)
    write_json(stage_path(sid, 'dossier'), d)
    with open(stage_path(sid, 'dossier').replace('.json', '.md'), 'w', encoding='utf-8') as f:
        f.write(render(d))
    counts = {}
    for a in d['answers']:
        counts.setdefault(a['investigator'], {}).setdefault(a['verdict'], 0)
        counts[a['investigator']][a['verdict']] += 1
    print(f'  {len(d["answers"])} answers: {json.dumps(counts)}')


if __name__ == '__main__':
    main(sys.argv[1])
