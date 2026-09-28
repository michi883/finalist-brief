"""What the generator is told about links and demos it cannot see.

    cd tool/deep_review && python3 -m unittest discover tests
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import extract  # noqa: E402
import generate  # noqa: E402


class Sources(unittest.TestCase):
    def test_live_links_carry_the_link_check(self):
        sources = {'live': ['https://a.example/app', 'https://b.example'],
                   'liveChecks': [{'url': 'https://a.example/app', 'http': 404,
                                   'status': 'unreachable'}]}
        self.assertEqual(generate.links_text(sources).splitlines()[1:], [
            "- https://a.example/app: type unknown (Devpost 'Try it out' link); "
            'unreachable, HTTP 404 when checked',
            "- https://b.example: type unknown (Devpost 'Try it out' link); not checked"])
        self.assertEqual(generate.links_text({'live': []}), 'Links: none')

    def test_a_private_demo_is_not_called_a_download_failure(self):
        self.assertIn('private', extract.DEMO_ABSENT['private'])
        self.assertNotIn('download', extract.DEMO_ABSENT['private'])


if __name__ == '__main__':
    unittest.main()
