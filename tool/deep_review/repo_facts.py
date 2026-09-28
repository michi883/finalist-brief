"""Stage 2: deterministic repository analysis.

Reads only the deadline snapshot exported by `acquire.py`. No model is
involved. Produces:

- the pilot's scaffold and Serverpod footprint for this tree;
- an inventory of authored files (generated code and untouched template
  files are marked, not hidden);
- endpoint methods, models and tables, the app's calls into the server,
  dependencies and platform permissions, each with a path and line;
- markers a judge would want to see: TODOs, hard-coded IDs, mocks and
  simulations, unimplemented methods;
- line-numbered excerpts of the most relevant files, within a budget, which
  are the only code the generator sees and may quote.

Output: .cache/<id>/repo_facts.json
"""

import os
import re
import sys

from common import load_stage, pilot_signals, stage_path, write_json

signals = pilot_signals()

RUNNER_STUB_LINES = 30
EXCERPT_BUDGET = 240_000  # characters of numbered source shown to the model
MARKERS = re.compile(
    r'TODO|FIXME|HACK|XXX|\bmock|\bfake\b|\bdummy\b|hard-?coded|placeholder|'
    r'simulat|for now|not implemented|UnimplementedError|userId\s*=\s*\d|'
    r'\bdemo\b|\bstub\b|lorem ipsum',
    re.I)
SIGNATURE = re.compile(
    r'^\s*(?:@\w+\s*)*(Future|Stream)<([^\n(]*)>\s+(\w+)\(\s*Session\b([^)]*)\)',
    re.M)
DB_OP = re.compile(r'\.db\.(\w+)|\b(\w+)\.db\.(\w+)|\bunsafe(Query|Execute)\b')


def line_of(text, index):
    return text.count('\n', 0, index) + 1


def area(rel, kinds):
    owner = max((d for d in kinds if d == '' or rel.startswith(d + '/')),
                key=len, default=None)
    return kinds[owner][0] if owner is not None else 'other'


def endpoint_methods(root, server_dir):
    methods = []
    base = os.path.join(root, server_dir)
    for rel, full in signals.walk(base):
        if not rel.endswith('.dart') or signals.is_generated(rel):
            continue
        text = signals.read(full) or ''
        classes = [(m.start(), m[1]) for m in re.finditer(
            r'class\s+(\w+)\s+extends\s+Endpoint\b', text)]
        classes = [c for c in classes if c[1] not in signals.TEMPLATE_ENDPOINTS]
        if not classes:
            continue
        matches = list(SIGNATURE.finditer(text))
        for i, m in enumerate(matches):
            owner = [c for c in classes if c[0] < m.start()]
            if not owner:
                continue
            end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
            body = text[m.end():end]
            ops = sorted({(g[0] or g[2] or 'raw sql') for g in
                          [(a, b, c) for a, b, c, _ in DB_OP.findall(body)]})
            start = line_of(text, m.start())
            methods.append({
                'endpoint': owner[-1][1],
                'method': m[3],
                'returns': f'{m[1]}<{m[2].strip()}>',
                'params': ' '.join(m[4].split()).strip(', '),
                'at': f'{server_dir}/{rel}' if server_dir not in ('', '.') else rel,
                'line': start,
                'endLine': start + body.count('\n'),
                'dbOps': ops,
                'auth': bool(re.search(
                    r'authenticated|authUserId|requireLogin|getAuthenticatedUserId',
                    body)),
            })
    return methods


def models(root, server_dir):
    found = []
    for rel, full in signals.walk(os.path.join(root, server_dir)):
        if not re.search(r'\.spy(\.ya?ml)?$|lib/src/(models|protocol)/.*\.ya?ml$', rel):
            continue
        text = signals.read(full) or ''
        name = re.search(r'^(class|exception|enum):\s*(\w+)', text, re.M)
        table = re.search(r'^table:\s*(\w+)', text, re.M)
        fields = re.findall(r'^  (\w+):\s*([^\n#]+)', text, re.M)
        found.append({
            'at': f'{server_dir}/{rel}' if server_dir not in ('', '.') else rel,
            'kind': name[1] if name else 'unknown',
            'name': name[2] if name else os.path.basename(rel),
            'table': table[1] if table else None,
            'fields': [f'{k}: {v.strip()}' for k, v in fields
                       if k not in ('fields', 'indexes')][:20],
        })
    return found


