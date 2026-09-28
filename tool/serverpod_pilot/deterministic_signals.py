"""Step 2: deterministic signals from links and repositories.

Everything here is computed by code from public artifacts: HTTP status of the
submitted links, git history, and the repository tree at the last commit
before the deadline. Nothing reads README length, prose quality, stars, forks
or popularity.

Scaffold delta compares each Serverpod package with the exact `serverpod
create` template for its pinned Serverpod version (downloaded from pub.dev):
generated code and platform runners are excluded, untouched template files
contribute nothing, and edited template files contribute only added lines.

Output: data/deterministic.json
"""

import collections
import datetime
import difflib
import io
import os
import posixpath
import re
import subprocess
import sys
import tarfile
import urllib.request

from common import (
    CACHE, DATA, DEADLINE, SUBMISSIONS_OPEN, USER_AGENT, ensure_dir, read_json,
    status_of, write_json,
)

CODE_EXTENSIONS = {
    '.dart': 'Dart', '.py': 'Python', '.js': 'JavaScript', '.ts': 'TypeScript',
    '.tsx': 'TypeScript', '.jsx': 'JavaScript', '.kt': 'Kotlin',
    '.swift': 'Swift', '.java': 'Java', '.go': 'Go', '.rs': 'Rust',
    '.sql': 'SQL',
}
SKIP_DIRS = {
    '.git', '.dart_tool', 'build', 'node_modules', '.idea', '.vscode', 'Pods',
    '.gradle', '.symlinks', 'ephemeral', '.fvm', 'venv', '.venv',
    '__pycache__', 'dist', '.serverpod', '.plugin_symlinks',
}
PLATFORM_DIRS = {'android', 'ios', 'macos', 'linux', 'windows', 'web'}
# Runner files `flutter create` writes into platform folders.
PLATFORM_DEFAULTS = {
    'MainActivity.kt', 'MainActivity.java', 'AppDelegate.swift',
    'SceneDelegate.swift', 'MainFlutterWindow.swift', 'RunnerTests.swift',
    'GeneratedPluginRegistrant.java', 'GeneratedPluginRegistrant.swift',
    'GeneratedPluginRegistrant.m', 'GeneratedPluginRegistrant.h',
}
GENERATED = [
    re.compile(p) for p in [
        r'(^|/)lib/src/generated/', r'(^|/)lib/src/protocol/.*\.dart$',
        r'\.g\.dart$', r'\.freezed\.dart$', r'\.gr\.dart$', r'\.mocks\.dart$',
        r'generated_plugin_registrant', r'(^|/)firebase_options\.dart$',
        r'(^|/)serverpod_test_tools\.dart$', r'(^|/)migrations/',
        r'(^|/)l10n/generated/', r'\.pb(json|enum|server)?\.dart$',
    ]
]
TEMPLATE_ENDPOINTS = {'GreetingEndpoint', 'EmailIdpEndpoint', 'JwtRefreshEndpoint'}

AI_SIGNATURES = {
    'Gemini': [r'google_generative_ai', r'firebase_ai', r'firebase_vertexai',
               r'generativelanguage\.googleapis\.com', r'\bgemini-\d'],
    'OpenAI': [r'dart_openai', r'openai_dart', r'api\.openai\.com'],
    'Anthropic': [r'anthropic_sdk_dart', r'api\.anthropic\.com'],
    'On-device model': [r'\bfllama\b', r'tflite_flutter', r'\.tflite\b',
                        r'google_mlkit_', r'llama_cpp', r'\.gguf\b'],
    'Other hosted AI': [r'api\.groq\.com', r'aimlapi\.com', r'openrouter\.ai', r'pollinations\.ai',
                        r'api\.mistral\.ai', r'huggingface\.co'],
}
OTHER_BACKENDS = {
    'Firebase': r'^\s+(firebase_core|cloud_firestore|firebase_auth|firebase_database):',
    'Supabase': r'^\s+supabase(_flutter)?:',
    'Appwrite': r'^\s+appwrite:',
}


