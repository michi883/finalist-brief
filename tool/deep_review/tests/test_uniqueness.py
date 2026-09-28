"""Uniqueness claims must be scoped to the reviewed entries the generator saw."""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import ground  # noqa: E402


def draft(note):
    return {'dimensions': {'ideaDistinctiveness': {'value': .5, 'note': note}}}


class Uniqueness(unittest.TestCase):
    def test_unscoped_only_claims_are_sent_back(self):
        for note in ['The only travel-planning entry; it chains familiar steps.',
                     'DOBY is the only other entry that builds agents.',
                     'The only entry that places real phone calls.',
                     'A sole voice-first planner.']:
            self.assertEqual(len(ground.uniqueness_problems(draft(note))), 1, note)

    def test_scoped_or_ordinary_uses_pass(self):
        for note in ['The only travel planner among reviewed entries.',
                     'Productivity is the most common area; it only adds a persona.',
                     'Only outline and script call OpenAI.']:
            self.assertEqual(ground.uniqueness_problems(draft(note)), [], note)


if __name__ == '__main__':
    unittest.main()
