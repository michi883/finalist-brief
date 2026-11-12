import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finalist_brief_api/finalist_brief_api.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Configuration comes from environment variables:
///
/// - `PORT` (default 8080; set by Cloud Run)
/// - `GOOGLE_CLOUD_PROJECT`: use Firestore in this project. Without it (and
///   without `STORE=firestore`) the API keeps its data in memory.
/// - `ASSETS_DIR` (default `assets`)
/// - `PUBLIC_WEB_ORIGIN`: where the web app is hosted
/// - `ALLOWED_ORIGINS`: comma-separated origins allowed by CORS
Future<void> main() async {
  final env = Platform.environment;
  final port = int.parse(env['PORT'] ?? '8080');
  final fixture = Fixture.load(env['ASSETS_DIR'] ?? 'assets');

  final projectId = env['GOOGLE_CLOUD_PROJECT'];
  final Store store;
  if (projectId != null && projectId.isNotEmpty) {
    store = FirestoreStore.connect(projectId);
    _log('INFO', 'Using Firestore in project $projectId');
  } else {
    store = MemoryStore();
    _log(
      'WARNING',
      'GOOGLE_CLOUD_PROJECT is not set; using an in-memory store',
    );
  }

  final seeded = await ensureSeeded(store, fixture);
  _log('INFO', seeded ? 'Seeded the fixture' : 'Fixture already seeded');

  final allowed = env['ALLOWED_ORIGINS'];
  final handler = buildHandler(
    store: store,
    fixture: fixture,
    webOrigin: env['PUBLIC_WEB_ORIGIN'] ?? 'https://finalists.sound.fan',
    allowedOrigins: allowed == null || allowed.trim().isEmpty
        ? defaultAllowedOrigins
        : [for (final o in allowed.split(',')) o.trim()],
    onError: (severity, error, stack) => _log(severity, '$error', stack: stack),
  );

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  _log('INFO', 'Listening on port ${server.port}');

  // Cloud Run sends SIGTERM before stopping an instance.
  ProcessSignal.sigterm.watch().listen((_) async {
    await server.close();
    exit(0);
  });
}

/// One JSON line per entry, which Cloud Logging parses into a log record.
void _log(String severity, String message, {StackTrace? stack}) {
  stdout.writeln(
    jsonEncode({
      'severity': severity,
      'message': stack == null ? message : '$message\n$stack',
    }),
  );
}
