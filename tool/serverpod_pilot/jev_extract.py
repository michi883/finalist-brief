"""Step 3: narrow structured extraction from each writeup with Jev.

Jev (TypeSafe System One, https://docs.typesafe.ai) answers typed questions
(Choice, Noul) about a state; it does not generate text. Code splits each
Devpost writeup into numbered lines, Jev classifies them and answers a small
profile, and code does all counting and comparison afterwards.

Jev is never asked to rank, judge quality, or pick winners: every question
asks what the writeup *says*, not whether it is good.

Responses are cached in data/jev.json keyed by a hash of the request, so
rebuilding the dataset is deterministic and makes no calls unless the
writeup or the questions change. Requires TYPESAFE_API_KEY in the root .env.

Output: data/jev.json
"""

import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

from common import CACHE, DATA, load_env, read_json, write_json

MODEL = 'jev-1.13.0'  # Pinned: the alias would change answers silently.
ENDPOINT = 'https://api.typesafe.ai/v1/systemone'
LINES_PER_REQUEST = 90

def split_lines(writeup):
    """Numbered writeup lines with their section. Headings are kept as context."""
    lines, section = [], ''
    for block in writeup.split('\n'):
        block = block.strip()
        if not block:
            continue
        if block.startswith('## '):
            section = block[3:].strip()
            lines.append({'text': section, 'section': section, 'heading': True})
            continue
        # Long paragraphs are split into sentences so each claim is addressable.
        parts = re.split(r'(?<=[.!?])\s+(?=[A-Z“"(])', block) if len(block) > 240 else [block]
        for part in parts:
            if len(part.strip(' -*•')) > 2:
                lines.append({'text': part.strip(), 'section': section, 'heading': False})
    for i, line in enumerate(lines):
        line['id'] = f'L{i:03d}'
    return lines


def state_for(submission, lines):
    return {
        'title': submission['title'],
        'tagline': submission['tagline'],
        'built_with': submission['builtWith'],
        'writeup': '\n'.join(f"{l['id']}| {l['text']}" for l in lines),
    }


PROFILE = {
    'domain': {
        'type': 'choice',
        'instructions': 'Which area of everyday life does the project described in `writeup` mainly serve?',
        'criteria': {
            'productivity': 'Tasks, to-dos, schedules, reminders, habits or personal organization',
            'health': 'Health, medicine, skin care, fitness, elder care or wellbeing',
            'finance': 'Money, trading, crypto, budgets or payments',
            'learning': 'Education, courses, studying or careers',
            'knowledge': 'Knowledge management, documents, notes or an organization\'s memory',
            'community': 'Social networks, civic issues, groups, or messaging between people',
            'developer': 'Tools for software developers, or for building other apps or agents',
            'privacy': 'Privacy, encryption, or secure storage of personal data',
            'automation': 'Phone, device or home automation triggered by context',
            'other': 'None of the above',
        },
    },
    'butler_mode': {
        'type': 'choice',
        'instructions': 'According to `writeup`, how does the app mainly help its user?',
        'criteria': {
            'conversational': 'The user asks questions or gives instructions in a chat, and the app answers',
            'proactive': 'The app acts on its own: it monitors, triggers actions, schedules or notifies without being asked',
            'analysis': 'The user provides content such as photos, documents or data, and the app analyzes it',
            'organizer': 'The app stores, tracks and organizes the user\'s records or tasks',
            'platform': 'The app is a platform for creating or configuring other agents or apps',
        },
    },
    'ai_role': {
        'type': 'choice',
        'instructions': 'According to `writeup`, what role does an AI or machine-learning model play in the app?',
        'criteria': {
            'none': 'No AI or machine-learning model is mentioned',
            'supporting': 'An AI model powers one feature among several',
            'core': 'The app\'s main function depends on an AI model',
        },
    },
    'ai_provider': {
        'type': 'choice',
        'instructions': 'Which AI model provider does `writeup` or `built_with` name?',
        'criteria': {
            'gemini': 'Google Gemini',
            'openai': 'OpenAI or GPT models',
            'anthropic': 'Anthropic Claude',
            'on_device': 'A model that runs on the device, such as TensorFlow Lite, llama.cpp or ML Kit',
            'other': 'Another named provider',
            'unnamed': 'AI is mentioned but no provider is named',
            'none': 'No AI is mentioned',
        },
    },
    'serverpod_role': {
        'type': 'choice',
        'instructions': 'How does `writeup` describe what Serverpod does in the project?',
        'criteria': {
            'not_mentioned': 'Serverpod is not mentioned',
            'named_only': 'Serverpod is named as the backend, but no specific responsibility is described',
            'specific': 'The writeup describes specific things Serverpod does, such as endpoints, database models, authentication, streaming or scheduled jobs',
        },
    },
    'mentions_database': {
        'type': 'noul',
        'instructions': 'Does `writeup` say the backend stores data in a database, such as PostgreSQL?',
    },
    'mentions_realtime': {
        'type': 'noul',
        'instructions': 'Does `writeup` say the app receives real-time updates, streams, or uses websockets?',
    },
    'mentions_scheduling': {
        'type': 'noul',
        'instructions': 'Does `writeup` say the backend runs scheduled or background jobs, such as tasks or reminders that run at a set time?',
    },
    'mentions_auth': {
        'type': 'noul',
        'instructions': 'Does `writeup` say users sign in, log in, or are authenticated?',
    },
    'mentions_uploads': {
        'type': 'noul',
        'instructions': 'Does `writeup` say users upload files, photos or images to the backend?',
    },
    'mentions_cloud_deploy': {
        'type': 'noul',
        'instructions': 'Does `writeup` say the backend is deployed on Serverpod Cloud?',
    },
    'mentions_tests': {
        'type': 'noul',
        'instructions': 'Does `writeup` say the project has automated tests?',
    },
    'admits_unfinished': {
        'type': 'noul',
        'instructions': (
            'Does `writeup` say that a described feature is unfinished, mocked, '
            'simulated, uses dummy or sample data, or does not work yet? '
            'Plans listed under a future-work heading such as "What\'s next" do not count.'
        ),
    },
}


