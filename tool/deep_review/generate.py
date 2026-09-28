"""Stage 4: semantic representation generation.

One model call turns the acquired evidence into a draft deep review: summary,
Idea graph, Integration graph, Idea → Integration observations, evidence and
judge questions. The model never writes source references directly. It
cites writeup lines, code lines with a verbatim quote, demo frames or
narration, and `ground.py` turns only verifiable citations into references.

The prompt is generic: nothing in it names or describes a particular
submission. Tone examples are pulled from the other deep reviews as phrases,
never as graphs, so their topology cannot be copied.

When the draft breaks a structural rule or cites something that does not
exist, the model gets the list of problems and returns a corrected draft
(at most MAX_REPAIRS times). Whatever still fails is handled by grounding.
On Claude the repairs are later turns of one conversation, so the context is
sent once and read from the prompt cache afterwards; stateless providers
re-send the context and the previous draft with each repair.

Output: .cache/<id>/draft.json
"""

import json
import sys

from common import (
    ASSET, ClaudeSession, SessionDiverged, ask, load_stage, read_json, route,
    stage_path, write_json,
)
import ground
import repo_facts

MAX_REPAIRS = 3
SIDE = {'flutter': 'app', 'server': 'server', 'client': 'shared client'}

SYSTEM = """You write deep reviews for Finalist Brief, a tool that helps \
hackathon judges understand one submission in a few minutes. You do not \
judge, score or rank. A judge opening your review must quickly understand: \
what the project does, how it is built, how the idea maps onto the build, \
what is verified, what is uncertain, and what to ask the team.

You receive the submission's sources: the writeup as numbered lines, the \
demo's narration (automatic captions may mishear words), literal \
observations of demo frames, deterministic facts about the repository at its \
last commit before the deadline, and line-numbered source excerpts. These \
are your only sources. Do not use outside knowledge about the team or \
project.

WHAT TO PRODUCE

1. summary: one direct, literal sentence (under 150 characters) saying what \
a user does with the project and what happens. Never the team's pitch: no \
adjectives such as intelligent, seamless, powerful, smart, effortless, \
revolutionary; no "AI-powered". If the build does less than the writeup \
claims, describe what the submission presents, plainly.

2. idea: the conceptual structure the TEAM PRESENTS (writeup, narration, \
tagline). 3 to 6 nodes. Only the essential concepts; merge or drop the rest.

3. integration: the build structure that matters, from the code and demo. \
3 to 6 nodes. Show the parts that realize (or fail to realize) the idea, not \
every file. Preserve uncertainty: if a connection is not visible in code, \
say so through an inferred edge or a node detail such as "Not in the repo". \
A part that is claimed but absent belongs in the mapping or a question, not \
as an invented node.

The submission determines the topology. Choose per graph: \
"flow" (a pipeline from left to right), "loop" (a cycle drawn as a ring; \
close it with one feedback edge), "hub" (one central node, named in focus, \
with the others around it), "layers" (stacked tiers, e.g. app, server, \
storage). Do not default to a shape; pick what this submission's structure is.

Node kinds: human (a person or role), surface (a screen or app a person \
uses), model (an AI model), transformation (code that computes, decides or \
stores: an endpoint, a scheduler, a rule engine), external (a third-party \
system or the device's OS), signal (a measured or observed quantity), \
artifact (stored data, files, tables).

Labels: node label at most 22 characters, a noun phrase a judge can read at \
a glance ("Meeting reminder", "Rules endpoint"). Labels are for judges, not \
developers: plain words, no class or method names unless the name itself \
is the finding. detail (sublabel) at most \
18 characters and only when it carries a finding ("Not in the repo", \
"No AI model", "Newest first"); otherwise empty. Edge labels at most 18 \
characters, short verbs ("posts", "saved as user 1", "every hour"); empty \
when the direction says enough. Flow edges must not form a cycle; mark the \
edge that closes a cycle as kind "feedback". Every graph must be connected. \
Keep each diagram simple to read: in a flow, edges should join neighbouring \
steps; at most one edge may jump over other nodes.

4. mapping: at most 4 Idea → Integration observations, each a plain \
statement of at most 40 characters in the form "<idea part> → <what the \
build does>", e.g. "Popular issues rise → newest first", "4 audiences → \
1 runtime", "Insurer → not built". Prefer observations that show \
compression, mismatch or a missing counterpart over ones that merely \
confirm. An empty integration list means no counterpart exists.

5. evidence: every node and every mapping has evidence; an edge has evidence \
only when its label states a finding. Evidence = status + a one-line note \
(under 130 characters, literal, no hype) + citations. Every part of a note \
must be supported by its own citations; a finding that needs other \
evidence belongs in its own node, edge, mapping or question. Statuses, strongest \
first; use the strongest one your citations directly support, never more:
   - demonstrated: seen working in a demo frame. Cite the frame's t. \
Narration alone never demonstrates anything. A screen that merely exists is \
not the claimed behaviour working.
   - foundInCode: located in the repository. Cite the file path, the line \
range that shows the whole claim (the method or block, up to 40 lines), and \
a verbatim quote from inside that range (copied exactly: one line or a \
distinctive fragment of one). A checker will see only the cited lines, so \
cite every place the claim depends on, one citation each. A claim that \
something is absent ("never", "no …") must cite the place where it would \
have to be, e.g. the whole method or the manifest declaration.
   - described: stated by the team. Cite the writeup line ID with a verbatim \
quote, or the narration with its t and a verbatim quote.
   - inferred: your structural reading with no direct source; cite nothing \
or whatever partially supports it, and say in the note what is inferred.
Set frame to the t of the demo frame that best shows a demonstrated node; \
omit it otherwise.

Demo frames are samples taken a few seconds apart (the interval is given \
with them). Something missing from them may have happened between samples. \
Never write that the demo does not show, skips, or starts after something, \
and never build a finding on such an absence. Write "not observed in the \
sampled frames", or leave it open. Only what a frame visibly shows (e.g. an \
error on screen) supports a claim about the demo.

Attribute behaviour to the code that actually runs it. Before citing code \
for what the app, a screen or a feature does, follow the path from that \
screen or caller to the code it calls, and cite that code, not a similarly \
named file, an alternative path or an endpoint used elsewhere. Say on which \
side it runs (in the app or on the server). The repository facts mark app \
files that are never imported and endpoint methods the app never calls: \
such code exists but does not run, so cite it only to say that, and say it \
plainly ("unused", "never called"). When code offers several paths (e.g. a \
model with fallbacks), name the path the code selects, or say which paths \
are possible and that the sources do not show which one ran.

6. questions: 1 to 4 judge questions, only where a concrete gap, mismatch or \
uncertainty exists in the sources. None generic ("How will you scale?"). \
Each: the question (ends with "?", at most two short sentences and 200 \
characters, neutral, specific), the basis (why it arises, pointing at the \
evidence; at most 280 characters), its kind (mismatch: \
the idea and the build disagree, anchored in BOTH graphs; unverified: a \
claim that the sources cannot confirm; unclear: a relationship the sources \
leave open; implementation: a concrete build question), anchors (the first \
must be a node) and citations.

7. dimensions: descriptive placement in the Competition View, each a value \
from 0 to 1 with a one-line note stating the fact behind it. Place this \
submission relative to the other reviewed submissions given below; these \
are positions, not merit. ideaDistinctiveness: how unusual the concept's \
structure is within this field. integrationDepth: how much working \
implementation stands behind the idea. sponsorCentrality: how much of the \
core function depends on the sponsor technology (Serverpod). \
sponsorEvidence: how clearly that use of Serverpod can be verified.

8. uncertainties: a few short sentences for the pipeline log (not shown to \
judges) on what you could not determine or resolved by judgement.

Never invent relationships, numbers or behaviour that the sources do not \
show. Never promote evidence beyond what the cited source supports. When in \
doubt, choose the weaker status and say what is missing."""

