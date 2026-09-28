"""Shared paths and helpers for the Serverpod triage pilot pipeline.

The pipeline is offline-first: every network result is cached under
`.cache/` (raw pages, clones) or written to `data/` (parsed signals), and the
Flutter app only reads the bundled asset that `build_dataset.py` produces.
"""

import html
import json
import os
import re
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(ROOT))
CACHE = os.path.join(ROOT, '.cache')
DATA = os.path.join(ROOT, 'data')
ASSET = os.path.join(
    REPO_ROOT, 'finalist_brief_flutter', 'assets', 'triage', 'serverpod.json'
)

GALLERY = 'https://serverpod.devpost.com/project-gallery'
# From https://serverpod.devpost.com/details/dates (CET = UTC+1).
SUBMISSIONS_OPEN = '2025-12-09T16:15:00Z'
DEADLINE = '2026-01-30T16:00:00Z'
SAMPLE_SIZE = 117
CHECKED = '2026-09-24'

USER_AGENT = (
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
)


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)
    return path


def fetch(url, cache_name=None, retries=2):
    """GETs [url] as text, caching the body under .cache/pages/."""
    if cache_name:
        cached = os.path.join(ensure_dir(os.path.join(CACHE, 'pages')), cache_name)
        if os.path.exists(cached):
            with open(cached, encoding='utf-8') as f:
                return f.read()
    request = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read().decode('utf-8', errors='replace')
            break
        except urllib.error.URLError:
            if attempt == retries:
                raise
            time.sleep(1 + attempt)
    if cache_name:
        with open(cached, 'w', encoding='utf-8') as f:
            f.write(body)
    time.sleep(0.4)  # Be gentle with Devpost.
    return body


def status_of(url, method='GET'):
    """HTTP status for [url]; 0 when the host cannot be reached."""
    request = urllib.request.Request(
        url, method=method, headers={'User-Agent': USER_AGENT}
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code
    except (urllib.error.URLError, TimeoutError, ConnectionError):
        return 0


def html_to_text(fragment):
    fragment = re.sub(r'<(script|style)\b.*?</\1>', '', fragment, flags=re.S)
    fragment = re.sub(r'<br\s*/?>', '\n', fragment)
    fragment = re.sub(r'</(p|li|h\d|div|pre|blockquote)>', '\n', fragment)
    fragment = re.sub(r'<li[^>]*>', '- ', fragment)
    text = html.unescape(re.sub(r'<[^>]+>', '', fragment))
    text = re.sub(r'[ \t ]+', ' ', text)
    return re.sub(r'\n\s*\n+', '\n\n', text).strip()


def read_json(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def write_json(path, value):
    ensure_dir(os.path.dirname(path))
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(value, f, indent=1, ensure_ascii=False)
        f.write('\n')


def load_env():
    env = {}
    path = os.path.join(REPO_ROOT, '.env')
    if os.path.exists(path):
        with open(path, encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env[key.strip()] = value.strip().strip('"').strip("'")
    return {**env, **os.environ}