def git(repo, *args):
    return subprocess.run(
        ['git', '-C', repo, *args], capture_output=True, text=True, check=True,
    ).stdout.strip()


# ---------------------------------------------------------------- access

def youtube_status(embed):
    video = embed.rsplit('/', 1)[1]
    code = status_of(
        'https://www.youtube.com/oembed?format=json&url='
        f'https://www.youtube.com/watch?v={video}'
    )
    return code, f'https://www.youtube.com/watch?v={video}'


def vimeo_status(embed):
    video = embed.rsplit('/', 1)[1]
    code = status_of(f'https://vimeo.com/api/oembed.json?url=https://vimeo.com/{video}')
    return code, f'https://vimeo.com/{video}'


def demo_access(links):
    video = links.get('video')
    if not video:
        return {'status': 'notLinked'}
    code, url = youtube_status(video) if 'youtube' in video else vimeo_status(video)
    # oEmbed answers 200 for public and unlisted videos and 401 when only
    # embedding is disabled; 403 is a private video and 404 a removed one.
    status = {200: 'available', 401: 'available', 403: 'private'}.get(code, 'unavailable')
    return {'status': status, 'url': url, 'http': code}


def live_access(links):
    results = []
    for url in links.get('live', []):
        code = status_of(url)
        results.append({
            'url': url, 'http': code,
            'status': 'reachable' if 200 <= code < 400 else 'unreachable',
        })
    return results


def repo_access(url):
    if not url:
        return 'notLinked'
    probe = subprocess.run(
        ['git', 'ls-remote', '--heads', url + '.git'], capture_output=True,
        text=True, env={**os.environ, 'GIT_TERMINAL_PROMPT': '0'},
    )
    return 'public' if probe.returncode == 0 else 'notFound'


def clone(submission_id, url):
    path = os.path.join(ensure_dir(os.path.join(CACHE, 'repos')), submission_id)
    if not os.path.exists(path):
        subprocess.run(
            ['git', 'clone', '-q', '--filter=blob:none', url, path], check=True,
            env={**os.environ, 'GIT_TERMINAL_PROMPT': '0'},
        )
    return path


# ---------------------------------------------------------------- history

def commit_timing(repo):
    lines = git(repo, 'log', '--all', '--format=%H %cI %aI').splitlines()
    commits = []
    for line in lines:
        sha, committed, authored = line.split(' ')
        commits.append((sha, committed, authored))
    from datetime import datetime, timezone

    def utc(value):
        return datetime.fromisoformat(value).astimezone(timezone.utc)

    open_, deadline = utc(SUBMISSIONS_OPEN), utc(DEADLINE)
    authored = sorted(utc(a) for _, _, a in commits)
    before = [t for t in authored if t < open_]
    window = [t for t in authored if open_ <= t <= deadline]
    after = [t for t in authored if t > deadline]
    iso = lambda t: t.strftime('%Y-%m-%dT%H:%M:%SZ')
    return {
        'total': len(commits),
        'beforeOpen': len(before),
        'inWindow': len(window),
        'afterDeadline': len(after),
        'first': iso(authored[0]) if authored else None,
        'last': iso(authored[-1]) if authored else None,
        'activeDays': len({t.date() for t in window}),
        'windowSpanMinutes': round((window[-1] - window[0]).total_seconds() / 60)
        if len(window) > 1 else 0,
    }


def deadline_snapshot(repo):
    """Checks out the last commit on the default branch before the deadline."""
    head = git(repo, 'rev-parse', 'origin/HEAD')
    sha = git(repo, 'rev-list', '-1', f'--before={DEADLINE}', head)
    if not sha:
        return None
    git(repo, '-c', 'advice.detachedHead=false', 'checkout', '-q', sha)
    return {
        'sha': sha[:12],
        'date': git(repo, 'show', '-s', '--format=%cI', sha),
        'isHead': sha == head,
    }