CITE = {
    'type': 'object',
    'properties': {
        'source': {'type': 'string', 'enum': ['writeup', 'repo', 'demo', 'narration']},
        'line': {'type': 'string', 'description': 'Writeup line ID, e.g. L012'},
        'path': {'type': 'string', 'description': 'Repository path'},
        'from': {'type': 'integer'},
        'to': {'type': 'integer'},
        't': {'type': 'integer', 'description': 'Seconds into the demo'},
        'quote': {'type': 'string', 'description': 'Verbatim text'},
    },
    'required': ['source'],
}
EVIDENCE = {
    'type': 'object',
    'properties': {
        'status': {'type': 'string', 'enum': [
            'demonstrated', 'foundInCode', 'described', 'inferred']},
        'note': {'type': 'string'},
        'cites': {'type': 'array', 'items': CITE},
        'frame': {'type': 'integer'},
    },
    'required': ['status', 'note', 'cites'],
}
NODE = {
    'type': 'object',
    'properties': {
        'id': {'type': 'string', 'description': 'lowercase slug'},
        'label': {'type': 'string'},
        'kind': {'type': 'string', 'enum': [
            'human', 'surface', 'model', 'transformation', 'external',
            'signal', 'artifact']},
        'detail': {'type': 'string'},
        'evidence': EVIDENCE,
    },
    'required': ['id', 'label', 'kind', 'detail', 'evidence'],
}
EDGE = {
    'type': 'object',
    'properties': {
        'from': {'type': 'string'},
        'to': {'type': 'string'},
        'kind': {'type': 'string', 'enum': ['flow', 'feedback']},
        'label': {'type': 'string'},
        'evidence': EVIDENCE,
    },
    'required': ['from', 'to', 'kind', 'label'],
}
GRAPH = {
    'type': 'object',
    'properties': {
        'topology': {'type': 'string', 'enum': ['flow', 'loop', 'hub', 'layers']},
        'focus': {'type': 'string'},
        'description': {'type': 'string', 'description':
                        'One plain sentence, at most 100 characters.'},
        'nodes': {'type': 'array', 'items': NODE},
        'edges': {'type': 'array', 'items': EDGE},
    },
    'required': ['topology', 'description', 'nodes', 'edges'],
}
DIMENSION = {
    'type': 'object',
    'properties': {'value': {'type': 'number'}, 'note': {'type': 'string'}},
    'required': ['value', 'note'],
}
SCHEMA = {
    'type': 'object',
    'properties': {
        'summary': {'type': 'string'},
        'idea': GRAPH,
        'integration': GRAPH,
        'mapping': {'type': 'array', 'items': {
            'type': 'object',
            'properties': {
                'label': {'type': 'string'},
                'idea': {'type': 'array', 'items': {'type': 'string'}},
                'integration': {'type': 'array', 'items': {'type': 'string'}},
                'evidence': EVIDENCE,
            },
            'required': ['label', 'idea', 'integration', 'evidence'],
        }},
        'questions': {'type': 'array', 'items': {
            'type': 'object',
            'properties': {
                'id': {'type': 'string'},
                'kind': {'type': 'string', 'enum': [
                    'mismatch', 'unverified', 'unclear', 'implementation']},
                'question': {'type': 'string'},
                'basis': {'type': 'string'},
                'anchors': {'type': 'array', 'items': {
                    'type': 'object',
                    'properties': {
                        'lens': {'type': 'string', 'enum': ['idea', 'integration']},
                        'node': {'type': 'string'},
                        'edge': {'type': 'array', 'items': {'type': 'string'}},
                    },
                    'required': ['lens'],
                }},
                'cites': {'type': 'array', 'items': CITE},
            },
            'required': ['id', 'kind', 'question', 'basis', 'anchors', 'cites'],
        }},
        'dimensions': {
            'type': 'object',
            'properties': {k: DIMENSION for k in (
                'ideaDistinctiveness', 'integrationDepth',
                'sponsorCentrality', 'sponsorEvidence')},
            'required': ['ideaDistinctiveness', 'integrationDepth',
                         'sponsorCentrality', 'sponsorEvidence'],
        },
        'uncertainties': {'type': 'array', 'items': {'type': 'string'}},
    },
    'required': ['summary', 'idea', 'integration', 'mapping', 'questions',
                 'dimensions', 'uncertainties'],
}


