"""Jev-normalized claims: what the team says, one cited writeup line each.

Reuses the triage pilot's numbered writeup lines (the same L000 IDs), its
per-line kind (capability, implementation, outcome, plan, context) and its
profile. Adds one typed Choice per line: which topic the line makes a claim
about. Jev only classifies what the writeup *says*. It is never asked whether
a claim is true, important or good; investigators check claims against the
repository afterwards.

Output: .cache/<id>/runs/<profile>/claims.json
"""

import hashlib
import json
import os
import sys

from common import (
    PILOT, _common, _pilot, load_stage, log_call, read_json, stage_path,
    workspace, write_json,
)

VERSION = 'claims-1'
TOPICS = {
    'core_capability': 'Says what the product does for its users',
    'user_workflow': 'Describes a step or interaction a user performs in the app',
    'ai_model': 'Says an AI or machine-learning model, embedding, LLM or inference is used',
    'sponsor_tech': 'Says what Serverpod does in the project: endpoints, database or ORM, '
                    'authentication, streaming, scheduled jobs or deployment',
    'integration': 'Names an external service, API or data source the app connects to or ingests',
    'data_or_scale': 'States an amount of data, a dataset size, a speed or another number the '
                     'system achieves',
    'unfinished': 'Says something is unfinished, simulated, mocked, planned or not working yet',
    'other': 'None of these',
}
PRICE = 0.042  # USD per million Jev input tokens; output is free.


def jev_module():
    saved = sys.modules.get('common')
    sys.modules['common'] = _common
    try:
        return _pilot('jev_extract')
    finally:
        if saved is None:
            sys.modules.pop('common', None)
        else:
            sys.modules['common'] = saved


def topic_question(line):
    return {'type': 'choice',
            'instructions': (f"Line {line['id']} of `writeup` (under the heading "
                             f"\"{line['section'] or 'none'}\") makes a statement. Which topic "
                             f"is it a claim about?"),
            'criteria': TOPICS}


def run(sid):
    jev = jev_module()
    devpost = read_json(os.path.join(PILOT, 'data', 'devpost.json'))
    submission = next(s for s in devpost['submissions'] if s['id'] == sid)
    pilot = read_json(os.path.join(PILOT, 'data', 'jev.json'))['submissions'][sid]
    lines = jev.split_lines(submission['writeup'])
    assert [l['id'] for l in lines] == [l['id'] for l in pilot['lines']], 'writeup lines changed'
    kinds = {l['id']: l.get('kind') for l in pilot['lines']}
    state = jev.state_for(submission, lines)
    cache_path = workspace(sid, 'llm', 'jev-claims.json')
    cache = read_json(cache_path) if os.path.exists(cache_path) else {}
    content = [l for l in lines if not l['heading'] and kinds.get(l['id']) != 'context']
    topics = {}
    for start in range(0, len(content), jev.LINES_PER_REQUEST):
        chunk = content[start:start + jev.LINES_PER_REQUEST]
        questions = {l['id']: topic_question(l) for l in chunk}
        body = {'model': jev.MODEL, 'state': state, 'questions': questions}
        key = hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest()
        hit = key in cache
        answer = jev.ask(_common.load_env().get('TYPESAFE_API_KEY'), state, questions, cache)
        write_json(cache_path, cache)
        usage = answer['usage']
        log_call(sid, 'claims', f'jev-topics{start // jev.LINES_PER_REQUEST}', key[:16],
                 {'provider': 'jev', 'model': answer['model'], 'usage': usage,
                  'costUsd': usage['input_tokens'] * PRICE / 1e6}, hit)
        topics.update(answer['answers'])
    claims = []
    for l in content:
        t = topics.get(l['id'])
        if not t or t['choice'] == 'other':
            continue
        claims.append({'id': l['id'], 'text': l['text'], 'section': l['section'],
                       'kind': kinds.get(l['id']), 'topic': t['choice'],
                       'p': round(t['probabilities'][t['choice']], 3)})
    return {'version': VERSION, 'model': jev.MODEL, 'claims': claims,
            'profile': pilot['profile'], 'unfinishedLine': pilot.get('unfinishedLine')}


def main(sid):
    result = run(sid)
    write_json(stage_path(sid, 'claims'), result)
    counts = {}
    for c in result['claims']:
        counts[c['topic']] = counts.get(c['topic'], 0) + 1
    print(f'· claims for {sid}: {len(result["claims"])} {counts}')


if __name__ == '__main__':
    main(sys.argv[1])