# ---------------------------------------------------------------- files

def walk(root):
    for base, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for name in sorted(files):
            full = os.path.join(base, name)
            yield os.path.relpath(full, root), full


def read(path):
    try:
        with open(path, encoding='utf-8') as f:
            return f.read()
    except (UnicodeDecodeError, OSError):
        return None


def nonblank(text):
    return [l for l in text.splitlines() if l.strip()]


def is_generated(rel):
    return any(p.search(rel) for p in GENERATED)


def looks_minified(text):
    lines = text.splitlines() or ['']
    return max(len(l) for l in lines) > 1000 or sum(map(len, lines)) / len(lines) > 200


def pubspec(path):
    text = read(path) or ''
    name = re.search(r'^name:\s*([\w_]+)', text, re.M)
    deps = dict(re.findall(r'^  ([\w_]+):\s*([^\n#]*)', text, re.M))
    return {'name': name[1] if name else '', 'deps': deps, 'text': text}


def packages(root):
    """Serverpod server, client and Flutter packages in the tree."""
    found = {'server': [], 'client': [], 'flutter': []}
    for rel, full in walk(root):
        if os.path.basename(rel) != 'pubspec.yaml':
            continue
        spec = pubspec(full)
        directory = os.path.dirname(rel)
        if 'serverpod' in spec['deps']:
            found['server'].append((directory, spec))
        elif re.search(r'^\s+flutter:\s*\n\s+sdk:\s*flutter', spec['text'], re.M):
            found['flutter'].append((directory, spec))
        elif 'serverpod_client' in spec['deps']:
            found['client'].append((directory, spec))
    return found


# ---------------------------------------------------------------- app calls

DART_IMPORT = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.M)


def _package_dir(directory):
    return '' if os.path.normpath(directory or '.') == '.' else os.path.normpath(directory)


def runnable_dart(root, directories):
    """Dart files under the given packages' lib/ that the app can run: those
    reachable over import/export/part edges from any package's
    lib/main*.dart, following `package:` imports into the other local
    packages. None when no package has a main entry point (then nothing is
    excluded)."""
    local, files, prefixes = {}, set(), []
    for directory in directories:
        directory = _package_dir(directory)
        prefix = f'{directory}/lib/' if directory else 'lib/'
        prefixes.append(prefix)
        name = pubspec(os.path.join(root, directory, 'pubspec.yaml'))['name']
        if name:
            local[name] = prefix
        files |= {prefix + rel for rel, _ in walk(os.path.join(root, directory, 'lib'))
                  if rel.endswith('.dart')}
    todo = [at for at in files if re.search(r'(^|/)lib/main\w*\.dart$', at)]
    if not todo:
        return None
    seen = set(todo)
    while todo:
        at = todo.pop()
        for target in DART_IMPORT.findall(read(os.path.join(root, at)) or ''):
            if target.startswith('package:'):
                name, _, rest = target[len('package:'):].partition('/')
                if name not in local:
                    continue
                rel = local[name] + rest
            elif ':' in target:
                continue
            else:
                # Dart reads files under lib/ as package: URIs, so a relative
                # import cannot climb out of lib/: `..` stops at its root
                # (`lib/screens` + `../../widgets/x.dart` is lib/widgets/x.dart).
                root_prefix = max((p for p in prefixes if at.startswith(p)), key=len)
                inside = posixpath.normpath(posixpath.join(
                    posixpath.dirname(at[len(root_prefix):]) or '.', target))
                while inside.startswith('../'):
                    inside = inside[3:]
                rel = root_prefix + inside
            if rel in files and rel not in seen:
                seen.add(rel)
                todo.append(rel)
    return seen


def reachable_dart(root, directory):
    """runnable_dart for a single package."""
    return runnable_dart(root, [directory])