def field_context(sid):
    """Other reviews: their placements (for calibration) and tone phrases."""
    field = [p for p in read_json(ASSET)['projects'] if p['id'] != sid]
    placements, phrases = [], []
    for p in field:
        dims = {k: (v['value'], v['note']) for k, v in p['competitionDimensions'].items()}
        placements.append(f'- {p["title"]}: ' + '; '.join(
            f'{k} {v:.2f} ({note})' for k, (v, note) in dims.items()))
        nodes = [n['label'] + (f' / {n["detail"]}' if n.get('detail') else '')
                 for g in ('idea', 'integration') for n in p[g]['nodes']]
        edges = sorted({e['label'] for g in ('idea', 'integration')
                        for e in p[g]['edges'] if e.get('label')})
        q = p['questions'][0] if p['questions'] else None
        phrases.append('\n'.join([
            f'- Summary: {p["summary"]}',
            f'  Node labels: {", ".join(nodes)}',
            f'  Edge labels: {", ".join(edges)}',
            f'  Observations: {", ".join(m["label"] for m in p["mapping"])}',
            *([f'  Question: {q["question"]}', f'  Basis: {q["basis"]}'] if q else []),
        ]))
    return '\n'.join(placements), '\n'.join(phrases)


def link_facts(sources):
    """Every link the submission gives, typed only where a source
    establishes the type. Devpost's demo field embeds a video, so that link
    is a video. The "Try it out" links carry no type: a URL's host or path
    (a Drive file, a .app domain) never decides what is behind it, so they
    stay `unknown`. The pilot's check result travels with each link."""
    links = []
    demo = sources.get('demo') or {}
    if demo.get('url'):
        links.append({'url': demo['url'], 'type': 'video',
                      'source': "Devpost's demo video field",
                      'status': demo.get('status')})
    checks = {c['url']: c for c in sources.get('liveChecks', [])}
    for url in sources.get('live', []):
        check = checks.get(url)
        links.append({'url': url, 'type': 'unknown',
                      'source': "Devpost 'Try it out' link",
                      'status': (f'{check["status"]}, HTTP {check.get("http")} when checked'
                                 if check else 'not checked')})
    return links


