"""A file that does not fit the excerpt budget is outlined, so it reads as
unseen, never as absent."""

import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import generate  # noqa: E402
import repo_facts  # noqa: E402

SOS = '''import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_app/models/user.dart';

class EmergencyService {
  Future<bool> _sendSMS(String phone, String message) async {
    final Uri uri = Uri(scheme: 'sms', path: phone);
    // https://example-docs.dev/sms is only a comment
    return launchUrl(uri);
  }
}
'''


class Outline(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)
        path = os.path.join(self.root, 'app/lib/services/emergency_service.dart')
        os.makedirs(os.path.dirname(path))
        with open(path, 'w') as f:
            f.write(SOS)

    def test_outline_names_packages_declarations_and_schemes(self):
        o = repo_facts.outline(self.root, 'app/lib/services/emergency_service.dart', {'my_app'})
        self.assertEqual(o['imports'], ['geolocator', 'url_launcher'])  # own package left out
        self.assertEqual(o['declares'], ['EmergencyService', '_sendSMS'])
        self.assertEqual(o['schemes'], ['sms'])

    def test_prompt_says_unseen_is_not_absent(self):
        o = repo_facts.outline(self.root, 'app/lib/services/emergency_service.dart', {'my_app'})
        text = generate.outlines_text({'notShownOutlines': [o]})
        self.assertIn('unseen, not absent', text)
        self.assertIn('emergency_service.dart: imports geolocator, url_launcher; '
                      'declares EmergencyService, _sendSMS; URI schemes sms', text)
        self.assertEqual(generate.outlines_text({'notShownOutlines': []}), '')
        self.assertEqual(generate.outlines_text({}), '')


if __name__ == '__main__':
    unittest.main()