# A function or method declaration: `static Future<X> name(`, `void name(`.
LIB_FUNCTION = re.compile(
    r'^\s*(?:(?:static|async|external|override|@\w+)\s+)*(?:[\w<>?,\[\] ]+?\s+)(?P<name>[A-Za-z_]\w*)\s*\([^;{]*\)\s*(?:async\s*)?(?:\{|=>)',
    re.M)


def endpoint_calls(root, flutter_dirs, methods):
    """Calls from the Flutter app into this server's own endpoints.

    methods: {client accessor: set of endpoint method names}; an accessor is
    the endpoint class name in lower camel case without "Endpoint". Returns
    [(accessor, method, path, line)] for calls in app files that can run.

    Recognised:
    - `….summary.listSummaries(`, with any whitespace or line breaks between
      the parts (the client's endpoint accessed directly);
    - calls on an endpoint held elsewhere: a variable or provider typed as
      the generated client class (`Provider<EndpointSummary>`,
      `EndpointSummary summary`), assigned from the client
      (`final s = client.summary;`), or read from such a holder
      (`ref.read(summaryProvider)`), called as `holder.method(` or
      `ref.read(holder).method(`. A holder call counts only for a method of
      that endpoint, so a same-named method on another class does not."""
    if not methods:
        return []
    classes = {'Endpoint' + a[0].upper() + a[1:]: a for a in methods}
    direct = re.compile(r'\.\s*(' + '|'.join(sorted(methods)) + r')\s*\.\s*(\w+)\s*\(')
    typed = re.compile(r'\b(\w+)\s*=\s*\w*Provider\w*(?:\.\w+)*\s*<\s*(' + '|'.join(classes)
                       + r')\s*>|\b(' + '|'.join(classes) + r')\??\s+(\w+)\s*[;=,)]')
    assigned = re.compile(r'\b(\w+)\s*=\s*([^;]*?)\.\s*(' + '|'.join(sorted(methods))
                          + r')\b(?!\s*\.\s*\w+\s*\()(?!\s*\()')
    files = {}
    runnable = runnable_dart(root, flutter_dirs)
    dirs = [_package_dir(d) for d in flutter_dirs]
    # Library packages (no lib/main*.dart of their own), such as a wrapper
    # around the client: their code runs only when the app calls into it.
    libraries = {d for d in dirs if not any(
        re.fullmatch(r'main\w*\.dart', f) for f in os.listdir(os.path.join(root, d, 'lib')))
        } if all(os.path.isdir(os.path.join(root, d, 'lib')) for d in dirs) else set()
    for directory in dirs:
        base = os.path.join(root, directory)
        for rel, full in walk(base):
            at = f'{directory}/{rel}' if directory else rel
            # A nested package is its own package, walked on its own if it is
            # a Flutter package, and never app code otherwise.
            parts = rel.split('/')
            if any(os.path.exists(os.path.join(base, *parts[:i], 'pubspec.yaml'))
                   for i in range(1, len(parts))):
                continue
            if not rel.endswith('.dart') or is_generated(rel):
                continue
            if runnable is not None and rel.startswith('lib/') and at not in runnable:
                continue
            files[at] = (directory, read(full) or '')

    holders, ambiguous = {}, set()

    def hold(name, accessor):
        if holders.get(name, accessor) != accessor:
            ambiguous.add(name)
        holders[name] = accessor

    for _, text in files.values():
        for m in typed.finditer(text):
            if m[1]:
                hold(m[1], classes[m[2]])
            else:
                hold(m[4], classes[m[3]])
        for m in assigned.finditer(text):
            if re.search(r'client', m[2], re.I):
                hold(m[1], m[3])
    # A holder read into a variable (`final endpoint = ref.read(goalProvider);`)
    # is local: teams reuse one name such as `endpoint` for different
    # endpoints in different functions and files. Each call resolves to the
    # nearest earlier binding of that name in the same file, never to a
    # binding elsewhere.
    names = [n for n in holders if n not in ambiguous]
    local = {}
    if names:
        derived = re.compile(r'\b(\w+)\s*=\s*(?:await\s+)?ref\s*\.\s*(?:read|watch)\s*\(\s*(\w+)\s*\)\s*;')
        for at, (_, text) in files.items():
            bindings = []
            for m in derived.finditer(text):
                source = m[2]
                earlier = [a for i, n, a in bindings if n == source]
                accessor = earlier[-1] if earlier else (
                    holders[source] if source in names else None)
                if accessor:
                    bindings.append((m.start(), m[1], accessor))
            local[at] = bindings
    bound = {n for b in local.values() for _, n, _ in b}
    callable_names = sorted(set(names) | bound)
    via = re.compile(r'(?:ref\s*\.\s*(?:read|watch)\s*\(\s*(' + '|'.join(map(re.escape, names))
                     + r')\s*\)|\b(' + '|'.join(map(re.escape, callable_names))
                     + r'))\s*\.\s*(\w+)\s*\(') if callable_names else None

    def resolve(at, name, index):
        earlier = [a for i, n, a in local.get(at, []) if n == name and i < index]
        if earlier:
            return earlier[-1]
        return holders[name] if name in names else None

    def line(text, index):
        return text.count('\n', 0, index) + 1

    app_code = {at: text for at, (d, text) in files.items() if d not in libraries}

    def used(at, text, index):
        """A call in a library package counts only if the function around it
        is called from app code that can run."""
        if files[at][0] not in libraries:
            return True
        fn = None
        for m in LIB_FUNCTION.finditer(text[:index]):
            fn = m['name']
        if fn is None:
            return True
        pattern = re.compile(rf'\b{re.escape(fn)}\s*\(')
        return any(pattern.search(t) for other, t in app_code.items() if other != at)

    calls = []
    for at, (_, text) in files.items():
        for m in direct.finditer(text):
            if used(at, text, m.start()):
                calls.append((m[1], m[2], at, line(text, m.start())))
        if via:
            for m in via.finditer(text):
                accessor = holders[m[1]] if m[1] else resolve(at, m[2], m.start())
                if accessor and m[3] in methods[accessor] and used(at, text, m.start()):
                    calls.append((accessor, m[3], at, line(text, m.start())))
    return calls


