"""Secret redaction in judge-facing text.

    cd tool/deep_review && python3 -m unittest discover tests
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import redact  # noqa: E402

MASK = redact.MASK


def redacted(text, known=frozenset()):
    return redact.redact_text(text, set(known))[0]


class FallbackSecrets(unittest.TestCase):
    SOURCE = '''  33|   static String _getEncryptionKey(Session session) {
  34|     try {
  35|       return session.passwords['oauthEncryptionKey'] ??
  36|           'default-dev-key-change-in-production';
  37|     } catch (_) {
  38|       return 'default-dev-key-change-in-production';
  39|     }
  40|   }'''

    def test_fallback_in_key_function_is_a_secret(self):
        self.assertEqual(redact.secrets_in([self.SOURCE]), {'default-dev-key-change-in-production'})

    def test_fallback_is_removed_from_quotes_and_prose(self):
        known = redact.secrets_in([self.SOURCE])
        self.assertEqual(redacted("default-dev-key-change-in-production';", known), f"{MASK}';")
        self.assertEqual(
            redacted("If oauthEncryptionKey is missing, it uses 'default-dev-key-change-in-production'.", known),
            f"If oauthEncryptionKey is missing, it uses '{MASK}'.")
        # The lookup name stays, so the finding still reads.
        self.assertIn('oauthEncryptionKey', redacted(self.SOURCE, known))

    def test_fallback_in_a_sensitive_statement(self):
        for line in ["final apiKey = env['API_KEY'] ?? 'k3y-Fallback-99';",
                     "final pwd = config.password ?? 'hunter2hunter';",
                     "const tokenSecret = process.env.TOKEN ?? 'abcdEF123456';"]:
            self.assertEqual(len(redact.fallback_literals(line)), 1, line)
            self.assertIn(MASK, redacted(line), line)

    def test_fallback_outside_sensitive_context_stays(self):
        for line in ["final theme = prefs.getString('theme') ?? 'light-mode';",
                     "String title() { return 'Welcome back'; }",
                     "final url = env['URL'] ?? 'https://example.org/api';"]:
            self.assertEqual(redacted(line), line, line)


class AssignmentSecrets(unittest.TestCase):
    def test_assignment_style_secrets(self):
        cases = {
            "static final _encryptionKey = Key.fromUtf8('GitRadar2026SecretKey32BytesABCD');":
                f"static final _encryptionKey = Key.fromUtf8('{MASK}');",
            "static final _iv = IV.fromUtf8('GitRadarIV16Byte');": f"static final _iv = IV.fromUtf8('{MASK}');",
            "password: 'hunter2hunter'": f"password: '{MASK}'",
            '"apiKey": "Zx81QpLm7700"': f'"apiKey": "{MASK}"',
        }
        for text, expected in cases.items():
            self.assertEqual(redacted(text), expected, text)

    def test_known_formats_anywhere(self):
        self.assertEqual(redacted('key AIzaSyBD1234567890abcdefghijklmnop here'), f'key {MASK} here')
        self.assertEqual(redacted('uses sk-proj-abcdefghijklmnop1234'), f'uses {MASK}')
        self.assertEqual(redacted('token ghp_abcdefghijklmnopqrstuvwxyz0123'), f'token {MASK}')


class NotSecrets(unittest.TestCase):
    def test_benign_lookup_names_stay(self):
        for line in ["static const String sessionToken = 'session_token';",
                     "static const themeKey = 'app_theme';",
                     "final isPrivate = repoData['private'] as bool;",
                     "final key = session.passwords['oauthEncryptionKey'];",
                     "static String tokenKey() { return 'auth_token_v1'; }"]:
            self.assertEqual(redacted(line), line, line)

    def test_placeholders_and_mocks_stay(self):
        for line in ["final pat = 'YOUR_GITHUB_PAT_HERE';",
                     "final apiKey = session.getPassword('weatherApiKey') ?? 'MOCK_API_KEY';",
                     "const password = 'changeme';"]:
            self.assertEqual(redacted(line), line, line)

    def test_paths_urls_messages_and_interpolation_stay(self):
        for line in ["apiKey = await rootBundle.loadString('assets/config/gemini_api_key.txt');",
                     "static const String productionUrl = 'https://gitradar.api.serverpod.space/';",
                     "headers: {'Authorization': 'Bearer $token'}",
                     "String passwordError() { return 'Password must be at least 8 characters.'; }",
                     "final senderPassword = cfg.pass ?? 'info@rootradar.com';",
                     "The AES key and IV are fixed strings in the source."]:
            self.assertEqual(redacted(line), line, line)


if __name__ == '__main__':
    unittest.main()
