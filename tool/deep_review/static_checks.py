"""Static candidate checks for the evidence dossier.

Deterministic, generic checks over the deadline snapshot. Each result is a
*candidate*: an objective code fact that may matter (or may be a false
positive), with the file and line it rests on. Nothing here decides whether
a candidate matters; `dossier.py` asks a narrow investigator to confirm or
reject each one.

Checks (all generic; none names a submission, a file or an identifier):

  jobs.registeredNeverScheduled   future call registered, never scheduled
  jobs.scheduledNeverRegistered   future call scheduled, never registered
  values.comparedNeverWritten     literal a query compares a field against,
                                  never written to a field of that name
  classes.unreferenced            *Service/*Client/... class nothing else uses
  ui.emptyHandlers                UI callbacks with an empty body
  endpoints.neverCalled           endpoint method the app never calls
  config.optionalNeverSupplied    optional key/token parameter no caller passes
  tables.writtenNeverRead         table inserted into, never read
  tables.readNeverWritten         table read, never written
  external.calls                  outbound HTTP hosts and model APIs (facts)
  demo.textNotInRepo              on-screen demo text with no matching string
                                  literal anywhere in the repository

Output: .cache/<id>/runs/<profile>/static.json
"""

import os
import re
import sys

from common import load_stage, stage_path, write_json

VERSION = 'static-5'

CODE = ('.dart', '.kt', '.java', '.swift', '.ts', '.js', '.py', '.sql')
TEXT = CODE + ('.json', '.yaml', '.yml', '.arb', '.html', '.md', '.xml', '.plist')
SKIP = re.compile(r'(^|/)(\.git|\.dart_tool|build|node_modules|Pods|\.gradle)/|'
                  r'\.(g|freezed|mocks)\.dart$|/generated/|/protocol/.*\.dart$')
ROLE = r'(?:Service|Client|Repository|Manager|Provider|Handler|Controller|Api|Engine|Processor|Scheduler|Worker|Agent)'
CREDENTIAL = r'(?:apiKey|apikey|api_key|token|secret|accessKey|key)'
MAX_PER_CHECK = 25


def read_files(root):
    files = {}
    for directory, _, names in os.walk(root):
        for name in names:
            path = os.path.join(directory, name)
            rel = os.path.relpath(path, root)
            if SKIP.search(rel) or not name.endswith(TEXT):
                continue
            try:
                with open(path, encoding='utf-8') as f:
                    files[rel] = f.read()
            except (UnicodeDecodeError, OSError):
                pass
    return files


def line_of(text, index):
    return text.count('\n', 0, index) + 1


def at(path, text, index):
    line = line_of(text, index)
    return {'path': path, 'line': line, 'text': text.splitlines()[line - 1].strip()[:160]}


def candidate(check, subject, detail, evidence):
    return {'check': check, 'subject': subject, 'detail': detail, 'evidence': evidence[:4]}


def jobs(dart):
    registered, scheduled = {}, {}
    for path, text in dart.items():
        for m in re.finditer(r"registerFutureCall\s*\(([^;]*?)'(\w+)'", text, re.S):
            registered.setdefault(m[2], at(path, text, m.start()))
        for m in re.finditer(r"futureCall\w*\s*\(\s*'(\w+)'", text):
            scheduled.setdefault(m[1], at(path, text, m.start()))
    out = [candidate('jobs.registeredNeverScheduled', name,
                     f'future call "{name}" is registered but nothing schedules it', [ev])
           for name, ev in registered.items() if name not in scheduled]
    out += [candidate('jobs.scheduledNeverRegistered', name,
                      f'future call "{name}" is scheduled but never registered', [ev])
            for name, ev in scheduled.items() if name not in registered]
    return out


def compared_values(dart):
    compared, written = {}, {}
    for path, text in dart.items():
        for m in re.finditer(r"\.(\w+)\.equals\(\s*'([^'$\n]{1,60})'\s*\)", text):
            compared.setdefault((m[1], m[2]), at(path, text, m.start()))
        for m in re.finditer(r"\b(\w+)\s*(?::|=)\s*'([^'$\n]{1,60})'", text):
            written.setdefault(m[1], set()).add(m[2])
    return [candidate('values.comparedNeverWritten', f'{field} == "{value}"',
                      f'a query compares {field} with "{value}", but no code writes "{value}" '
                      f'to a field named {field}', [ev])
            for (field, value), ev in compared.items() if value not in written.get(field, set())]


def unreferenced_classes(dart):
    out = []
    for path, text in dart.items():
        for m in re.finditer(r'^\s*(?:abstract\s+)?class\s+(\w+%s)\b' % ROLE, text, re.M):
            name = m[1]
            used = [p for p, t in dart.items() if p != path and re.search(r'\b%s\b' % name, t)]
            own = len(re.findall(r'\b%s\b' % name, text))
            if not used and own <= 2:
                out.append(candidate('classes.unreferenced', name,
                                     f'class {name} is declared but no other file refers to it',
                                     [at(path, text, m.start())]))
    return out