# ---------------------------------------------------------------- template

TEMPLATE_VERSIONS = ['1.2.7', '3.0.0', '3.1.1', '3.2.0', '3.2.1', '3.2.2', '3.2.3']


def template_version(constraint):
    match = re.search(r'(\d+)\.(\d+)\.(\d+)', constraint or '')
    if not match:
        return TEMPLATE_VERSIONS[-1]
    wanted = tuple(map(int, match.groups()))
    candidates = [v for v in TEMPLATE_VERSIONS
                  if tuple(map(int, v.split('.')))[:1] == wanted[:1]]
    exact = [v for v in candidates if tuple(map(int, v.split('.'))) == wanted]
    if exact:
        return exact[0]
    lower = [v for v in candidates if tuple(map(int, v.split('.'))) <= wanted]
    return (lower or candidates or TEMPLATE_VERSIONS[-1:])[-1]


def template_files(version):
    """Maps 'projectname_server/…' paths to their template text (mini and full)."""
    directory = os.path.join(CACHE, 'templates', version)
    if not os.path.exists(directory):
        url = f'https://pub.dev/api/archives/serverpod_templates-{version}.tar.gz'
        request = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
        with urllib.request.urlopen(request, timeout=60) as response:
            data = response.read()
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            archive.extractall(ensure_dir(directory), filter='data')
    variants = collections.defaultdict(list)
    for rel, full in walk(directory):
        top, _, rest = rel.partition('/')
        kind = top.removesuffix('_upgrade')
        if kind not in ('projectname_server', 'projectname_client', 'projectname_flutter'):
            continue
        rest = re.sub(r'(^|/)gitignore$', r'\1.gitignore', rest)
        text = read(full)
        if text is not None:
            variants[f'{kind}/{rest}'].append(text)
    return variants