def unfinished_line_questions(lines):
    """One Choice per 250 lines; a Choice accepts at most 255 options."""
    content = [l['id'] for l in lines if not l['heading']]
    return {
        f'unfinished_line_{i // 250}': unfinished_line_question(content[i:i + 250])
        for i in range(0, len(content), 250)
    }


def unfinished_line_question(ids):
    criteria = {i: None for i in ids}
    criteria['none'] = 'No line says this'
    return {
        'type': 'choice',
        'instructions': (
            'Which line of `writeup` most directly says that a described feature '
            'is unfinished, mocked, simulated, uses dummy or sample data, or does '
            'not work yet? Plans under a future-work heading such as "What\'s next" do not count.'
        ),
        'criteria': criteria,
    }


LINE_KINDS = {
    'capability': 'Says what the app does or lets its users do',
    'implementation': 'Says how the app is built: technologies, architecture, models, APIs or code',
    'outcome': 'Reports a measured result, a metric, user adoption, or an achieved impact',
    'plan': 'Describes future or planned work that is not built yet',
    'context': 'Background, motivation, a problem statement, challenges faced, or lessons learned',
}


def line_question(line):
    return {
        'type': 'choice',
        'instructions': (
            f"What kind of statement is line {line['id']} of `writeup`? "
            f"It appears under the heading \"{line['section'] or 'none'}\"."
        ),
        'criteria': LINE_KINDS,
    }


def ask(api_key, state, questions, cache):
    body = {'model': MODEL, 'state': state, 'questions': questions}
    key = hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest()
    if key in cache:
        return cache[key]
    if not api_key:
        sys.exit('TYPESAFE_API_KEY is missing and the response is not cached.')
    request = urllib.request.Request(
        ENDPOINT, data=json.dumps(body).encode(), method='POST',
        headers={'Authorization': f'Bearer {api_key}', 'Content-Type': 'application/json'},
    )
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                result = json.loads(response.read())
            break
        except urllib.error.HTTPError as error:
            if error.code in (429, 529) and attempt < 4:
                time.sleep(2 ** attempt)
                continue
            raise SystemExit(f'Jev error {error.code}: {error.read().decode()[:500]}')
    cache[key] = {'model': result['model'], 'answers': result['answers'], 'usage': result['usage']}
    return cache[key]


def main():
    devpost = read_json(os.path.join(DATA, 'devpost.json'))
    cache_path = os.path.join(CACHE, 'jev_responses.json')
    cache = read_json(cache_path) if os.path.exists(cache_path) else {}
    api_key = load_env().get('TYPESAFE_API_KEY')
    results, tokens = {}, 0
    for submission in devpost['submissions']:
        lines = split_lines(submission['writeup'])
        state = state_for(submission, lines)
        profile = ask(api_key, state, {**PROFILE, **unfinished_line_questions(lines)}, cache)
        # Across chunks, the most probable non-"none" line wins; code decides.
        chunks = {k: v for k, v in profile['answers'].items() if k.startswith('unfinished_line_')}
        candidates = [(p, line) for a in chunks.values()
                      for line, p in a['probabilities'].items() if line != 'none']
        best_p, best_line = max(candidates) if candidates else (0, None)
        tokens += profile['usage']['input_tokens']
        content = [l for l in lines if not l['heading']]
        kinds = {}
        for start in range(0, len(content), LINES_PER_REQUEST):
            chunk = content[start:start + LINES_PER_REQUEST]
            answer = ask(api_key, state, {l['id']: line_question(l) for l in chunk}, cache)
            tokens += answer['usage']['input_tokens']
            kinds.update(answer['answers'])
        write_json(cache_path, cache)
        results[submission['id']] = {
            'model': profile['model'],
            'lines': [
                {**l, **({'kind': kinds[l['id']]['choice'],
                          'p': round(kinds[l['id']]['probabilities'][kinds[l['id']]['choice']], 3),
                          'confidence': round(kinds[l['id']]['confidence'], 3)}
                         if l['id'] in kinds else {})}
                for l in lines
            ],
            'profile': {
                name: ({'choice': a['choice'], 'confidence': round(a['confidence'], 3),
                        'probabilities': {k: round(v, 3) for k, v in a['probabilities'].items()
}}
                       if a['type'] == 'choice' else {'noul': round(a['noul'], 3)})
                for name, a in profile['answers'].items()
                if not name.startswith('unfinished_line_')
            },
            'unfinishedLine': {'line': best_line, 'p': round(best_p, 3)} if best_line else None,
        }
        print(f"· {submission['id']}: {len(lines)} lines")
    write_json(os.path.join(DATA, 'jev.json'), {
        'model': MODEL,
        'questions': {
            'profile': {k: v['instructions'] for k, v in PROFILE.items()},
            'lineKinds': LINE_KINDS,
        },
        'inputTokens': tokens,
        'submissions': results,
    })
    print(f'{tokens} input tokens')


if __name__ == '__main__':
    main()