def empty_handlers(dart):
    by_file = {}
    pattern = re.compile(r"(on\w+\s*:\s*\(\s*_?\s*\)\s*(?:\{\s*\}|=>\s*\{\s*\}|=>\s*null)|"
                         r"'([^'\n]{2,40})'\s*,\s*\(\s*\)\s*\{\s*\})")
    for path, text in dart.items():
        for m in pattern.finditer(text):
            label = m[2]
            if not label:
                window = text[max(0, m.start() - 400):m.start()]
                labels = re.findall(r"Text\(\s*'([^'\n]{2,40})'", window)
                label = labels[-1] if labels else None
            ev = at(path, text, m.start())
            if label:
                ev['label'] = label
            by_file.setdefault(path, []).append(ev)
    return [candidate('ui.emptyHandlers', path,
                      f'{len(evs)} UI callbacks in {path} have an empty body'
                      + (f' (labels: {", ".join(e["label"] for e in evs if e.get("label"))[:160]})'
                         if any(e.get('label') for e in evs) else ''), evs)
            for path, evs in by_file.items()]


def uncalled_endpoints(facts):
    return [candidate('endpoints.neverCalled', f'{m["endpoint"]}.{m["method"]}',
                      f'endpoint method {m["endpoint"]}.{m["method"]} is never called by the app',
                      [{'path': m['at'], 'line': m['line'], 'text': f'{m["method"]}({m["params"]})'}])
            for m in facts.get('endpointMethods', [])
            # Private methods are not exposed as endpoints.
            if not m['method'].startswith('_')
            and not m.get('calledByApp') and not m.get('calledNatively')]


def optional_config(dart):
    out = []
    for path, text in dart.items():
        for m in re.finditer(r'\b(\w+)\s*\(\s*\{[^}]*?\bString\?\s+(%s)\b[^}]*\}\s*\)' % CREDENTIAL, text):
            cls, param = m[1], m[2]
            if cls in ('copyWith', 'fromJson') or not cls[0].isupper():
                continue
            sites = [(p, t, s) for p, t in dart.items()
                     for s in re.finditer(r'(?<![\w.])%s\s*\(([^()]*)\)' % cls, t)
                     if not (p == path and s.start() == m.start())]
            sites = [(p, t, s) for p, t, s in sites if not s[1].strip().startswith('{')]
            if sites and not any(re.search(r'\b%s\s*:' % param, s[1]) for _, _, s in sites):
                out.append(candidate('config.optionalNeverSupplied', f'{cls}.{param}',
                                     f'{cls} takes an optional {param}; none of its {len(sites)} '
                                     f'construction sites passes it',
                                     [at(path, text, m.start())] +
                                     [at(p, t, s.start()) for p, t, s in sites[:3]]))
    return out


def table_key(name):
    """ORM model names and SQL table names differ in case, underscores and
    plural (KnowledgeNode vs knowledge_nodes); compare them normalized."""
    key = name.lower().replace('_', '')
    return key[:-1] if key.endswith('s') else key


def table_access(files):
    """{table: first write}, {table: first read} and unresolved write sites."""
    writes, reads, unresolved = {}, {}, []
    for path, text in files.items():
        for m in re.finditer(r'\b([A-Z]\w*)\.db\.(insert\w*|update\w*|delete\w*)\b', text):
            writes.setdefault(table_key(m[1]), at(path, text, m.start()))
        for m in re.finditer(r'\b([A-Z]\w*)\.db\.(find\w*|count)\b', text):
            reads.setdefault(table_key(m[1]), at(path, text, m.start()))
        # Serverpod 1.x: session.db.find<T>(...), session.db.insert(row).
        for m in re.finditer(r'\.db\.(?:find\w*|count)\s*<\s*(\w+)\s*>', text):
            reads.setdefault(table_key(m[1]), at(path, text, m.start()))
        for m in re.finditer(r'\.db\.(?:insert|update|delete)\w*\s*(?:<\s*(\w+)\s*>)?\s*\(\s*(\w+)', text):
            kind = m[1]
            if not kind:
                declared = re.findall(r'\b(?:final|var)\s+%s\s*=\s*(?:await\s+)?(\w+)\s*\(|\b(\w+)\??\s+%s\s*[=;,)]'
                                      % (m[2], m[2]), text[:m.start()])
                kinds = [a or b for a, b in declared if (a or b)[:1].isupper()]
                kind = kinds[-1] if kinds else None
            if kind:
                writes.setdefault(table_key(kind), at(path, text, m.start()))
            else:
                unresolved.append(at(path, text, m.start()))
        if path.endswith(('.dart', '.py', '.ts', '.js', '.sql')):
            for m in re.finditer(r'\bINSERT\s+INTO\s+"?(\w+)|\bUPDATE\s+"?(\w+)"?\s+SET\b', text, re.I):
                writes.setdefault(table_key(m[1] or m[2]), at(path, text, m.start()))
            for m in re.finditer(r'\b(?:FROM|JOIN)\s+"?(\w+)', text):
                if not path.endswith('.sql'):
                    reads.setdefault(table_key(m[1]), at(path, text, m.start()))
    return writes, reads, unresolved


