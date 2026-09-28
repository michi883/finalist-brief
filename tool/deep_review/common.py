"""Shared paths and helpers for automatic deep-review generation.

The deep-review pipeline reuses the Serverpod pilot's acquisition caches
(Devpost pages, clones, deterministic signals) and adds its own per-submission
workspace under `.cache/<id>/`. Every model call is cached by a hash of its
full request, so re-running a stage is deterministic and free unless its
inputs or prompt change.
"""

import base64
import hashlib
import importlib.util
import json
import os
import subprocess
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(ROOT))
PILOT = os.path.join(REPO_ROOT, 'tool', 'serverpod_pilot')


def _pilot(module):
    spec = importlib.util.spec_from_file_location(
        f'pilot_{module}', os.path.join(PILOT, f'{module}.py'))
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


_common = _pilot('common')


def pilot_signals():
    """The pilot's deterministic analyzer, which imports its own `common`."""
    import sys
    saved = sys.modules.get('common')
    sys.modules['common'] = _common
    try:
        return _pilot('deterministic_signals')
    finally:
        if saved is None:
            sys.modules.pop('common', None)
        else:
            sys.modules['common'] = saved
DEADLINE = _common.DEADLINE
ensure_dir = _common.ensure_dir
read_json = _common.read_json
write_json = _common.write_json

CACHE = os.path.join(ROOT, '.cache')
FLUTTER = os.path.join(REPO_ROOT, 'finalist_brief_flutter')
ASSET = os.path.join(FLUTTER, 'assets', 'representations', 'serverpod.json')
TRIAGE_ASSET = os.path.join(FLUTTER, 'assets', 'triage', 'serverpod.json')
EVIDENCE_DIR = os.path.join(FLUTTER, 'assets', 'evidence', 'serverpod')

ROUTING = read_json(os.path.join(ROOT, 'routing.json'))
PROFILE = os.environ.get('DEEP_REVIEW_PROFILE') or ROUTING['default']
if PROFILE not in ROUTING['profiles']:
    raise SystemExit(f'Unknown DEEP_REVIEW_PROFILE {PROFILE}; see routing.json')
# Stage outputs that depend on a model live per profile; sources, repository
# facts and frames are deterministic and shared.
MODEL_STAGES = {'extract', 'draft', 'grounded', 'provenance', 'representation',
                'static', 'claims', 'dossier'}


def route(stage):
    """{provider, model} for a model stage: an env override, else the profile.

    Models are pinned by ID; an alias would change answers silently."""
    override = os.environ.get(f'DEEP_REVIEW_{stage.upper()}')
    if override:
        provider, _, model = override.partition(':')
        return {'provider': provider, 'model': model}
    return dict(ROUTING['profiles'][PROFILE][stage])


def routes():
    stages = [s for s in ('observe', 'generate', 'verify', 'investigate', 'investigate-deep')
              if s in ROUTING['profiles'][PROFILE] or os.environ.get(f'DEEP_REVIEW_{s.upper()}')]
    return {stage: f'{r["provider"]}:{r["model"]}' for stage in stages for r in [route(stage)]}


def workspace(sid, *parts):
    return os.path.join(ensure_dir(os.path.join(CACHE, sid)), *parts)


def run_dir(sid):
    return ensure_dir(workspace(sid, 'runs', PROFILE))


def stage_path(sid, name):
    if name in MODEL_STAGES:
        return os.path.join(run_dir(sid), f'{name}.json')
    return workspace(sid, f'{name}.json')


def load_stage(sid, name):
    path = stage_path(sid, name)
    if not os.path.exists(path):
        raise SystemExit(f'Missing {name}.json for {sid} ({PROFILE}); run the earlier stage.')
    return read_json(path)


def image_block(path):
    with open(path, 'rb') as f:
        data = base64.b64encode(f.read()).decode()
    return {
        'type': 'image',
        'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': data},
    }