def added_lines(text, baselines, name):
    """Non-blank lines in [text] beyond the closest template variant."""
    best = None
    for base in baselines:
        base = base.replace('projectname', name)
        diff = difflib.ndiff(nonblank(base), nonblank(text))
        added = sum(1 for d in diff if d.startswith('+ '))
        best = added if best is None else min(best, added)
    return best


# ---------------------------------------------------------------- analysis

def footprint(server_dirs, flutter_dirs, root):
    models = tables = enums = 0
    endpoints, methods, streams = set(), 0, 0
    method_names = {}
    db_calls = 0
    features = collections.Counter()
    for directory in server_dirs:
        base = os.path.join(root, directory)
        for rel, full in walk(base):
            if is_generated(rel):
                continue
            text = read(full) or ''
            # Serverpod reads .spy, .spy.yaml and .spy.yml model files.
            is_model = re.search(r'\.spy(\.(ya?ml|json))?$', rel) or (
                re.search(r'lib/src/(models|protocol)/.*\.ya?ml$', rel))
            if is_model and 'greeting.spy.yaml' not in rel:
                models += len(re.findall(r'^(class|exception):', text, re.M))
                enums += len(re.findall(r'^enum:', text, re.M))
                tables += len(re.findall(r'^table:', text, re.M))
            if not rel.endswith('.dart'):
                continue
            custom = [c for c in re.findall(r'class\s+(\w+)\s+extends\s+Endpoint\b', text)
                      if c not in TEMPLATE_ENDPOINTS]
            if custom:
                endpoints.update(custom)
                named = re.findall(r'\b(?:Future|Stream)<[^\n(]*>\s+(\w+)\(\s*Session\b', text)
                for c in custom:
                    method_names.setdefault(c, set()).update(named)
                methods += len(named)
                streams += len(re.findall(r'\bStream<[^\n(]*>\s+\w+\(\s*Session\b', text))
            db_calls += len(re.findall(
                r'\.db\.(find\w*|insert\w*|update\w*|delete\w*|count|transaction)\b'
                r'|session\.db\.|\bunsafe(Query|Execute)\b', text))
            if re.search(r'extends\s+FutureCall\b|futureCall(WithDelay|AtTime)|registerFutureCall|\.futureCalls\b', text):
                features['futureCalls'] += 1
            if re.search(r'streamOpened|handleStreamMessage|sendStreamMessage|session\.messages', text):
                features['streams'] += 1
            if re.search(r'session\.caches', text):
                features['caching'] += 1
            if re.search(r'createDirectFileUploadDescription|verifyDirectFileUpload|storage\.(store|retrieve)File', text):
                features['fileUploads'] += 1
            if re.search(r'requireLogin\s*=>\s*true|session\.authenticated|\.authUserId\b|getAuthenticatedUserId', text):
                features['authInCustomCode'] += 1
            for route in re.findall(r'class\s+(\w+)\s+extends\s+(?:Widget)?Route\b', text):
                if route not in ('RootRoute', 'AppConfigRoute'):
                    features['webRoutes'] += 1
        migrations = os.path.join(base, 'migrations')
        if os.path.isdir(migrations):
            features['migrations'] += sum(
                1 for d in os.listdir(migrations)
                if os.path.exists(os.path.join(migrations, d, 'migration.sql')))
        features['generatedProtocol'] += int(os.path.exists(
            os.path.join(base, 'lib', 'src', 'generated', 'protocol.dart')))

    # Client accessors are the endpoint class names in lower camel case,
    # so calls are matched against this server's own endpoints only.
    accessors = {e[0].lower() + e[1:].removesuffix('Endpoint'): method_names.get(e, set())
                 for e in endpoints}
    calls = {f'{a}.{m}' for a, m, _, _ in endpoint_calls(root, flutter_dirs, accessors)}
    streams = streams + (1 if features['streams'] and not streams else 0)
    return {
        'models': models,
        'tables': tables,
        'enums': enums,
        'endpoints': sorted(endpoints),
        'endpointMethods': methods,
        'streamMethods': streams,
        'dbCallSites': db_calls,
        'futureCalls': features['futureCalls'] > 0,
        'caching': features['caching'] > 0,
        'fileUploads': features['fileUploads'] > 0,
        'authInCustomCode': features['authInCustomCode'] > 0,
        'webRoutes': features['webRoutes'],
        'migrations': features['migrations'],
        'generatedProtocol': features['generatedProtocol'] > 0,
        'appCalls': sorted(calls),
    }