# Entities a copy-paste through HTML leaves in source. In Dart code (outside
# strings and comments) they are never valid syntax.
HTML_ENTITY = re.compile(r'&(lt|gt|amp|quot|apos|#\d+|#x[0-9a-fA-F]+);')
STRING_OR_COMMENT = re.compile(r"//.*$|'(?:[^'\\\n]|\\.)*'|\"(?:[^\"\\\n]|\\.)*\"", re.M)


def source_problems(root, files):
    """Source files that cannot be read as normal Dart or model YAML: HTML
    entities (`&lt;`, `&gt;`, …) where code syntax belongs. Such a file does
    not compile, and a parser that finds nothing in it has not shown that
    nothing is there."""
    found = []
    for f in files:
        if f['generated'] or not f['at'].endswith(('.dart', '.spy', '.spy.yaml', '.spy.yml')):
            continue
        text = signals.read(os.path.join(root, f['at'])) or ''
        code = STRING_OR_COMMENT.sub('', text) if f['at'].endswith('.dart') else text
        hits = list(HTML_ENTITY.finditer(code))
        if hits:
            line = line_of(code, hits[0].start())
            found.append({'at': f['at'], 'kind': 'htmlEscaped', 'count': len(hits),
                          'line': line, 'text': text.splitlines()[line - 1].strip()[:160]})
    return found


def endpoint_parsing(root, server_dir, methods, problems):
    """Whether the endpoint method list can be trusted. An endpoint class
    whose file is malformed, or whose methods did not parse although the
    class has Future/Stream members, makes the count "could not be parsed
    reliably", never "none found"."""
    escaped = {p['at'] for p in problems}
    flagged = []
    base = os.path.join(root, server_dir)
    for rel, full in signals.walk(base):
        if not rel.endswith('.dart') or signals.is_generated(rel):
            continue
        text = signals.read(full) or ''
        classes = [c for c in re.findall(r'class\s+(\w+)\s+extends\s+Endpoint\b', text)
                   if c not in signals.TEMPLATE_ENDPOINTS]
        if not classes:
            continue
        at = f'{server_dir}/{rel}' if server_dir not in ('', '.') else rel
        parsed = sum(1 for m in methods if m['at'] == at)
        if at in escaped:
            reason = 'htmlEscaped'
        elif not parsed and re.search(r'\b(Future|Stream)\b', text):
            reason = 'signaturesNotParsed'
        else:
            continue
        flagged.append({'at': at, 'endpoints': classes, 'methodsParsed': parsed,
                        'reason': reason})
    return {'status': 'unreliable' if flagged else 'ok', 'files': flagged}


SECRET_FILE = re.compile(r'passw|secret|credential|\bkeys?\b|token', re.I)
CONFIG_SECTIONS = ('redis', 'futureCall', 'sessionLogs')
CONFIG_SCALARS = ('futureCallExecutionEnabled',)


def yaml_value(raw):
    raw = raw.split(' #')[0].strip().strip('\'"')
    return {'true': True, 'false': False}.get(raw.lower(), raw)


def yaml_text(value):
    return str(value).lower() if isinstance(value, bool) else str(value)


def config_file(text):
    """The runtime settings in one Serverpod run-mode file that decide
    whether a feature is on: listed sections' scalar keys and a few
    top-level switches, each with its line. Values are read literally."""
    out = {}
    lines = text.splitlines()
    for i, line in enumerate(lines):
        top = re.match(r'^(\w+):\s*(.*)$', line)
        if not top:
            continue
        key, value = top[1], top[2]
        if key in CONFIG_SCALARS and value.split('#')[0].strip():
            out[key] = {'value': yaml_value(value), 'line': i + 1}
        elif key in CONFIG_SECTIONS:
            section = {'line': i + 1, 'keys': {}}
            for j in range(i + 1, len(lines)):
                child = lines[j]
                if child.strip() and not child.startswith((' ', '\t', '#')):
                    break
                m = re.match(r'^\s+(\w+):\s*([^#\s][^#]*)', child)
                if m:
                    section['keys'][m[1]] = {'value': yaml_value(m[2]), 'line': j + 1}
            out[key] = section
    return out


