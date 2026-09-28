"""App → endpoint call detection shared by triage and deep review.

    cd tool/deep_review && python3 -m unittest discover tests
"""

import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from common import pilot_signals  # noqa: E402

signals = pilot_signals()

METHODS = {'summary': {'listSummaries', 'getSummaryDetails'},
           'onboarding': {'confirmWhitelist'}, 'user': {'login', 'updateUser'},
           'briefing': {'generateBriefing'}}


class EndpointCalls(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)
        self.write('app/pubspec.yaml', 'name: demo_app\ndependencies:\n  flutter:\n    sdk: flutter\n')

    def write(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            f.write(text)

    def calls(self):
        return sorted({(a, m, at) for a, m, at, _ in
                       signals.endpoint_calls(self.root, ['app'], METHODS)})

    def test_direct_calls_including_line_breaks(self):
        self.write('app/lib/main.dart', '''
void main() async {
  await client.summary.listSummaries(1);
  final r = await client.user
      .updateUser(userId: 1);
}''')
        self.assertEqual(self.calls(), [
            ('summary', 'listSummaries', 'app/lib/main.dart'),
            ('user', 'updateUser', 'app/lib/main.dart')])

    def test_typed_provider_and_derived_holders(self):
        # The hushflow shape: typed providers in one file, used elsewhere.
        self.write('app/lib/main.dart', "import 'providers.dart';\nimport 'screen.dart';\nvoid main() {}")
        self.write('app/lib/providers.dart', '''
final summaryEndpointProvider = Provider<EndpointSummary>((ref) {
  final client = ref.watch(clientProvider);
  return client.summary;
});
final onboardingEndpointProvider = Provider<EndpointOnboarding>((ref) => ref.watch(clientProvider).onboarding);
''')
        self.write('app/lib/screen.dart', '''
Future<void> load(WidgetRef ref) async {
  final s = await ref.read(summaryEndpointProvider).listSummaries(1);
  final onboarding = ref.read(onboardingEndpointProvider);
  await onboarding.confirmWhitelist(ids);
}''')
        self.assertEqual(self.calls(), [
            ('onboarding', 'confirmWhitelist', 'app/lib/screen.dart'),
            ('summary', 'listSummaries', 'app/lib/screen.dart')])

    def test_one_local_name_bound_to_different_endpoints(self):
        # The btlr shape: every provider file reads its own endpoint into a
        # local called `endpoint`; each call belongs to the nearest binding.
        self.write('app/lib/main.dart', "import 'providers.dart';\nimport 'a.dart';\nimport 'b.dart';\nvoid main() {}")
        self.write('app/lib/providers.dart', '''
final summaryEndpointProvider = Provider<EndpointSummary>((ref) => ref.watch(clientProvider).summary);
final userEndpointProvider = Provider<EndpointUser>((ref) => ref.watch(clientProvider).user);
final onboardingEndpointProvider = Provider<EndpointOnboarding>((ref) => ref.watch(clientProvider).onboarding);
''')
        self.write('app/lib/a.dart', '''
Future<void> load() async {
  final endpoint = ref.read(summaryEndpointProvider);
  await endpoint.listSummaries(1);
}''')
        self.write('app/lib/b.dart', '''
Future<void> signIn() async {
  final endpoint = ref.read(userEndpointProvider);
  await endpoint.login(email);
}
Future<void> confirm() async {
  final endpoint = ref.read(onboardingEndpointProvider);
  await endpoint.confirmWhitelist();
  await endpoint.login(email);
}''')
        self.assertEqual(self.calls(), [
            ('onboarding', 'confirmWhitelist', 'app/lib/b.dart'),
            ('summary', 'listSummaries', 'app/lib/a.dart'),
            ('user', 'login', 'app/lib/b.dart')])

    def test_variable_assigned_from_client(self):
        self.write('app/lib/main.dart', '''
void main() async {
  final users = client.user;
  await users.login(email, password);
}''')
        self.assertEqual(self.calls(), [('user', 'login', 'app/lib/main.dart')])

    def test_same_named_method_on_another_class_is_not_a_call(self):
        self.write('app/lib/main.dart', '''
void main() async {
  await DemoService().listSummaries(1);
  ref.read(userProvider.notifier).updateUser(u);
  final notes = client.notes;
  await notes.generateBriefing();
}''')
        self.assertEqual(self.calls(), [])

    def test_calls_in_files_the_app_never_imports_do_not_count(self):
        self.write('app/lib/main.dart', "import 'live.dart';\nvoid main() {}")
        self.write('app/lib/live.dart', 'f() => client.summary.listSummaries(1);')
        self.write('app/lib/dead.dart', 'g() => client.briefing.generateBriefing();')
        self.assertEqual(self.calls(), [('summary', 'listSummaries', 'app/lib/live.dart')])

    def test_relative_imports_stop_at_the_lib_root(self):
        # The butlrapp shape: lib/screens imports '../../widgets/x.dart',
        # which Dart resolves to lib/widgets/x.dart (checked with dart run).
        self.write('app/lib/main.dart', "import 'screens/chat.dart';\nvoid main() {}")
        self.write('app/lib/screens/chat.dart', "import '../../widgets/drawer.dart';")
        self.write('app/lib/widgets/drawer.dart', 'f() => client.summary.listSummaries(1);')
        self.assertEqual(self.calls(), [('summary', 'listSummaries', 'app/lib/widgets/drawer.dart')])
        self.assertIn('app/lib/widgets/drawer.dart', signals.runnable_dart(self.root, ['app']))

    def test_local_packages_count_only_when_the_app_imports_them(self):
        # The scriptly shape: a wrapper package the app never imports, and a
        # shared package it does import.
        self.write('app/lib/main.dart', "import 'package:shared/api.dart';\nvoid main() {}")
        self.write('shared/pubspec.yaml', 'name: shared\ndependencies:\n  flutter:\n    sdk: flutter\n')
        self.write('shared/lib/api.dart', 'f() => client.summary.listSummaries(1);')
        self.write('wrapper/pubspec.yaml', 'name: wrapper\ndependencies:\n  flutter:\n    sdk: flutter\n')
        self.write('wrapper/lib/wrapper.dart', 'g() => client.user.login(a, b);')
        calls = signals.endpoint_calls(self.root, ['app', 'shared', 'wrapper'], METHODS)
        self.assertEqual([(a, m, at) for a, m, at, _ in calls],
                         [('summary', 'listSummaries', 'shared/lib/api.dart')])

    def test_wrapper_methods_count_only_when_the_app_calls_them(self):
        # The scriptly shape: the app imports a wrapper package, but only a
        # file nothing imports calls the wrapper's methods.
        self.write('app/lib/main.dart', "import 'package:wrap/wrap.dart';\nvoid main() { Wrap.initialize(); }")
        self.write('app/lib/dead.dart', "import 'package:wrap/wrap.dart';\nf() => Wrap.login();")
        self.write('wrap/pubspec.yaml', 'name: wrap\ndependencies:\n  flutter:\n    sdk: flutter\n')
        self.write('wrap/lib/wrap.dart', '''class Wrap {
  static void initialize() {}
  static Future<void> login() async {
    return await client.user.login(a, b);
  }
  static Future<void> list() async {
    return await client.summary.listSummaries(1);
  }
}''')
        self.assertEqual(signals.endpoint_calls(self.root, ['app', 'wrap'], METHODS), [])
        self.write('app/lib/main.dart',
                   "import 'package:wrap/wrap.dart';\nvoid main() { Wrap.initialize(); Wrap.list(); }")
        self.assertEqual([(a, m) for a, m, _, _ in signals.endpoint_calls(self.root, ['app', 'wrap'], METHODS)],
                         [('summary', 'listSummaries')])

    def test_nested_packages_are_not_walked_twice(self):
        self.write('pubspec.yaml', 'name: rootapp\ndependencies:\n  flutter:\n    sdk: flutter\n')
        self.write('lib/main.dart', 'void main() => client.summary.listSummaries(1);')
        self.write('server/pubspec.yaml', 'name: server\ndependencies:\n  serverpod: ^2.0.0\n')
        self.write('server/test/x.dart', 'f() => client.user.login(a, b);')
        calls = signals.endpoint_calls(self.root, ['.'], METHODS)
        self.assertEqual([(a, m, at) for a, m, at, _ in calls], [('summary', 'listSummaries', 'lib/main.dart')])

    def test_package_at_repository_root(self):
        # A Flutter package at the root is recorded as '.'.
        root = self.root
        self.write('pubspec.yaml', 'name: rootapp\ndependencies:\n  flutter:\n    sdk: flutter\n')
        self.write('lib/main.dart', "import 'package:rootapp/api.dart';\nvoid main() {}")
        self.write('lib/api.dart', 'f() => client.summary.getSummaryDetails(1);')
        calls = signals.endpoint_calls(root, ['.'], METHODS)
        self.assertEqual([(a, m, at) for a, m, at, _ in calls],
                         [('summary', 'getSummaryDetails', 'lib/api.dart')])
        self.assertEqual(signals.reachable_dart(root, '.'), {'lib/main.dart', 'lib/api.dart'})


if __name__ == '__main__':
    unittest.main()
