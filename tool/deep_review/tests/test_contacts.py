"""Incidental personal contact details in judge-facing text.

    cd tool/deep_review && python3 -m unittest discover tests
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import redact  # noqa: E402


def masked(text, allowed=frozenset()):
    return redact.mask_contacts_text(text, set(allowed))[0]


class Contacts(unittest.TestCase):
    def test_phone_numbers_from_the_demo_are_replaced(self):
        self.assertEqual(masked('Who answered the demo call to +917013963980?'),
                         'Who answered the demo call to [phone number]?')
        self.assertEqual(masked('The callee, +1 (415) 555-0199, answered.'),
                         'The callee, [phone number], answered.')
        self.assertEqual(masked('Call 415-555-0199.'), 'Call [phone number].')

    def test_email_addresses_from_the_demo_are_replaced(self):
        self.assertEqual(masked("Add mssuchith2@gmail.com to every event"),
                         'Add [email address] to every event')

    def test_the_teams_own_and_placeholder_addresses_stay(self):
        allowed = redact.contacts_allowed(["email: 'promo@amazon.com',", 'Support: +1 800 555 0100'])
        self.assertEqual(masked('the mock list starts with promo@amazon.com', allowed),
                         'the mock list starts with promo@amazon.com')
        self.assertEqual(masked('it dials +1 800 555 0100', allowed), 'it dials +1 800 555 0100')
        self.assertEqual(masked('e.g. boss@company.com'), 'e.g. boss@company.com')

    def test_ids_times_and_counts_stay(self):
        for text in ['vimeo.com/1163953482', 'at 1159662331', '2026-01-30 16:00', '3 of 48 endpoints',
                     'score 0.5 on failure', 'order #4 for $162.95', 'L026 says']:
            self.assertEqual(masked(text), text)

    def test_counts_every_replacement(self):
        text, n = redact.mask_contacts_text('a@b.io called +447700900123 twice', set())
        self.assertEqual((text, n), ('[email address] called [phone number] twice', 2))

    def test_walks_only_judge_facing_fields(self):
        review = {'questions': [{'id': 'q4', 'question': 'Who took the call to +917013963980?',
                                 'refs': [{'source': 'video', 't': 86}]}]}
        log = redact.mask_contacts(review, set())
        self.assertEqual(review['questions'][0]['question'], 'Who took the call to [phone number]?')
        self.assertEqual(review['questions'][0]['refs'], [{'source': 'video', 't': 86}])
        self.assertEqual(log, [('review.questions.0.question', 1)])


if __name__ == '__main__':
    unittest.main()