def redis_state(settings):
    """Serverpod's rule (serverpod_shared config.dart, 3.x and 4.x): Redis
    is on when the mode has a `redis` section whose `enabled` is true or
    unset, off when the section is missing or `enabled` is false. The
    SERVERPOD_REDIS_ENABLED environment variable can override either."""
    section = settings.get('redis')
    if section is None:
        return {'enabled': False, 'why': 'no redis section'}
    enabled = section['keys'].get('enabled')
    if enabled is None:
        return {'enabled': True, 'why': 'redis section without enabled', 'line': section['line']}
    return {'enabled': enabled['value'] is True, 'why': f'enabled: {yaml_text(enabled["value"])}',
            'line': enabled['line']}


# Server code that needs Redis, uses other caches, or schedules work.
USES = {
    'redis': re.compile(r'caches\.global\b|postMessage\([^;]*global:\s*true|'
                        r'\bRedisController\b'),
    'localCache': re.compile(r'caches\.(local|localPrio|query)\b'),
    'futureCalls': re.compile(r'extends\s+FutureCall\b|futureCall(WithDelay|AtTime)|'
                              r'registerFutureCall|\.futureCalls\b|\.callWithDelay\(|\.callAtTime\('),
}


def compose_services(root):
    """Services declared in Docker Compose files: supporting context only. A
    container that is declared does not show the server uses it."""
    found = []
    for rel, full in signals.walk(root):
        if not re.search(r'(^|/)(docker-)?compose[\w.-]*\.ya?ml$', rel):
            continue
        text = signals.read(full) or ''
        block = re.search(r'^services:\s*\n((?:[ \t].*\n|\s*\n)*)', text, re.M)
        if not block:
            continue
        start = line_of(text, block.start(1))
        for m in re.finditer(r'^  (\w[\w.-]*):\s*$', block[1], re.M):
            body = block[1][m.end():]
            nxt = re.search(r'^  \w', body, re.M)
            image = re.search(r'^\s+image:\s*(\S+)', body[:nxt.start()] if nxt else body, re.M)
            found.append({'at': rel, 'line': start + block[1].count('\n', 0, m.start()),
                          'service': m[1], 'image': image[1] if image else None})
    return found


def serverpod_config(root, server_dir):
    """Runtime configuration, kept apart from code use, so a claim can say
    separately whether a feature is configured, enabled, and used."""
    config_dir = os.path.join(root, server_dir, 'config')
    prefix = f'{server_dir}/config' if server_dir not in ('', '.') else 'config'
    modes = {}
    if os.path.isdir(config_dir):
        for name in sorted(os.listdir(config_dir)):
            stem, ext = os.path.splitext(name)
            # passwords.yaml (and any copy such as passwords_production.yaml)
            # holds secrets; generator.yaml is build config.
            if ext not in ('.yaml', '.yml') or stem == 'generator' or SECRET_FILE.search(stem):
                continue
            settings = config_file(signals.read(os.path.join(config_dir, name)) or '')
            modes[stem] = {'at': f'{prefix}/{name}', 'settings': settings,
                           'redis': redis_state(settings)}
    uses = {k: [] for k in USES}
    base = os.path.join(root, server_dir)
    for rel, full in signals.walk(base):
        if not rel.endswith('.dart') or signals.is_generated(rel) or '/test/' in f'/{rel}':
            continue
        text = STRING_OR_COMMENT.sub('', signals.read(full) or '')
        at = f'{server_dir}/{rel}' if server_dir not in ('', '.') else rel
        for kind, pattern in USES.items():
            for m in pattern.finditer(text):
                uses[kind].append({'at': at, 'line': line_of(text, m.start()),
                                   'match': m[0][:60]})
    return {'modes': modes, 'uses': uses, 'composeServices': compose_services(root)}


def app_calls(root, flutter_dirs, methods, endpoint_classes=()):
    """The app's calls into this server's endpoints, found by the pilot's
    shared detector (direct client accessors and endpoint holders such as
    typed providers), in app files that can run. The endpoint classes come
    from the same footprint as the triage's, so both see the same endpoints
    even when a method signature cannot be parsed."""
    accessors = {e[0].lower() + e[1:].removesuffix('Endpoint'): set() for e in endpoint_classes}
    for m in methods:
        accessor = m['endpoint'][0].lower() + m['endpoint'][1:].removesuffix('Endpoint')
        accessors.setdefault(accessor, set()).add(m['method'])
    return [{'call': f'{a}.{name}', 'at': at, 'line': line}
            for a, name, at, line in signals.endpoint_calls(root, flutter_dirs, accessors)]


