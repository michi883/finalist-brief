"""Step 4: merge Devpost, deterministic and Jev signals into app assets.

Writes two files so the table stays small as the field grows:

- assets/triage/serverpod.json: one compact row of signals per submission.
- assets/triage/serverpod_writeups.json: every numbered writeup line with
  its Jev classification, loaded only when a submission is opened.

Signals are kept in separate, labelled groups (`devpost`, `access`, `repo`,
`jev`). Lanes and open questions are *not* computed here: the app derives them
with named rules in lib/triage/, so every assignment is explainable in place.
"""

import os

from common import ASSET, CHECKED, DATA, DEADLINE, SUBMISSIONS_OPEN, read_json, write_json

CLAIM_KINDS = ('capability', 'implementation', 'outcome')
MAJOR_CLAIMS = 5


def major_claims(lines):
    """The most clearly stated capability and outcome lines, in writeup order."""
    candidates = [
        l for l in lines
        if not l['heading'] and l.get('kind') in ('capability', 'outcome')
        and l['p'] >= .6 and len(l['text'].split()) >= 6
    ]
    chosen = sorted(candidates, key=lambda l: (-l['p'], l['id']))[:MAJOR_CLAIMS]
    return [{'line': l['id'], 'text': l['text'].lstrip('-•* ').strip()}
            for l in sorted(chosen, key=lambda l: l['id'])]


def jev_row(entry):
    profile = entry['profile']
    lines = entry['lines']
    kinds = {k: 0 for k in ('capability', 'implementation', 'outcome', 'plan', 'context')}
    for l in lines:
        if not l['heading']:
            kinds[l['kind']] += 1
    choice = lambda name: {
        'value': profile[name]['choice'], 'confidence': profile[name]['confidence'],
    }
    unfinished = entry.get('unfinishedLine')
    unfinished_text = next((l['text'] for l in lines if unfinished and l['id'] == unfinished['line']), None)
    return {
        'model': entry['model'],
        'domain': choice('domain'),
        'butlerMode': choice('butler_mode'),
        'aiRole': choice('ai_role'),
        'aiProvider': choice('ai_provider'),
        'serverpodRole': choice('serverpod_role'),
        'mentions': {
            key: profile[f'mentions_{name}']['noul']
            for key, name in [
                ('database', 'database'), ('realtime', 'realtime'),
                ('scheduling', 'scheduling'), ('auth', 'auth'),
                ('uploads', 'uploads'), ('cloudDeploy', 'cloud_deploy'),
                ('tests', 'tests'),
            ]
        },
        'admitsUnfinished': profile['admits_unfinished']['noul'],
        'unfinishedLine': {**unfinished, 'text': unfinished_text} if unfinished else None,
        'lineKinds': kinds,
        'claims': sum(kinds[k] for k in CLAIM_KINDS),
        'majorClaims': major_claims(lines),
    }


def repo_row(repo):
    row = {'url': repo['url'], 'status': repo['status']}
    for key in ('snapshot', 'commits', 'serverpod', 'scaffold', 'footprint', 'tests', 'aiInCode', 'otherBackends'):
        if key in repo:
            row[key] = repo[key]
    if 'tests' in row:
        row['tests'] = {k: row['tests'][k] for k in ('files', 'cases', 'paths')}
    return row


def main():
    devpost = read_json(os.path.join(DATA, 'devpost.json'))
    deterministic = read_json(os.path.join(DATA, 'deterministic.json'))['submissions']
    jev = read_json(os.path.join(DATA, 'jev.json'))
    rows, writeups = [], {}
    for submission in devpost['submissions']:
        sid = submission['id']
        signals = deterministic[sid]
        rows.append({
            'id': sid,
            'title': submission['title'],
            'tagline': submission['tagline'],
            'team': submission['team'],
            'devpostUrl': submission['devpostUrl'],
            'builtWith': submission['builtWith'],
            'links': submission['links'],
            'access': {
                'repo': signals['repo']['status'],
                'demo': signals['demo'],
                'live': signals['live'],
                # Rows added after the first check carry their own date.
                **({'checked': signals['checked']} if 'checked' in signals else {}),
            },
            'repo': repo_row(signals['repo']) if signals['repo']['status'] == 'public' else None,
            'jev': jev_row(jev['submissions'][sid]),
        })
        writeups[sid] = [
            {k: l[k] for k in ('id', 'text', 'section', 'heading', 'kind', 'p', 'confidence') if k in l}
            for l in jev['submissions'][sid]['lines']
        ]
    rows.sort(key=lambda r: r['title'].lower())
    write_json(ASSET, {
        'version': 1,
        'hackathon': {
            'id': 'serverpod',
            'title': 'Build your Flutter Butler with Serverpod',
            'sponsorTech': 'Serverpod',
            'gallery': devpost['gallery'],
            'submissionsOpen': SUBMISSIONS_OPEN,
            'deadline': DEADLINE,
            'fieldSize': devpost['fieldSize'],
        },
        'pilot': {
            'sample': devpost['sample'],
            'checked': CHECKED,
            'pipeline': 'tool/serverpod_pilot',
        },
        'extraction': {
            'deterministic': (
                'Link status, git history and the repository tree at the last '
                'commit before the deadline, compared with the exact `serverpod '
                'create` template for the pinned Serverpod version.'
            ),
            'jev': {
                'model': jev['model'],
                'inputTokens': jev['inputTokens'],
                'scope': (
                    'Classifies what each writeup says. Never ranks, scores '
                    'quality or selects winners.'
                ),
                'questions': jev['questions']['profile'],
                'lineKinds': jev['questions']['lineKinds'],
            },
        },
        'submissions': rows,
    })
    write_json(ASSET.replace('serverpod.json', 'serverpod_writeups.json'), writeups)
    print(f'wrote {len(rows)} rows')


if __name__ == '__main__':
    main()