def links_text(sources):
    links = link_facts(sources)
    if not links:
        return 'Links: none'
    return ('Links (a type is given only where a source establishes it; for '
            '"type unknown", nothing shows what the link is, so never call it a '
            'video, app, deployment or download; say "the Drive link" or "the '
            'second link"):\n' + '\n'.join(
                f'- {l["url"]}: ' + (f'{l["type"]} ({l["source"]})' if l['type'] != 'unknown'
                                     else f'type unknown ({l["source"]})') +
                (f'; {l["status"]}' if l.get('status') else '')
                for l in links))


def config_text(facts):
    """Serverpod runtime configuration as three separate facts per feature:
    configured, enabled, used by server code."""
    config = facts.get('serverpodConfig')
    if not config:
        return 'none (no Serverpod server found)'
    out = ['Redis support is part of the serverpod package; it needs no extra '
           'dependency. Per run mode, Serverpod turns Redis on when the file has '
           'a redis section whose enabled is true or unset; the '
           'SERVERPOD_REDIS_ENABLED environment variable can override this at '
           'deploy time.']
    for mode, m in config['modes'].items():
        r = m['redis']
        detail = [f'redis {"enabled" if r["enabled"] else "disabled"} ({r["why"]}'
                  + (f', line {r["line"]})' if r.get('line') else ')')]
        for key, v in m['settings'].items():
            if key == 'redis':
                continue
            if 'keys' in v:
                detail.append(f'{key}: ' + (', '.join(
                    f'{k}={repo_facts.yaml_text(x["value"])} (line {x["line"]})' for k, x in v['keys'].items()) or 'empty'))
            else:
                detail.append(f'{key}={repo_facts.yaml_text(v["value"])} (line {v["line"]})')
        out.append(f'- {mode} ({m["at"]}): ' + '; '.join(detail))
    if not config['modes']:
        out.append('- no run-mode config files found')
    names = {'redis': 'Server code that needs Redis (global caches, global messages, '
                      'RedisController)',
             'localCache': 'Server code using local caches',
             'futureCalls': 'Server code scheduling future calls'}
    for kind, label in names.items():
        uses = config['uses'].get(kind, [])
        out.append(f'{label}: ' + ('; '.join(
            f'{u["match"]} at {u["at"]}:{u["line"]}' for u in uses[:8]) or 'none found'))
    services = config['composeServices']
    out.append('Docker Compose services (supporting context only: a declared '
               'container does not show that the server uses it): ' + ('; '.join(
                   f'{c["service"]}' + (f' ({c["image"]})' if c['image'] else '')
                   + f' at {c["at"]}:{c["line"]}' for c in services) or 'none'))
    out.append('Keep three things apart: a feature is configured, it is enabled, '
               'and code uses it. Say which of these the facts show.')
    return '\n'.join(out)