def dependencies(root, found):
    deps = {}
    for kind, entries in found.items():
        for directory, spec in entries:
            deps[directory or '.'] = {
                'kind': kind,
                'packages': sorted(n for n in spec['deps']
                                   if n not in ('flutter', 'sdk')),
            }
    return deps


def manifests(root):
    """Android permissions, services and receivers; iOS usage descriptions."""
    found = []
    for rel, full in signals.walk(root):
        name = os.path.basename(rel)
        if name == 'AndroidManifest.xml' and '/src/main/' in rel:
            text = signals.read(full) or ''
            for m in re.finditer(
                    r'<(uses-permission|service|receiver|activity)\b[^>]*'
                    r'android:name="([^"]+)"', text):
                found.append({'at': rel, 'line': line_of(text, m.start()),
                              'kind': m[1], 'name': m[2]})
        elif name == 'Info.plist':
            text = signals.read(full) or ''
            for m in re.finditer(r'<key>(NS\w+UsageDescription|UIBackgroundModes)</key>', text):
                found.append({'at': rel, 'line': line_of(text, m.start()),
                              'kind': 'ios', 'name': m[1]})
    return found


def platform_channels(root, files):
    """Flutter ↔ native bridges: channel names and the methods invoked."""
    found = []
    for f in files:
        if f['generated'] or not f['at'].endswith(('.dart', '.kt', '.java', '.swift')):
            continue
        text = signals.read(os.path.join(root, f['at'])) or ''
        for m in re.finditer(r'(Method|Event)Channel\(\s*(?:[\w.]+,\s*)?[\'"]([^\'"]+)', text):
            found.append({'at': f['at'], 'line': line_of(text, m.start()),
                          'kind': 'channel', 'name': m[2]})
        for m in re.finditer(r'invokeMethod(?:<[^>]*>)?\(\s*[\'"](\w+)', text):
            found.append({'at': f['at'], 'line': line_of(text, m.start()),
                          'kind': 'invokes', 'name': m[1]})
        for m in re.finditer(r'^\s*"(\w+)"\s*->', text, re.M):
            found.append({'at': f['at'], 'line': line_of(text, m.start()),
                          'kind': 'handles', 'name': m[1]})
    return found


def inventory(root, kinds, untouched):
    files = []
    for rel, full in signals.walk(root):
        ext = os.path.splitext(rel)[1]
        if ext not in signals.CODE_EXTENSIONS and not rel.endswith(
                ('.spy', '.spy.yaml', '.spy.yml', 'pubspec.yaml', 'AndroidManifest.xml')):
            continue
        parts = rel.split('/')
        kind = area(rel, kinds)
        in_platform = any(p in signals.PLATFORM_DIRS for p in parts[:3])
        if in_platform and ext not in ('.kt', '.java', '.swift', '.xml'):
            continue
        text = signals.read(full)
        if text is None or signals.looks_minified(text):
            continue
        # Platform runners that grew far beyond `flutter create`'s stub hold
        # real native code (the pilot's scaffold delta skips them by name).
        grown = len(signals.nonblank(text)) > RUNNER_STUB_LINES
        if in_platform and parts[-1] in signals.PLATFORM_DEFAULTS and (
                not grown or parts[-1].startswith('GeneratedPluginRegistrant')):
            continue
        files.append({
            'at': rel,
            'area': kind,
            'lines': len(signals.nonblank(text)),
            'generated': signals.is_generated(rel),
            'untouchedTemplate': rel in untouched,
        })
    return files


def app_reachability(root, files, kinds):
    """Marks each app Dart file under a Flutter package's lib/ as reachable
    or not, using the pilot's shared rule: import/export/part edges from
    lib/main*.dart, across local packages. A file nothing reachable imports
    exists but never runs; citing it for what the app does attributes
    behaviour to the wrong code."""
    dirs = [d for d, (kind, _) in kinds.items() if kind == 'flutter']
    runnable = signals.runnable_dart(root, dirs)
    if runnable is None:
        return
    prefixes = [f'{d}/lib/' if d else 'lib/' for d in dirs]
    for f in files:
        if f['at'].endswith('.dart') and any(f['at'].startswith(p) for p in prefixes):
            f['reachable'] = f['at'] in runnable