def ask(sid, name, stage, system, content, schema):
    """One structured model call, routed by [stage] (see routing.json).

    [content] is a list of Messages API content blocks (text and images);
    each provider translates it. Responses are cached under `.cache/<id>/llm/`
    by a hash of the full request including the model, so re-running a stage
    is free unless its inputs, prompt or route change. Every call, cached or
    not, is appended to the run's `calls.jsonl` for cost accounting.
    DEEP_REVIEW_CACHE_ONLY=1 refuses any call that is not cached.
    """
    r = route(stage)
    request = {'model': r['model'], 'system': system, 'content': content,
               'schema': schema}
    if r['provider'] != 'claude-cli':
        # Claude CLI keys predate routing; keeping them unchanged keeps the
        # existing cache valid. Route options (thinking level, media
        # resolution) change the answer, so they are part of the key.
        request['provider'] = r['provider']
        request['options'] = {k: v for k, v in r.items() if k not in ('provider', 'model')}
    key = hashlib.sha256(
        json.dumps(request, sort_keys=True).encode()).hexdigest()[:16]
    cached = workspace(sid, 'llm', f'{name}-{key}.json')
    ensure_dir(os.path.dirname(cached))
    hit = os.path.exists(cached)
    if not hit:
        if os.environ.get('DEEP_REVIEW_CACHE_ONLY'):
            raise SystemExit(f'{name} ({key}) is not cached and DEEP_REVIEW_CACHE_ONLY is set')
        print(f'  · model call {name} → {r["provider"]}:{r["model"]} ({key})', flush=True)
        call = PROVIDERS[r['provider']]
        started = time.monotonic()
        output, usage, cost, attempts = call(r, system, content, schema)
        write_json(cached, {
            'provider': r['provider'],
            'model': r['model'],
            'options': request.get('options', {}),
            'name': name,
            'costUsd': cost,
            'usage': usage,
            'attempts': attempts,
            'seconds': round(time.monotonic() - started, 1),
            'output': output,
        })
    record = read_json(cached)
    log_call(sid, stage, name, key, record, hit)
    return record['output']


def log_call(sid, stage, name, key, record, cached):
    """Appends one call, cached or not, to the run's ledger."""
    with open(os.path.join(run_dir(sid), 'calls.jsonl'), 'a', encoding='utf-8') as f:
        f.write(json.dumps({
            'at': time.strftime('%Y-%m-%dT%H:%M:%S'), 'stage': stage, 'name': name,
            'key': key, 'provider': record.get('provider', 'claude-cli'),
            'model': record['model'], 'cached': cached,
            'costUsd': record.get('costUsd'), 'tokens': tokens(record),
            'attempts': record.get('attempts', 1), 'seconds': record.get('seconds'),
        }) + '\n')


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()[:16]


class SessionDiverged(Exception):
    """A recorded session cannot be continued: the next turn differs."""