def outlines_text(facts):
    """Outlines of files that did not fit: enough to know a feature may be
    there, never enough to quote or to call it missing."""
    rows = []
    for o in facts.get('notShownOutlines') or []:
        parts = [f'imports {", ".join(o["imports"])}' if o['imports'] else '',
                 f'declares {", ".join(o["declares"])}' if o['declares'] else '',
                 f'URI schemes {", ".join(o["schemes"])}' if o['schemes'] else '',
                 f'hosts {", ".join(o["hosts"])}' if o['hosts'] else '']
        rows.append(f'- {o["at"]}: ' + ('; '.join(p for p in parts if p) or 'nothing detected'))
    if not rows:
        return ''
    return ('\n\n## Outlines of files not shown (deterministic; not quotable). A file '
            'not shown is unseen, not absent: never state or imply that the repository '
            'lacks something an outline below may contain (e.g. an sms scheme, a '
            'notification package, an AI SDK). Say the file was not shown and name it.\n'
            + '\n'.join(rows))


def parsing_text(facts):
    problems = facts.get('sourceProblems') or []
    parsing = facts.get('endpointParsing') or {'status': 'ok', 'files': []}
    out = []
    if problems:
        out.append('Malformed source (HTML entities where Dart or model syntax '
                   'belongs; such a file does not compile as written):\n' + '\n'.join(
                       f'- {p["at"]}:{p["line"]} ({p["count"]} entities): {p["text"]}'
                       for p in problems[:12]))
    if parsing['status'] != 'ok':
        out.append('Endpoint methods could NOT be parsed reliably in these files, so '
                   'the endpoint method list below is incomplete. Do not read it as '
                   '"no endpoints" or "no methods"; use the excerpts:\n' + '\n'.join(
                       f'- {f["at"]} ({", ".join(f["endpoints"])}): {f["reason"]}, '
                       f'{f["methodsParsed"]} methods parsed' for f in parsing['files']))
    return '\n'.join(out) or 'none'