def markers(root, files):
    found = []
    for f in files:
        if f['generated'] or f['untouchedTemplate'] or f['at'].endswith('.lock'):
            continue
        text = signals.read(os.path.join(root, f['at'])) or ''
        for i, line in enumerate(text.splitlines(), 1):
            if MARKERS.search(line):
                found.append({'at': f['at'], 'line': i, 'text': line.strip()[:160]})
    return found[:120]


OUTLINE_CAP = 12
DECLARATION = re.compile(
    r'^\s*(?:class|mixin|enum|extension)\s+(\w+)'
    r'|^\s*(?:static\s+|external\s+)*(?:Future|Stream|void|bool|int|double|String|List|Map|Set|[A-Z]\w*)'
    r'(?:<[^\n(]*>)?\??\s+(\w+)\s*\('
    r'|^\s*(?:async\s+)?def\s+(\w+)\s*\(|^\s*(?:export\s+)?(?:async\s+)?function\s+(\w+)', re.M)
IMPORT = re.compile(r"^\s*import\s+['\"]package:(\w+)/|^\s*from\s+([\w.]+)\s+import|^\s*import\s+([\w.]+)\s*$", re.M)
SCHEME = re.compile(r"\bscheme:\s*['\"](\w+)['\"]|['\"](sms|tel|mailto|whatsapp|geo):")
HOST = re.compile(r'https?://([\w-]+(?:\.[\w-]+)+)')
NOT_NAMES = {'if', 'for', 'while', 'switch', 'catch', 'return', 'build', 'setState'}


def outline(root, rel, own_packages=()):
    """A file that did not fit the excerpt budget, reduced to what it
    touches: packages it imports, what it declares, URI schemes and hosts
    it uses. Not quotable; it only stops an unseen file from reading as an
    absent feature."""
    text = signals.read(os.path.join(root, rel)) or ''
    imports = sorted({(m[1] or m[2] or m[3]).split('.')[0] for m in IMPORT.finditer(text)}
                     - {'flutter', *own_packages})
    names = []
    for m in DECLARATION.finditer(text):
        name = next(g for g in m.groups() if g)
        if name not in names and name not in NOT_NAMES:
            names.append(name)
    schemes = sorted({m[1] or m[2] for m in SCHEME.finditer(text)})
    hosts = sorted({h for h in HOST.findall(text) if not h.startswith(('localhost', '127.'))})
    return {'at': rel, 'imports': imports[:OUTLINE_CAP], 'declares': names[:OUTLINE_CAP],
            'schemes': schemes, 'hosts': hosts[:6]}


def excerpts(root, files, methods, calls, model_list, marks, manifest):
    """Numbered source of the most telling files, within EXCERPT_BUDGET."""
    def priority(f):
        at = f['at']
        if f['generated'] or f['untouchedTemplate']:
            return 9
        if any(m['at'] == at for m in methods):
            return 0
        if any(m['at'] == at for m in model_list):
            return 1
        if any(c['at'] == at for c in calls) or any(m['at'] == at for m in manifest):
            return 2
        if at.endswith(('.kt', '.java', '.swift')):
            return 2
        if any(m['at'] == at for m in marks):
            return 3
        if at.endswith('pubspec.yaml'):
            return 4
        return 5

    chosen, used, skipped = [], 0, []
    for f in sorted(files, key=lambda f: (priority(f), f['lines'])):
        if priority(f) == 9:
            continue
        text = signals.read(os.path.join(root, f['at'])) or ''
        numbered = '\n'.join(f'{i:4d}| {l}' for i, l in enumerate(text.splitlines(), 1))
        if used + len(numbered) > EXCERPT_BUDGET:
            skipped.append(f['at'])
            continue
        used += len(numbered)
        chosen.append({'at': f['at'], 'text': numbered})
    return chosen, skipped