class ClaudeSession:
    """A multi-turn structured conversation with Claude through one live CLI.

    The first turn carries the full context; later turns (repair requests)
    carry only what is new. Because the conversation grows by appending, the
    CLI's prompt cache serves the earlier turns on every later one, instead of
    each repair re-sending and re-paying for the whole context.

    The schema is the same on every turn: it is part of the cached prefix,
    so a different schema for repairs would invalidate the cache.

    Turns are recorded under `.cache/<id>/llm/<stage>-session-<key>.json`. A
    re-run replays recorded turns while its messages match. A live process
    cannot be resumed after a replayed turn, so a mismatch after the first
    turn raises SessionDiverged and the caller starts a fresh session.
    """

    def __init__(self, sid, stage, system, schema, first, fresh=False):
        self.sid, self.stage, self.system, self.schema = sid, stage, system, schema
        self.route = route(stage)
        self.key = digest({'model': self.route['model'], 'system': system,
                           'content': first, 'schema': schema, 'mode': 'multi-turn'})
        self.path = workspace(sid, 'llm', f'{stage}-session-{self.key}.json')
        ensure_dir(os.path.dirname(self.path))
        self.recorded = [] if fresh or not os.path.exists(self.path) else read_json(self.path)['turns']
        self.turns, self.process, self.spent = [], None, 0.0

    def ask(self, name, content):
        i, message = len(self.turns), digest(content)
        replay = (self.process is None and i < len(self.recorded)
                  and self.recorded[i]['message'] == message)
        if replay:
            turn = self.recorded[i]
        else:
            if self.process is None and i > 0:
                raise SessionDiverged(f'{self.stage} turn {i} differs from the recording')
            if os.environ.get('DEEP_REVIEW_CACHE_ONLY'):
                raise SystemExit(f'{name} ({self.key}#{i}) is not cached and DEEP_REVIEW_CACHE_ONLY is set')
            if self.process is None:
                self._start()
            print(f'  · session turn {i} {name} → claude-cli:{self.route["model"]} ({self.key})', flush=True)
            turn = self._turn(content)
            turn.update({'name': name, 'message': message})
        self.turns.append(turn)
        if not replay:
            write_json(self.path, {'model': self.route['model'], 'turns': self.turns})
        log_call(self.sid, self.stage, name, f'{self.key}#{i}',
                 {'provider': 'claude-cli', **turn}, replay)
        return turn['output']

    def _start(self):
        command = [
            'claude', '-p', '--model', self.route['model'],
            '--input-format', 'stream-json', '--output-format', 'stream-json',
            '--verbose', '--tools', '', '--system-prompt', self.system,
            '--strict-mcp-config', '--setting-sources', '',
            '--disable-slash-commands', '--no-chrome', '--no-session-persistence',
            '--json-schema', json.dumps(self.schema),
        ]
        self.process = subprocess.Popen(
            command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True,
            env={**os.environ, 'DISABLE_PROMPT_CACHING': '1'})

    def _turn(self, content):
        started = time.monotonic()
        message = {'type': 'user', 'message': {'role': 'user', 'content': content}}
        self.process.stdin.write(json.dumps(message) + '\n')
        self.process.stdin.flush()
        result, retries = None, 0
        for line in self.process.stdout:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get('type') == 'system' and 'retry' in str(event.get('subtype', '')):
                retries += 1
            if event.get('type') == 'result':
                result = event
                break
        if not result or result.get('is_error') or result.get('structured_output') is None:
            self.close()
            raise RuntimeError(f'claude-cli session failed: {str(result)[:800]}')
        # The CLI reports cost cumulatively for the session, usage per turn.
        cost = (result.get('total_cost_usd') or 0) - self.spent
        self.spent = result.get('total_cost_usd') or self.spent
        return {'model': self.route['model'], 'output': result['structured_output'],
                'usage': result.get('usage'), 'costUsd': cost, 'attempts': 1 + retries,
                'seconds': round(time.monotonic() - started, 1)}

    def close(self):
        if self.process is None:
            return
        try:
            self.process.stdin.close()
            self.process.wait(timeout=60)
        except (OSError, subprocess.TimeoutExpired):
            self.process.kill()
        self.process = None


def tokens(record):
    """Provider usage as {input, cacheWrite, cacheRead, output}."""
    u = record.get('usage') or {}
    if record.get('provider') == 'jev':
        return {'input': u.get('input_tokens', 0), 'cacheWrite': 0, 'cacheRead': 0,
                'output': u.get('output_tokens', 0)}
    if record.get('provider', 'claude-cli') == 'claude-cli':
        return {'input': u.get('input_tokens', 0),
                'cacheWrite': u.get('cache_creation_input_tokens', 0),
                'cacheRead': u.get('cache_read_input_tokens', 0),
                'output': u.get('output_tokens', 0)}
    cached = u.get('cachedContentTokenCount', 0)
    return {'input': u.get('promptTokenCount', 0) - cached, 'cacheWrite': 0,
            'cacheRead': cached,
            'output': u.get('candidatesTokenCount', 0) + u.get('thoughtsTokenCount', 0)}


def price(model, t):
    """USD at list price for normalized tokens; None if the model is unpriced."""
    p = ROUTING['prices'].get(model)
    if not p:
        return None
    return (t['input'] * p['input'] + t['cacheRead'] * p.get('cacheRead', p['input'])
            + t['cacheWrite'] * p.get('cacheWrite5m', p['input'])
            + t['output'] * p['output']) / 1e6


