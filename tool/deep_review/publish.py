"""Stage 6: rendering hand-off.

Writes the grounded review into the Serverpod representations asset in the
existing Finalist Brief format, copies the demo frames it cites into
assets/evidence/serverpod/, and records how the review was made in an
`origin` block so the app can say it was generated. Nothing is rewritten
here: every text field comes from the grounded draft unchanged.

Output: finalist_brief_flutter/assets/representations/serverpod.json,
        finalist_brief_flutter/assets/evidence/serverpod/<id>-<t>.jpg,
        .cache/<id>/representation.json (the entry on its own)
"""

import os
import shutil
import sys

from common import (
    ASSET, EVIDENCE_DIR, FLUTTER, load_stage, read_json, route, routes,
    stage_path, write_json,
)

DIMENSIONS = ('ideaDistinctiveness', 'integrationDepth', 'sponsorCentrality',
              'sponsorEvidence')


def clean_evidence(evidence):
    out = {'status': evidence['status'], 'note': evidence['note'],
           'refs': evidence['refs']}
    if evidence.get('frame'):
        out['frame'] = evidence['frame']
    return out


def graph(g):
    out = {'topology': g['topology'], 'description': g['description']}
    if g['topology'] == 'hub':
        out['focus'] = g['focus']
    out['nodes'] = []
    for n in g['nodes']:
        node = {'id': n['id'], 'label': n['label'], 'kind': n['kind']}
        if n.get('detail'):
            node['detail'] = n['detail']
        node['evidence'] = clean_evidence(n['evidence'])
        out['nodes'].append(node)
    out['edges'] = []
    for e in g['edges']:
        edge = {'from': e['from'], 'to': e['to']}
        if e.get('kind', 'flow') != 'flow':
            edge['kind'] = e['kind']
        if e.get('label'):
            edge['label'] = e['label']
        if e.get('evidence'):
            edge['evidence'] = clean_evidence(e['evidence'])
        out['edges'].append(edge)
    return out


def anchor(a):
    return ({'lens': a['lens'], 'edge': a['edge']} if a.get('edge')
            else {'lens': a['lens'], 'node': a['node']})


def main(sid):
    sources = load_stage(sid, 'sources')
    review = load_stage(sid, 'grounded')
    provenance = load_stage(sid, 'provenance')
    repo, demo = sources['repo'], sources['demo']
    entry = {
        'id': sid,
        'title': sources['title'],
        'creator': ', '.join(sources['team']),
        'summary': review['summary'],
        'origin': {
            'method': 'generated',
            'pipeline': 'tool/deep_review',
            'model': route('generate')['model'],
            'models': routes(),
            'handEdited': False,
            'verifierLowered': len(provenance['lowered']),
            'citationsDropped': len(provenance['dropped']),
        },
        'sources': {
            'writeup': {'kind': 'writeup', 'label': 'Devpost writeup',
                        'url': sources['devpostUrl']},
            **({'repo': {'kind': 'repo', 'label': 'GitHub repository',
                         'url': repo['url'], 'rev': repo['sha']}}
               if repo.get('status') == 'public' else {}),
            **({'video': {'kind': 'video', 'label': 'Demo video', 'url': demo['url']}}
               if demo.get('status') == 'available' else {}),
        },
        'competitionDimensions': {
            k: {'value': round(min(1, max(0, review['dimensions'][k]['value'])), 2),
                'note': review['dimensions'][k]['note']} for k in DIMENSIONS},
        'idea': graph(review['idea']),
        'integration': graph(review['integration']),
        'mapping': [{'label': m['label'], 'idea': m['idea'],
                     'integration': m['integration'],
                     'evidence': clean_evidence(m['evidence'])}
                    for m in review['mapping']],
        'questions': [{'id': q['id'], 'kind': q['kind'], 'question': q['question'],
                       'basis': q['basis'], 'anchors': [anchor(a) for a in q['anchors']],
                       'refs': q['refs']} for q in review['questions']],
    }

    # Frames: copy exactly the ones the review shows.
    frames = {f['t']: f['path'] for f in demo.get('frames', [])}
    os.makedirs(EVIDENCE_DIR, exist_ok=True)
    for old in os.listdir(EVIDENCE_DIR):
        if old.startswith(f'{sid}-'):
            os.remove(os.path.join(EVIDENCE_DIR, old))
    shown = [ev['frame'] for g in ('idea', 'integration')
             for part in ('nodes', 'edges') for x in entry[g][part]
             for ev in [x.get('evidence') or {}] if ev.get('frame')]
    shown += [m['evidence']['frame'] for m in entry['mapping'] if m['evidence'].get('frame')]
    for frame in shown:
        shutil.copy(frames[frame['t']], os.path.join(FLUTTER, frame['image']))

    write_json(stage_path(sid, 'representation'), entry)
    asset = read_json(ASSET)
    projects = [p for p in asset['projects'] if p['id'] != sid]
    asset['projects'] = projects + [entry]
    write_json(ASSET, asset)
    print(f'· published {sid}: {len(shown)} frames, '
          f'{len(entry["idea"]["nodes"])}+{len(entry["integration"]["nodes"])} nodes, '
          f'{len(entry["mapping"])} observations, {len(entry["questions"])} questions')


if __name__ == '__main__':
    main(sys.argv[1])
