"""A repository that cannot be read is stated as unseen, never as absent."""

import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import acquire  # noqa: E402
import generate  # noqa: E402


class UnavailableRepository(unittest.TestCase):
    def test_a_404_link_is_carried_over_not_cloned(self):
        with mock.patch.object(acquire, 'pilot_repo_check', return_value=('notFound', '2026-09-28')), \
                mock.patch.object(acquire, 'repository') as clone:
            repo = acquire.repo_source('x', 'https://github.com/a/b')
        clone.assert_not_called()
        self.assertEqual(repo, {'url': 'https://github.com/a/b', 'status': 'notFound',
                                'checked': '2026-09-28'})

    def test_no_link_needs_no_check(self):
        self.assertEqual(acquire.repo_source('x', None), {'status': 'notLinked'})

    def test_the_prompt_says_404_may_be_private_and_forbids_absence(self):
        text = generate.repo_unavailable_text(
            {'url': 'https://github.com/a/b', 'status': 'notFound', 'checked': '2026-09-28'})
        self.assertIn('HTTP 404', text)
        self.assertIn('private', text)
        self.assertIn('2026-09-28', text)
        self.assertIn('do not say that any code, feature or file is absent', text)
        self.assertIn('No repository is linked',
                      generate.repo_unavailable_text({'status': 'notLinked'}))


if __name__ == '__main__':
    unittest.main()
