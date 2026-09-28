"""HTML-escaped source is surfaced, and a parser that cannot read an
endpoint file never reports "0 endpoints"."""

import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import generate  # noqa: E402
import repo_facts  # noqa: E402

ESCAPED = ('class ProjectEndpoint extends Endpoint {\n'
           '  Future&lt;List&lt;Project&gt;&gt; list(Session session) async {\n'
           '    return [];\n  }\n}\n')
CLEAN = ('class NoteEndpoint extends Endpoint {\n'
         "  // renders &lt;b&gt; in HTML\n"
         "  Future<String> show(Session session) async => '&amp; done';\n}\n")


class MalformedSource(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)

    def write(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            f.write(text)
        return {'at': rel, 'generated': False}

    def test_escaped_dart_is_flagged_and_entities_in_strings_are_not(self):
        files = [self.write('server/lib/src/endpoints/project_endpoint.dart', ESCAPED),
                 self.write('server/lib/src/endpoints/note_endpoint.dart', CLEAN),
                 self.write('server/lib/src/models/project.spy',
                            'class: Project\nfields:\n  scenes: List&lt;Scene&gt;?\n')]
        problems = repo_facts.source_problems(self.root, files)
        self.assertEqual([(p['at'], p['line'], p['kind']) for p in problems], [
            ('server/lib/src/endpoints/project_endpoint.dart', 2, 'htmlEscaped'),
            ('server/lib/src/models/project.spy', 3, 'htmlEscaped')])

    def test_parser_failure_is_not_zero_endpoints(self):
        files = [self.write('server/lib/src/endpoints/project_endpoint.dart', ESCAPED)]
        methods = repo_facts.endpoint_methods(self.root, 'server')
        self.assertEqual(methods, [])
        problems = repo_facts.source_problems(self.root, files)
        parsing = repo_facts.endpoint_parsing(self.root, 'server', methods, problems)
        self.assertEqual(parsing['status'], 'unreliable')
        self.assertEqual(parsing['files'][0]['reason'], 'htmlEscaped')
        facts = {'sourceProblems': problems, 'endpointParsing': parsing}
        text = generate.parsing_text(facts)
        self.assertIn('could NOT be parsed reliably', text)
        self.assertIn('Do not read it as "no endpoints"', text)

    def test_unparsed_signatures_without_entities_are_also_unreliable(self):
        self.write('server/lib/src/endpoints/odd_endpoint.dart',
                   'class OddEndpoint extends Endpoint {\n'
                   '  Future f(Session session) async {}\n}\n')
        methods = repo_facts.endpoint_methods(self.root, 'server')
        parsing = repo_facts.endpoint_parsing(self.root, 'server', methods, [])
        self.assertEqual([f['reason'] for f in parsing['files']], ['signaturesNotParsed'])

    def test_clean_endpoints_parse_as_ok(self):
        files = [self.write('server/lib/src/endpoints/note_endpoint.dart', CLEAN)]
        methods = repo_facts.endpoint_methods(self.root, 'server')
        self.assertEqual([m['method'] for m in methods], ['show'])
        parsing = repo_facts.endpoint_parsing(
            self.root, 'server', methods, repo_facts.source_problems(self.root, files))
        self.assertEqual(parsing, {'status': 'ok', 'files': []})
        self.assertEqual(generate.parsing_text({'endpointParsing': parsing}), 'none')


if __name__ == '__main__':
    unittest.main()
