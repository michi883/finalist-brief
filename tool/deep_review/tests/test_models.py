"""Model files are found under every extension Serverpod reads.

    cd tool/deep_review && python3 -m unittest discover tests
"""

import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import repo_facts  # noqa: E402
from common import pilot_signals  # noqa: E402

signals = pilot_signals()

MODEL = 'class: TasteEntry\ntable: taste_entry\nfields:\n  title: String\n'


class ModelFiles(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)
        # The serverpod_cli list: .spy, .spy.yaml and .spy.yml.
        for rel in ('lib/src/models/taste_entry.spy', 'lib/src/a/b.spy.yaml',
                    'lib/src/c.spy.yml'):
            path = os.path.join(self.root, 'server', rel)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w') as f:
                f.write(MODEL)

    def test_repo_facts_lists_every_extension(self):
        found = repo_facts.models(self.root, 'server')
        self.assertEqual(sorted(m['at'] for m in found), [
            'server/lib/src/a/b.spy.yaml', 'server/lib/src/c.spy.yml',
            'server/lib/src/models/taste_entry.spy'])
        self.assertTrue(all(m['table'] == 'taste_entry' for m in found))

    def test_triage_footprint_counts_every_extension(self):
        result = signals.footprint(['server'], [], self.root)
        self.assertEqual((result['models'], result['tables']), (3, 3))


if __name__ == '__main__':
    unittest.main()
