"""Serverpod runtime configuration is reported as configured, enabled and
used, kept apart.

    cd tool/deep_review && python3 -m unittest discover tests
"""

import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import generate  # noqa: E402
import repo_facts  # noqa: E402

DEVELOPMENT = '''apiServer:
  port: 8080

# This is the setup for Redis.
redis:
  enabled: false
  host: localhost
  port: 8091

sessionLogs:
  persistentEnabled: true
'''
COMPOSE = '''services:
  postgres:
    image: pgvector/pgvector:pg16
  redis:
    image: redis:6.2.6
    command: redis-server --requirepass "not-read"
'''


class ServerpodConfig(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)

    def write(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            f.write(text)

    def facts(self):
        return {'serverpodConfig': repo_facts.serverpod_config(self.root, 'server')}

    def test_redis_configured_but_disabled_and_unused(self):
        self.write('server/config/development.yaml', DEVELOPMENT)
        self.write('server/config/passwords.yaml', 'development:\n  redis: "secret"\n')
        self.write('server/config/passwords_production.yaml', 'redis:\n  password: "secret"\n')
        self.write('server/docker-compose.yaml', COMPOSE)
        self.write('server/lib/src/endpoints/a.dart',
                   'class A extends Endpoint {\n  Future<int> f(Session s) async => 1;\n}\n')
        config = self.facts()['serverpodConfig']
        self.assertEqual(list(config['modes']), ['development'])  # passwords.yaml never read
        self.assertEqual(config['modes']['development']['redis'],
                         {'enabled': False, 'why': 'enabled: false', 'line': 6})
        self.assertEqual(config['uses']['redis'], [])
        self.assertEqual([c['service'] for c in config['composeServices']],
                         ['postgres', 'redis'])
        text = generate.config_text(self.facts())
        self.assertIn('redis disabled (enabled: false, line 6)', text)
        self.assertIn('needs no extra dependency', text)
        self.assertIn('RedisController): none found', text)
        self.assertIn('supporting context only', text)
        self.assertNotIn('not-read', text)
        self.assertNotIn('secret', text)

    def test_redis_section_without_enabled_is_on_and_missing_section_is_off(self):
        self.assertTrue(repo_facts.redis_state(
            repo_facts.config_file('redis:\n  host: localhost\n'))['enabled'])
        self.assertEqual(repo_facts.redis_state(repo_facts.config_file('apiServer:\n  port: 1\n')),
                         {'enabled': False, 'why': 'no redis section'})

    def test_service_present_but_unused_is_not_use(self):
        self.write('docker-compose.yml', COMPOSE)
        self.write('server/lib/src/cache.dart',
                   "// session.caches.global is not used here\n"
                   "final note = 'caches.global';\n")
        config = self.facts()['serverpodConfig']
        self.assertEqual(config['modes'], {})
        self.assertEqual(len(config['composeServices']), 2)
        self.assertEqual(config['uses']['redis'], [])  # comments and strings are not code

    def test_code_that_needs_redis_is_reported_with_its_line(self):
        self.write('server/config/production.yaml', 'redis:\n  enabled: true\n')
        self.write('server/lib/src/endpoints/c.dart',
                   'class C extends Endpoint {\n'
                   '  Future<void> f(Session session) async {\n'
                   '    await session.caches.global.put("k", v);\n'
                   '    await session.caches.local.put("k", v);\n'
                   '  }\n}\n')
        config = self.facts()['serverpodConfig']
        self.assertTrue(config['modes']['production']['redis']['enabled'])
        self.assertEqual([(u['at'], u['line']) for u in config['uses']['redis']],
                         [('server/lib/src/endpoints/c.dart', 3)])
        self.assertEqual(len(config['uses']['localCache']), 1)


if __name__ == '__main__':
    unittest.main()
