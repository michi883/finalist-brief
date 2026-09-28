"""Runs every stage of automatic deep-review generation for one submission.

    python3 run.py <submission-id> [--profile <name>] [--no-publish] [--from <stage>]

Stages are separate modules and can be run on their own; each reads the
previous stage's output from .cache/<id>/. --profile picks a model routing
from routing.json (same as DEEP_REVIEW_PROFILE); --no-publish stops before
the app asset is touched, which is how an A/B variant is run; --from skips
earlier stages whose output already exists (e.g. `--from extract` reuses the
shared acquisition and repository facts). Wall time per stage is written to
runs/<profile>/timing.json.
"""

import argparse
import os
import time

parser = argparse.ArgumentParser()
parser.add_argument('sid')
parser.add_argument('--profile')
parser.add_argument('--no-publish', action='store_true')
parser.add_argument('--from', dest='start', default='acquire')
args = parser.parse_args()
if args.profile:
    # Before the stages import common, which reads it once.
    os.environ['DEEP_REVIEW_PROFILE'] = args.profile

import acquire  # noqa: E402
import costs  # noqa: E402
import extract  # noqa: E402
import generate  # noqa: E402
import ground  # noqa: E402
import publish  # noqa: E402
import repo_facts  # noqa: E402
from common import PROFILE, run_dir, write_json  # noqa: E402

if __name__ == '__main__':
    stages = [acquire, repo_facts, extract, generate, ground]
    if not args.no_publish:
        stages.append(publish)
    names = [s.__name__ for s in stages]
    stages = stages[names.index(args.start):]
    costs.start_run(args.sid)
    timing = {'profile': PROFILE, 'stages': {}}
    started = time.monotonic()
    for stage in stages:
        t = time.monotonic()
        stage.main(args.sid)
        timing['stages'][stage.__name__] = round(time.monotonic() - t, 1)
    timing['total'] = round(time.monotonic() - started, 1)
    write_json(os.path.join(run_dir(args.sid), 'timing.json'), timing)
    costs.report(args.sid)
    print(f'· {timing["total"]} s: ' + ', '.join(f'{k} {v} s' for k, v in timing['stages'].items()))
