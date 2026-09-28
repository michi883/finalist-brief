"""Stage 3: writeup and demo extraction.

Writeup: the numbered lines the pilot already gave Jev (same `L000` IDs the
triage drawer shows), with Jev's per-line kind (capability, implementation,
outcome, plan, context). Nothing is re-extracted.

Demo: a model looks at the frames only, never the writeup or narration, and
describes what is literally visible in each one. Keeping it blind to the
claims is the point: "Demonstrated" can later cite only what this pass saw.
The narration (captions) stays a separate source, because what the presenter
says is a description, not a demonstration.

Output: .cache/<id>/extract.json
"""

import os
import sys

from common import (
    PILOT, ask, image_block, load_stage, read_json, stage_path, write_json,
)

OBSERVER = """You are a careful visual observer. You will see frames from a \
software demo video, each labelled with its timestamp in seconds. For every \
frame, report only what is literally visible: which kind of screen it is, \
the app screen or state shown, and the exact on-screen text that matters. \
Do not guess what the software does behind the scenes, do not repeat \
marketing claims, and do not infer success from intent. If something is \
unreadable or ambiguous, say so. When a frame shows the same state as the \
previous one, say "unchanged" briefly."""

SCHEMA = {
    'type': 'object',
    'properties': {
        'frames': {
            'type': 'array',
            'items': {
                'type': 'object',
                'properties': {
                    't': {'type': 'integer'},
                    'kind': {'type': 'string', 'enum': [
                        'app', 'phone system ui', 'notification',
                        'slide or title', 'code or terminal', 'person',
                        'other']},
                    'shows': {'type': 'string', 'description':
                              'One literal sentence: what the frame shows.'},
                    'text': {'type': 'string', 'description':
                             'Key on-screen text, verbatim, separated by " · ".'},
                    'changed': {'type': 'boolean', 'description':
                                'False if the state equals the previous frame.'},
                },
                'required': ['t', 'kind', 'shows', 'text', 'changed'],
            },
        },
        'sequence': {'type': 'string', 'description':
                     'Two or three literal sentences on what the video shows '
                     'happening, in order, citing timestamps.'},
    },
    'required': ['frames', 'sequence'],
}


def writeup_lines(sid, sources):
    jev = read_json(os.path.join(PILOT, 'data', 'jev.json'))['submissions']
    lines = jev.get(sid, {}).get('lines')
    if not lines:
        return [{'id': f'L{i:03d}', 'text': t, 'section': '', 'heading': False,
                 'kind': None}
                for i, t in enumerate(l for l in sources['writeup'].splitlines()
                                      if l.strip())]
    return [{'id': l['id'], 'text': l['text'], 'section': l['section'],
             'heading': l['heading'], 'kind': l.get('kind')} for l in lines]


def observe(sid, demo):
    content = [{'type': 'text', 'text':
                f'{len(demo["frames"])} frames, one every {demo["step"]} s, '
                f'from a {demo["duration"]} s video.'}]
    for frame in demo['frames']:
        content.append({'type': 'text', 'text': f't = {frame["t"]} s'})
        content.append(image_block(frame['path']))
    result = ask(sid, 'demo-observe', 'observe', OBSERVER, content, SCHEMA)
    known = {f['t'] for f in demo['frames']}
    # Only observations for frames that exist survive.
    result['frames'] = [f for f in result['frames'] if f['t'] in known]
    return result


# What the generator is told when no frames exist, in words a review can repeat.
DEMO_ABSENT = {
    'notLinked': 'No demo video is linked.',
    'private': 'The linked demo video is private, so it could not be viewed.',
    'unavailable': 'The linked demo video is no longer available.',
    'downloadFailed': 'The demo video could not be downloaded.',
}


def main(sid):
    sources = load_stage(sid, 'sources')
    print(f'· extracting {sid}')
    demo = sources['demo']
    extract = {
        'writeup': writeup_lines(sid, sources),
        'narration': {'kind': demo.get('captionKind'),
                      'cues': demo.get('captions', [])},
        'demo': observe(sid, demo) if demo.get('status') == 'available'
        else {'frames': [], 'sequence': DEMO_ABSENT.get(
            demo.get('status'), f'Demo {demo.get("status")}.')},
    }
    write_json(stage_path(sid, 'extract'), extract)
    print(f'  {len(extract["writeup"])} writeup lines · '
          f'{len(extract["demo"]["frames"])} frames observed')
    print('  ' + extract['demo']['sequence'])


if __name__ == '__main__':
    main(sys.argv[1])