def analyze_tree(root):
    found = packages(root)
    if not found['server']:
        return {'serverpod': None}
    server_dir, server_spec = found['server'][0]
    constraint = server_spec['deps'].get('serverpod', '').strip()
    project = server_spec['name'].removesuffix('_server') or 'project'
    version = template_version(constraint)
    templates = template_files(version)
    kinds = {}
    for kind in ('server', 'client', 'flutter'):
        for directory, spec in found[kind]:
            kinds[directory] = (kind, spec['name'])

    authored = collections.Counter()
    by_area = collections.Counter()
    modified = 0
    untouched = []
    tests = {'files': 0, 'cases': 0, 'paths': []}
    for rel, full in walk(root):
        ext = os.path.splitext(rel)[1]
        parts = rel.split('/')
        owner = max((d for d in kinds if d == '' or rel.startswith(d + '/')),
                    key=len, default=None)
        inner = rel[len(owner) + 1:] if owner else rel
        if is_generated(inner if owner is not None else rel):
            continue
        kind = kinds[owner][0] if owner is not None else None
        in_platform = kind == 'flutter' and inner.split('/')[0] in PLATFORM_DIRS
        if in_platform and (ext not in ('.kt', '.java', '.swift') or parts[-1] in PLATFORM_DEFAULTS):
            continue
        text = read(full)
        if text is None:
            continue
        template_key = f'projectname_{kind}/{inner}' if kind else None
        if template_key in templates:
            if ext not in CODE_EXTENSIONS:
                continue
            added = added_lines(text, templates[template_key], project)
            if added == 0:
                untouched.append(f'{owner}/{inner}' if owner else inner)
            modified += added
            by_area[kind] += added
            authored[CODE_EXTENSIONS[ext]] += added
            continue
        # A test is a Dart file under test/ or integration_test/ that imports a
        # test framework, or a pytest-style Python file.
        is_test = (
            bool(re.search(r'(^|/)(test|integration_test)/.*\.dart$', rel))
            and not rel.endswith('flutter_test_config.dart')
            and bool(re.search(r"package:(test|flutter_test|serverpod_test|integration_test)/", text))
        ) or bool(re.search(r'(^|/)test_\w+\.py$|_test\.py$', rel) and 'def test_' in text)
        cases = len(re.findall(r'\b(test\w*|withServerpod)\(|^\s*def test_', text, re.M)) if is_test else 0
        if cases:
            tests['files'] += 1
            tests['cases'] += cases
            tests['paths'].append(rel)
        if ext not in CODE_EXTENSIONS or looks_minified(text):
            continue
        lines = len(nonblank(text))
        authored[CODE_EXTENSIONS[ext]] += lines
        by_area[kind or 'other'] += lines

    flutter_dirs = [d for d, (k, _) in kinds.items() if k == 'flutter']
    all_specs = '\n'.join(s['text'] for k in found.values() for _, s in k)
    code_blob = []
    for rel, full in walk(root):
        if os.path.splitext(rel)[1] in CODE_EXTENSIONS and not is_generated(rel):
            code_blob.append(read(full) or '')
    code_blob = '\n'.join(code_blob) + '\n' + all_specs
    return {
        'serverpod': {
            'constraint': constraint,
            'major': int(re.search(r'\d+', constraint)[0]) if re.search(r'\d+', constraint) else None,
            'server': server_dir or '.',
            'client': [d or '.' for d, _ in found['client']],
            'flutter': [d or '.' for d in flutter_dirs],
            'serverpodDeps': sorted(
                {n for k in found.values() for _, s in k for n in s['deps'] if n.startswith('serverpod')}),
        },
        'scaffold': {
            'templateVersion': version,
            'authoredLines': sum(authored.values()) - modified,
            'editedTemplateLines': modified,
            'delta': sum(authored.values()),
            'byArea': dict(by_area),
            'byLanguage': dict(authored.most_common()),
            'untouchedTemplateFiles': untouched,
        },
        'footprint': footprint([server_dir], flutter_dirs, root),
        'tests': tests,
        'aiInCode': sorted(
            name for name, patterns in AI_SIGNATURES.items()
            if any(re.search(p, code_blob) for p in patterns)),
        'otherBackends': sorted(
            name for name, pattern in OTHER_BACKENDS.items()
            if re.search(pattern, all_specs, re.M)),
    }