def facts_text(sources, facts, extract):
    parts = [
        f'# Submission\nTitle: {sources["title"]}\nTagline: {sources["tagline"]}\n'
        f'Team: {", ".join(sources["team"])}\n'
        f'Built with (self-reported): {", ".join(sources["builtWith"])}\n'
        + links_text(sources),
        '# Writeup (numbered lines; [kind] is an automatic classification)\n' + '\n'.join(
            f'{l["id"]}| ' + ('## ' if l['heading'] else '') + l['text'] +
            (f'  [{l["kind"]}]' if l.get('kind') and not l['heading'] else '')
            for l in extract['writeup']),
    ]
    narration = extract['narration']
    if narration['cues']:
        parts.append(
            f'# Demo narration ({narration["kind"]} captions; t in seconds)\n' +
            '\n'.join(f't={int(c["start"])}| {c["text"]}' for c in narration['cues']))
    demo = extract['demo']
    step = sources.get('demo', {}).get('step')
    parts.append('# Demo frames (literal observations by a separate pass that '
                 'saw only the frames)\n' + (
                     f'Frames are samples, one every {step} s; whatever happened between '
                     'them was not observed.\n' if step else '') + '\n'.join(
                     f't={f["t"]} [{f["kind"]}] {f["shows"]} | text: {f["text"]}'
                     for f in demo['frames']) + f'\nSequence: {demo["sequence"]}')
    if facts.get('files'):
        summary = facts['summary']
        methods = '\n'.join(
            f'- {m["endpoint"]}.{m["method"]}({m["params"]}) → {m["returns"]} '
            f'at {m["at"]}:{m["line"]}-{m["endLine"]}; db: {", ".join(m["dbOps"]) or "none"}; '
            f'checks auth: {m["auth"]}; called from Flutter code: {m["calledByApp"]}'
            + (f'; called over HTTP from native code at {m["calledNatively"]["at"]}:'
               f'{m["calledNatively"]["line"]}' if m.get('calledNatively') else '')
            for m in facts['endpointMethods'])
        parts.append('\n'.join([
            '# Repository facts (deterministic, from the deadline snapshot)',
            f'Snapshot: {facts["sha"]} ({sources["repo"]["date"]}); '
            f'{facts["commitsAfterDeadline"]} commits after the deadline are not read.',
            f'Serverpod: {json.dumps(summary.get("serverpod"))}',
            f'Scaffold delta (authored lines beyond the `serverpod create` template, '
            f'excluding native platform code): {json.dumps(summary.get("scaffold"))}',
            f'Footprint: {json.dumps(summary.get("footprint"))}',
            f'Tests: {json.dumps(summary.get("tests"))}',
            f'AI SDKs or endpoints referenced in code: {summary.get("aiInCode") or "none"}',
            f'Other backends: {summary.get("otherBackends") or "none"}',
            '## Source that could not be read normally\n' + parsing_text(facts),
            '## Serverpod runtime configuration\n' + config_text(facts),
            '## Endpoint methods\n' + (methods or (
                'none parsed (see above: not the same as none present)'
                if (facts.get('endpointParsing') or {}).get('status') == 'unreliable'
                else 'none')),
            '## Models\n' + ('\n'.join(
                f'- {m["kind"]} {m["name"]}' + (f' (table {m["table"]})' if m['table'] else '')
                + f' at {m["at"]}: {", ".join(m["fields"])}' for m in facts['models']) or 'none'),
            '## Calls from the app into the server\n' + ('\n'.join(
                f'- {c["call"]} at {c["at"]}:{c["line"]}' + (' (native HTTP)' if c.get('native') else '')
                for c in facts['appCalls']) or 'none'),
            '## Dependencies\n' + '\n'.join(
                f'- {d} ({v["kind"]}): {", ".join(v["packages"])}'
                for d, v in facts['dependencies'].items()),
            '## Platform manifest\n' + ('\n'.join(
                f'- {p["kind"]} {p["name"]} at {p["at"]}:{p["line"]}'
                for p in facts['platform']) or 'none'),
            '## Flutter ↔ native channels\n' + ('\n'.join(
                f'- {c["kind"]} {c["name"]} at {c["at"]}:{c["line"]}'
                for c in facts['platformChannels']) or 'none'),
            '## Markers (TODO, mock, simulate, hard-coded IDs, …)\n' + ('\n'.join(
                f'- {m["at"]}:{m["line"]}: {m["text"]}' for m in facts['markers']) or 'none'),
            '## App files that exist but never run (nothing reachable from the '
            "app's lib/main*.dart imports them)\n" + ('\n'.join(
                f'- {f["at"]}' for f in facts['files'] if f.get('reachable') is False) or 'none'),
            '## Files (non-blank lines; side: app, server or shared client code; '
            'generated, untouched template and never-imported files marked)\n' +
            '\n'.join(f'- {f["at"]} ({f["lines"]}; {SIDE.get(f["area"], f["area"])})' +
                      (' [never imported]' if f.get('reachable') is False else '') +
                      (' [generated]' if f['generated'] else '') +
                      (' [untouched template]' if f['untouchedTemplate'] else '')
                      for f in facts['files']),
        ]))
        excerpts = '\n\n'.join(f'=== {e["at"]}\n{e["text"]}' for e in facts['excerpts'])
        parts.append('# Source excerpts (line-numbered; the only code you may quote)\n'
                     + excerpts + (f'\n\nNot shown (over budget): {", ".join(facts["notShown"])}'
                                   if facts['notShown'] else '')
                     + outlines_text(facts))
    else:
        parts.append(f'# Repository\nNot available: {facts.get("status")}')
    return '\n\n'.join(parts)


