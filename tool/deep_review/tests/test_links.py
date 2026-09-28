"""Links are typed only where a source establishes the type."""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import generate  # noqa: E402

DRIVE = 'https://drive.google.com/file/d/abc/view?usp=drive_link'


class LinkTypes(unittest.TestCase):
    def test_try_it_out_links_are_unknown_whatever_the_url(self):
        sources = {'live': [DRIVE, 'https://x.serverpod.space/app/',
                            'https://example.com/demo.mp4'],
                   'liveChecks': [{'url': DRIVE, 'http': 401, 'status': 'unreachable'}],
                   'demo': {'status': 'notLinked'}}
        links = generate.link_facts(sources)
        self.assertEqual([l['type'] for l in links], ['unknown'] * 3)
        text = generate.links_text(sources)
        self.assertIn(f'{DRIVE}: type unknown', text)
        self.assertIn('unreachable, HTTP 401 when checked', text)
        self.assertIn('never call it a video', text)
        for line in text.splitlines()[1:]:
            self.assertNotIn(': video', line)

    def test_demo_field_is_a_confirmed_video(self):
        sources = {'live': [], 'demo': {'status': 'private',
                                        'url': 'https://www.youtube.com/watch?v=x'}}
        [link] = generate.link_facts(sources)
        self.assertEqual((link['type'], link['status']), ('video', 'private'))
        self.assertIn("video (Devpost's demo video field); private",
                      generate.links_text(sources))

    def test_no_links(self):
        self.assertEqual(generate.links_text({'live': [], 'demo': {}}), 'Links: none')


if __name__ == '__main__':
    unittest.main()