def unresolvable(serverpod_deps):
    """Serverpod-namespaced dependencies that do not exist on pub.dev."""
    missing = []
    for name in serverpod_deps:
        if status_of(f'https://pub.dev/api/packages/{name}') == 404:
            missing.append(name)
    return missing


REFRESH_CODE = '--refresh-code' in sys.argv


def main():
    devpost = read_json(os.path.join(DATA, 'devpost.json'))
    # Rows already checked keep their original link checks, so growing the
    # sample never silently changes an existing row; new rows record the day
    # they were checked.
    path = os.path.join(DATA, 'deterministic.json')
    previous = read_json(path)['submissions'] if os.path.exists(path) else {}
    results = {}
    for submission in devpost['submissions']:
        sid = submission['id']
        links = submission['links']
        if sid in previous:
            entry = previous[sid]
            # --refresh-code re-reads the repository at the recorded snapshot
            # (after a fix to the code analysis); link checks and their date
            # are kept as they were.
            snapshot = entry['repo'].get('snapshot')
            if REFRESH_CODE and snapshot and entry['repo'].get('serverpod'):
                path = clone(sid, links['repo'])
                git(path, '-c', 'advice.detachedHead=false', 'checkout', '-q', snapshot['sha'])
                unresolved = entry['repo']['serverpod'].get('unresolvedDeps', [])
                entry['repo'].update(analyze_tree(path))
                entry['repo']['serverpod']['unresolvedDeps'] = unresolved
            results[sid] = entry
            continue
        print(f'· {sid}')
        entry = {
            'checked': datetime.date.today().isoformat(),
            'demo': demo_access(links),
            'live': live_access(links),
            'repo': {'url': links['repo'], 'status': repo_access(links['repo'])},
        }
        if entry['repo']['status'] == 'public':
            path = clone(sid, links['repo'])
            git(path, 'fetch', '-q', 'origin')
            entry['repo']['commits'] = commit_timing(path)
            snapshot = deadline_snapshot(path)
            entry['repo']['snapshot'] = snapshot
            if snapshot:
                entry['repo'].update(analyze_tree(path))
                if entry['repo'].get('serverpod'):
                    entry['repo']['serverpod']['unresolvedDeps'] = unresolvable(
                        entry['repo']['serverpod']['serverpodDeps'])
        results[sid] = entry
    write_json(os.path.join(DATA, 'deterministic.json'), {
        'deadline': DEADLINE,
        'submissionsOpen': SUBMISSIONS_OPEN,
        'submissions': results,
    })


if __name__ == '__main__':
    main()