def _claude_cli(r, system, content, schema):
    """Claude Code CLI with no tools, settings or MCP servers and a replaced
    system prompt, so the model sees only what this pipeline gives it.

    Every call is a one-off prompt that is never read back from cache (the
    repair loop's prefix does not hit either), so the 1-hour cache write the
    CLI defaults to (2x input) is pure overhead. DISABLE_PROMPT_CACHING
    brings it down to a 5-minute write (1.25x). The CLI retries API errors
    itself; a failed call raises and a re-run resumes from the cache."""
    message = {'type': 'user', 'message': {'role': 'user', 'content': content}}
    command = [
        'claude', '-p', '--model', r['model'],
        '--input-format', 'stream-json', '--output-format', 'stream-json',
        '--verbose', '--tools', '', '--system-prompt', system,
        '--strict-mcp-config', '--setting-sources', '',
        '--disable-slash-commands', '--no-chrome', '--no-session-persistence',
        '--json-schema', json.dumps(schema),
    ]
    process = subprocess.run(
        command, input=json.dumps(message) + '\n', capture_output=True,
        text=True, timeout=1800,
        env={**os.environ, 'DISABLE_PROMPT_CACHING': '1'},
    )
    result, retries = None, 0
    for line in process.stdout.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get('type') == 'result':
            result = event
        elif event.get('type') == 'system' and 'retry' in str(event.get('subtype', '')):
            retries += 1
    if not result or result.get('is_error') or result.get('structured_output') is None:
        raise RuntimeError(
            f'claude-cli failed: {process.stderr[-800:]} {str(result)[:800]}')
    return (result['structured_output'], result.get('usage'),
            result.get('total_cost_usd'), 1 + retries)


GEMINI = 'https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent'
RETRYABLE = {429, 500, 502, 503, 504}


def _gemini(r, system, content, schema):
    """Gemini API over HTTP with JSON-schema constrained output.

    Transient errors (429, 5xx, timeouts) and an unparseable reply are
    retried with exponential backoff, at most 5 attempts. Repeated prefixes
    (the repair loop) are discounted by Gemini's implicit caching, which
    shows up as cachedContentTokenCount."""
    key = _common.load_env().get('GEMINI_API_KEY')
    if not key:
        raise SystemExit('GEMINI_API_KEY is missing from the root .env')
    parts = []
    for block in content:
        if block['type'] == 'text':
            parts.append({'text': block['text']})
        elif block['type'] == 'image':
            parts.append({'inlineData': {'mimeType': block['source']['media_type'],
                                         'data': block['source']['data']}})
    config = {'responseMimeType': 'application/json', 'responseJsonSchema': schema,
              'maxOutputTokens': 65536}
    if r.get('thinking'):
        config['thinkingConfig'] = {'thinkingLevel': r['thinking']}
    if r.get('mediaResolution'):
        config['mediaResolution'] = r['mediaResolution']
    body = json.dumps({
        'systemInstruction': {'parts': [{'text': system}]},
        'contents': [{'role': 'user', 'parts': parts}],
        'generationConfig': config,
    }).encode()
    usage = {}
    for attempt in range(1, 6):
        request = urllib.request.Request(
            GEMINI.format(r['model']), data=body, method='POST',
            headers={'x-goog-api-key': key, 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(request, timeout=900) as response:
                reply = json.loads(response.read())
        except urllib.error.HTTPError as error:
            if error.code in RETRYABLE and attempt < 5:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(f'gemini {error.code}: {error.read().decode()[:800]}')
        except (urllib.error.URLError, TimeoutError) as error:
            if attempt < 5:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(f'gemini unreachable: {error}')
        usage = reply.get('usageMetadata', {})
        candidate = (reply.get('candidates') or [{}])[0]
        if candidate.get('finishReason') != 'STOP':
            raise RuntimeError(f'gemini stopped: {candidate.get("finishReason")} '
                               f'{json.dumps(reply)[:800]}')
        text = ''.join(p.get('text', '') for p in candidate['content']['parts']
                       if not p.get('thought'))
        try:
            output = json.loads(text)
            break
        except json.JSONDecodeError:
            if attempt == 5:
                raise RuntimeError(f'gemini returned invalid JSON: {text[:800]}')
            time.sleep(2 ** attempt)
    record = {'provider': 'gemini', 'usage': usage}
    return output, usage, price(r['model'], tokens(record)), attempt


PROVIDERS = {'claude-cli': _claude_cli, 'gemini': _gemini}


def numbered(text, start=1):
    return '\n'.join(
        f'{i:4d}| {line}' for i, line in enumerate(text.splitlines(), start))
