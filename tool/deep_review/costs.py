"""Model usage and cost of a deep-review run.

    [DEEP_REVIEW_PROFILE=<name>] python3 costs.py <submission-id> [--all]

Reads the run ledger `.cache/<id>/runs/<profile>/calls.jsonl`, which `ask()`
appends to on every model call, cached or not. The report covers the latest
run: each call's tokens and what it cost when it was made. "Spent now"
counts only calls that were not served from the cache. --all also sums every response
cached for the submission, including drafts from earlier pipeline versions,
which is what developing the pipeline cost.

Claude costs are the CLI's own `total_cost_usd` (list price). Gemini costs
are computed from routing.json prices (list price, no promotions).
"""

import argparse
import json
import os
import time

from common import PROFILE, read_json, run_dir, workspace

STAGES = ('claims', 'observe', 'investigate', 'investigate-deep', 'generate', 'verify')


def start_run(sid):
    with open(os.path.join(run_dir(sid), 'calls.jsonl'), 'a', encoding='utf-8') as f:
        f.write(json.dumps({'run': time.strftime('%Y-%m-%dT%H:%M:%S')}) + '\n')


def latest_run(sid):
    path = os.path.join(run_dir(sid), 'calls.jsonl')
    if not os.path.exists(path):
        return []
    calls = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            entry = json.loads(line)
            if 'run' in entry:
                calls = []
            else:
                calls.append(entry)
    return calls


def summarize(calls):
    """Per stage. A request repeated within a run (ground.py re-asks the
    verifier's last question) is one call: the cache answers the repeat."""
    rows, seen = {}, set()
    for c in calls:
        if c['key'] in seen:
            continue
        seen.add(c['key'])
        row = rows.setdefault(c['stage'], {'calls': 0, 'fresh': 0, 'models': set(),
                                           'input': 0, 'cacheWrite': 0, 'cacheRead': 0,
                                           'output': 0, 'cost': 0.0, 'spent': 0.0})
        row['calls'] += 1
        row['fresh'] += not c['cached']
        row['models'].add(f'{c["provider"]}:{c["model"]}')
        for k in ('input', 'cacheWrite', 'cacheRead', 'output'):
            row[k] += c['tokens'][k]
        row['cost'] += c['costUsd'] or 0
        row['spent'] += 0 if c['cached'] else (c['costUsd'] or 0)
    return rows


def report(sid):
    calls = latest_run(sid)
    if not calls:
        print(f'no ledger for {sid} ({PROFILE})')
        return
    rows = summarize(calls)
    print(f'· model usage for {sid} ({PROFILE}), latest run')
    print(f'  {"stage":<9}{"calls":>6}{"input":>9}{"c.write":>9}{"c.read":>8}'
          f'{"output":>8}{"cost $":>9}{"spent now $":>13}  model')
    total = spent = count = 0
    for stage in STAGES:
        if stage not in rows:
            continue
        r = rows[stage]
        total += r['cost']
        spent += r['spent']
        count += r['calls']
        print(f'  {stage:<9}{r["calls"]:>6}{r["input"]:>9}{r["cacheWrite"]:>9}'
              f'{r["cacheRead"]:>8}{r["output"]:>8}{r["cost"]:>9.3f}{r["spent"]:>13.3f}'
              f'  {", ".join(sorted(r["models"]))}')
    print(f'  {"total":<9}{count:>6}{"":>42}{total:>9.3f}{spent:>13.3f}')


def all_cached(sid):
    folder = workspace(sid, 'llm')
    total, by_name = 0.0, {}
    for name in sorted(os.listdir(folder)):
        record = read_json(os.path.join(folder, name))
        kind = record['name'].rstrip('0123456789')
        by_name.setdefault(kind, [0, 0.0])
        by_name[kind][0] += 1
        by_name[kind][1] += record.get('costUsd') or 0
        total += record.get('costUsd') or 0
    print(f'· every cached response for {sid} (all pipeline versions)')
    for kind, (n, cost) in by_name.items():
        print(f'  {kind:<14}{n:>3} calls  ${cost:.3f}')
    print(f'  {"total":<14}{sum(n for n, _ in by_name.values()):>3} calls  ${total:.3f}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('sid')
    parser.add_argument('--all', action='store_true')
    args = parser.parse_args()
    report(args.sid)
    if args.all:
        all_cached(args.sid)