def main(sid):
    sources = load_stage(sid, 'sources')
    facts = load_stage(sid, 'repo_facts')
    extract = load_stage(sid, 'extract')
    placements, phrases = field_context(sid)
    print(f'· generating {sid}')
    context = '\n\n'.join([
        facts_text(sources, facts, extract),
        '# Other reviewed submissions in this field (for placement only)\n' + placements,
        '# Tone and length examples\nPhrases from reviews of OTHER submissions, '
        'with different structures. Match their plainness and length; do not '
        'reuse their shapes or wording.\n' + phrases,
        'Write the deep review for this submission.',
    ])
    content = [{'type': 'text', 'text': context}]
    if route('generate')['provider'] == 'claude-cli':
        draft, history = draft_in_session(sid, content, sources, facts, extract)
    else:
        draft, history = draft_by_resending(sid, content, sources, facts, extract)
    write_json(stage_path(sid, 'draft'), {'draft': draft, 'repairs': history})
    remaining = history[-1]['problems']
    print(f'  draft ready; {len(remaining)} problems left for grounding')


REPAIR = ('Return the complete corrected review. Change only what these '
          'problems require; if a citation cannot be made verbatim, cite '
          'something that can or weaken the status.')


def repair_loop(sid, draft, sources, facts, extract, repair):
    """Checks the draft and asks for corrections at most MAX_REPAIRS times.

    [repair](attempt, draft, problems) returns the corrected draft."""
    history = []
    for attempt in range(MAX_REPAIRS):
        # Structure and citations first; only a well-formed draft is sent to
        # the independent verifier, whose objections come back the same way.
        problems = ground.check(draft, sources, facts, extract)
        if not problems:
            problems = ground.verification_problems(sid, draft, sources, facts, extract)
        history.append({'attempt': attempt, 'problems': problems})
        if not problems:
            break
        print(f'  {len(problems)} problems; asking for a corrected draft')
        for p in problems:
            print(f'    - {p}')
        draft = repair(attempt, draft, problems)
    else:
        history.append({'attempt': MAX_REPAIRS,
                        'problems': ground.check(draft, sources, facts, extract)})
    return draft, history


def draft_in_session(sid, content, sources, facts, extract):
    """Claude: the context is sent once; repairs are later turns of the
    same conversation, so the context is read from the prompt cache."""
    def repair(attempt, draft, problems):
        return session.ask(f'repair{attempt + 1}', [{'type': 'text', 'text':
            'Your previous draft has these problems:\n' +
            '\n'.join(f'- {p}' for p in problems) + '\n\n' + REPAIR}])

    for fresh in (False, True):
        session = ClaudeSession(sid, 'generate', SYSTEM, SCHEMA, content, fresh=fresh)
        try:
            draft = session.ask('generate', content)
            return repair_loop(sid, draft, sources, facts, extract, repair)
        except SessionDiverged:
            print('  recorded session diverges; starting a fresh one')
        finally:
            session.close()
    raise RuntimeError('a fresh session cannot diverge')


def draft_by_resending(sid, content, sources, facts, extract):
    """Stateless providers: each repair re-sends the context and the draft."""
    def repair(attempt, draft, problems):
        return ask(sid, f'repair{attempt + 1}', 'generate', SYSTEM, content + [
            {'type': 'text', 'text':
             'Your previous draft:\n' + json.dumps(draft, ensure_ascii=False) +
             '\n\nIt has these problems:\n' + '\n'.join(f'- {p}' for p in problems) +
             '\n\n' + REPAIR}], SCHEMA)

    draft = ask(sid, 'generate', 'generate', SYSTEM, content, SCHEMA)
    return repair_loop(sid, draft, sources, facts, extract, repair)


if __name__ == '__main__':
    main(sys.argv[1])