def tables(files):
    writes, reads, unresolved = table_access(files)
    out = [candidate('tables.writtenNeverRead', t, f'{t} is written but never read', [ev])
           for t, ev in writes.items() if t not in reads]
    # A write whose table cannot be resolved statically could be to any
    # table, so "never written" is only claimed when every write resolved.
    if not unresolved:
        out += [candidate('tables.readNeverWritten', t, f'{t} is read but never written', [ev])
                for t, ev in reads.items() if t not in writes]
    return out


def external_calls(files):
    hosts = {}
    for path, text in files.items():
        if not path.endswith(CODE) or path.endswith('.sql'):
            continue
        for m in re.finditer(r"https?://([a-zA-Z0-9.-]+\.[a-z]{2,})", text):
            host = m[1]
            if host.endswith(('localhost', 'example.com', 'pub.dev', 'flutter.dev', 'dart.dev', 'github.com')):
                continue
            hosts.setdefault(host, []).append(at(path, text, m.start()))
    return [candidate('external.calls', host, f'code refers to {host} in {len(evs)} places', evs)
            for host, evs in hosts.items()]


def inventory(sources):
    """Facts the path and dataflow investigators take as items."""
    root = sources['repo'].get('path')
    if not root or not os.path.isdir(root):
        return {'jobsRegistered': {}, 'jobsScheduled': {}, 'tableWrites': {}, 'tableReads': {},
                'unresolvedWrites': [], 'hosts': {}}
    files = read_files(root)
    dart = {p: t for p, t in files.items() if p.endswith('.dart')}
    registered, scheduled = {}, {}
    for path, text in dart.items():
        for m in re.finditer(r"registerFutureCall\s*\(([^;]*?)'(\w+)'", text, re.S):
            registered.setdefault(m[2], at(path, text, m.start()))
        for m in re.finditer(r"futureCall\w*\s*\(\s*'(\w+)'", text):
            scheduled.setdefault(m[1], at(path, text, m.start()))
    writes, reads, unresolved = table_access(files)
    hosts = {c['subject']: [f'{e["path"]}:{e["line"]}' for e in c['evidence']]
             for c in external_calls(files)}
    return {'jobsRegistered': registered, 'jobsScheduled': scheduled,
            'tableWrites': {t: [f'{e["path"]}:{e["line"]}'] for t, e in writes.items()},
            'tableReads': {t: [f'{e["path"]}:{e["line"]}'] for t, e in reads.items()},
            'unresolvedWrites': [f'{e["path"]}:{e["line"]}' for e in unresolved],
            'hosts': hosts}


def norm(text):
    return re.sub(r'[^a-z0-9]+', ' ', text.lower()).strip()


def demo_text(files, extract):
    corpus = norm('\n'.join(files.values()))
    seen, out = set(), []
    for frame in extract.get('demo', {}).get('frames', []):
        for piece in frame.get('text', '').split(' · '):
            n = norm(piece)
            if len(n) < 12 or len(n.split()) < 2 or n in seen:
                continue
            seen.add(n)
            if n not in corpus:
                out.append((frame['t'], piece.strip()))
    by_frame = {}
    for t, piece in out:
        by_frame.setdefault(t, []).append(piece)
    return [candidate('demo.textNotInRepo', f't={t}',
                      f'on-screen text at t={t} has no matching string literal in the repository: '
                      + ' · '.join(f'"{p[:70]}"' for p in pieces[:6]),
                      [{'t': t, 'text': p} for p in pieces])
            for t, pieces in by_frame.items()]


def run(sources, facts, extract):
    root = sources['repo'].get('path')
    if not root or not os.path.isdir(root):
        return []
    files = read_files(root)
    dart = {p: t for p, t in files.items() if p.endswith('.dart')}
    found = []
    for check in (jobs(dart), compared_values(dart), unreferenced_classes(dart),
                  empty_handlers(dart), uncalled_endpoints(facts), optional_config(dart),
                  tables(files), external_calls(files), demo_text(files, extract)):
        found += check[:MAX_PER_CHECK]
    for i, c in enumerate(found):
        c['id'] = f'S{i:02d}'
    return found


def main(sid):
    sources = load_stage(sid, 'sources')
    facts = load_stage(sid, 'repo_facts')
    extract = load_stage(sid, 'extract')
    found = run(sources, facts, extract)
    write_json(stage_path(sid, 'static'), {'version': VERSION, 'candidates': found})
    counts = {}
    for c in found:
        counts[c['check']] = counts.get(c['check'], 0) + 1
    print(f'· static checks for {sid}: {len(found)} candidates {counts}')


if __name__ == '__main__':
    main(sys.argv[1])