def main(sid):
    sources = load_stage(sid, 'sources')
    repo = sources['repo']
    if repo.get('status') != 'public':
        write_json(stage_path(sid, 'repo_facts'), {'status': repo.get('status')})
        return
    root = repo['path']
    print(f'· analysing {sid} at {repo["sha"]}')
    analysis = signals.analyze_tree(root)
    found = signals.packages(root)
    kinds = {d: (k, s['name']) for k, entries in found.items() for d, s in entries}
    sp = analysis.get('serverpod') or {}
    server_dir = sp.get('server', '.')
    untouched = set(analysis.get('scaffold', {}).get('untouchedTemplateFiles', []))
    files = inventory(root, kinds, untouched)
    app_reachability(root, files, kinds)
    methods = endpoint_methods(root, server_dir) if sp else []
    model_list = models(root, server_dir) if sp else []
    endpoints = {m['endpoint'] for m in methods}
    calls = app_calls(root, sp.get('flutter', []), methods,
                      (analysis.get('footprint') or {}).get('endpoints', []))
    marks = markers(root, files)
    manifest = manifests(root)
    channels = platform_channels(root, files)
    chosen, skipped = excerpts(root, files, methods, calls, model_list, marks, manifest)
    problems = source_problems(root, files)
    parsing = endpoint_parsing(root, server_dir, methods, problems) if sp else {
        'status': 'ok', 'files': []}
    config = serverpod_config(root, server_dir) if sp else None
    # Run-mode files are short and hold no secrets (passwords.yaml is never
    # read): shown so a claim about a setting can quote its line.
    for mode in (config or {}).get('modes', {}).values():
        text = signals.read(os.path.join(root, mode['at'])) or ''
        chosen.append({'at': mode['at'], 'text': '\n'.join(
            f'{i:4d}| {l}' for i, l in enumerate(text.splitlines(), 1))})
    called = {c['call'] for c in calls}
    native = [(f['at'], signals.read(os.path.join(root, f['at'])) or '')
              for f in files if f['at'].endswith(('.kt', '.java', '.swift'))]
    for m in methods:
        accessor = m['endpoint'][0].lower() + m['endpoint'][1:].removesuffix('Endpoint')
        m['calledByApp'] = f'{accessor}.{m["method"]}' in called
        # Native code can reach an endpoint over plain HTTP at /accessor/method.
        for at, text in native:
            hit = re.search(rf'/{accessor}/{m["method"]}\b', text)
            if hit:
                m['calledNatively'] = {'at': at, 'line': line_of(text, hit.start())}
                calls.append({'call': f'{accessor}.{m["method"]}', 'at': at,
                              'line': line_of(text, hit.start()), 'native': True})
    own = {name for _, name in kinds.values()}
    outlines = [outline(root, at, own) for at in skipped
                if not at.endswith(('pubspec.yaml', '.xml'))]
    facts = {
        'sha': repo['sha'],
        'url': repo['url'],
        'commitsAfterDeadline': repo['commitsAfterDeadline'],
        'summary': {k: analysis[k] for k in
                    ('serverpod', 'scaffold', 'footprint', 'tests', 'aiInCode',
                     'otherBackends') if k in analysis},
        'sourceProblems': problems,
        'endpointParsing': parsing,
        'serverpodConfig': config,
        'files': files,
        'endpointMethods': methods,
        'models': model_list,
        'appCalls': calls,
        'dependencies': dependencies(root, found),
        'platform': manifest,
        'platformChannels': channels,
        'markers': marks,
        'excerpts': chosen,
        'notShown': skipped,
        'notShownOutlines': outlines,
    }
    if parsing['status'] == 'unreliable':
        # The pilot's count uses the same signature parser: a count from a
        # file it could not read is unknown, not zero.
        footprint = facts['summary'].get('footprint')
        if footprint:
            facts['summary']['footprint'] = {**footprint, 'endpointMethods': 'unknown (see endpointParsing)'}
    write_json(stage_path(sid, 'repo_facts'), facts)
    count = (f'{len(methods)} endpoint methods' if parsing['status'] == 'ok' else
             f'endpoint methods NOT reliably parsed ({len(methods)} read; '
             f'{len(parsing["files"])} endpoint files flagged)')
    if problems:
        print(f'  malformed source: {len(problems)} files with HTML-escaped syntax, '
              f'e.g. {problems[0]["at"]}:{problems[0]["line"]}')
    print(f'  {len(files)} files · {count} '
          f'({sum(m["calledByApp"] for m in methods)} called by the app) · '
          f'{len(model_list)} models · {len(marks)} markers · '
          f'{len(chosen)} files shown, {len(skipped)} over budget')


if __name__ == '__main__':
    main(sys.argv[1])
