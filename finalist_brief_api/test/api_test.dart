import 'dart:convert';

import 'package:finalist_brief_api/finalist_brief_api.dart';
import 'package:finalist_brief_shared/finalist_brief_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  final fixture = Fixture.load('assets');
  var clock = DateTime.utc(2026, 11, 11, 12);

  late MemoryStore store;
  late Handler handler;

  setUp(() async {
    clock = DateTime.utc(2026, 11, 11, 12);
    store = MemoryStore();
    await ensureSeeded(store, fixture);
    handler = buildHandler(
      store: store,
      fixture: fixture,
      webOrigin: 'https://app.test',
      now: () => clock,
    );
  });

  Future<Response> send(
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const {},
  }) => Future.sync(
    () => handler(
      Request(
        method,
        Uri.parse('http://api.test$path'),
        body: body == null ? null : jsonEncode(body),
        headers: headers,
      ),
    ),
  );

  Future<Object?> json(Response response) async =>
      jsonDecode(await response.readAsString());

  group('fixture', () {
    test('assigns ids from sortOrder and links analyses and segments', () {
      expect(fixture.submissions.map((s) => s.id), [1, 2, 3, 4, 5, 6, 7]);
      expect(
        fixture.analyses.map((a) => a.submissionId),
        fixture.submissions.map((s) => s.id),
      );
      expect(fixture.segments, hasLength(3));
      expect(fixture.segments.map((s) => s.position), [1, 2, 3]);
      expect(fixture.segments.every((s) => s.submissionId > 0), isTrue);
    });

    test('seeds once per content version', () async {
      expect(await ensureSeeded(store, fixture), isFalse);
      expect(await store.seedVersion(), fixture.hash);
    });
  });

  group('reads', () {
    test('lists submissions in display order', () async {
      final response = await send('GET', '/api/submissions');
      expect(response.statusCode, 200);
      final list = (await json(response) as List).cast<Map<String, dynamic>>();
      expect(list.map((s) => s['id']), [1, 2, 3, 4, 5, 6, 7]);
      expect(list.first['slug'], 'crowdwork-copilot');
    });

    test('lists one golden analysis per submission', () async {
      final response = await send('GET', '/api/analyses');
      final list = (await json(response) as List).cast<Map<String, dynamic>>();
      expect(list, hasLength(7));
      expect(list.map((a) => a['submissionId']), [1, 2, 3, 4, 5, 6, 7]);
      expect(list.every((a) => a['promptVersion'] == 'golden'), isTrue);
      // Round-trips through the shared model.
      expect(
        () => list.map(SubmissionAnalysis.fromJson).toList(),
        returnsNormally,
      );
    });

    test('health, root and unknown paths', () async {
      expect((await send('GET', '/healthz')).statusCode, 200);
      expect((await send('GET', '/')).statusCode, 200);
      expect((await send('GET', '/nope')).statusCode, 404);
      expect((await send('POST', '/api/submissions')).statusCode, 404);
    });
  });

  group('briefs', () {
    Future<Brief> create() async {
      final response = await send(
        'POST',
        '/api/briefs',
        body: {'mode': 'replay'},
      );
      expect(response.statusCode, 200);
      return Brief.fromJson(await json(response) as Map<String, dynamic>);
    }

    Future<Brief?> fetch(String path) async {
      final response = await send('GET', path);
      if (response.statusCode == 404) return null;
      expect(response.statusCode, 200);
      return Brief.fromJson(await json(response) as Map<String, dynamic>);
    }

    test('a new replay brief starts in the first analyzing stage', () async {
      final brief = await create();
      expect(brief.id, isNotNull);
      expect(brief.mode, BriefMode.replay);
      expect(brief.status, BriefStatus.analyzing);
      expect(brief.progressPercent, 0);
      expect(brief.submissionCount, 7);
      expect(brief.segments, isNull);
    });

    test(
      'progress follows elapsed time and finishes with three segments',
      () async {
        final created = await create();

        clock = clock.add(const Duration(seconds: 5));
        final midway = (await fetch('/api/briefs/${created.id}'))!;
        expect(midway.status, BriefStatus.analyzing);
        expect(midway.progressPercent, inInclusiveRange(1, 99));
        expect(midway.stageLog, isNotEmpty);
        expect(midway.completedAt, isNull);

        clock = clock.add(const Duration(minutes: 5));
        final done = (await fetch('/api/briefs/${created.id}'))!;
        expect(done.status, BriefStatus.complete);
        expect(done.progressPercent, 100);
        expect(done.segments, hasLength(3));
        expect(done.segments!.every((s) => s.submissionId > 0), isTrue);
        expect(done.videoUrl, 'https://app.test/briefs/${fixture.videoFile}');
        expect(done.videoDurationSec, fixture.videoDurationSec);
        expect(done.completedAt, isNotNull);

        // Reading again gives the same result.
        final again = (await fetch('/api/briefs/${created.id}'))!;
        expect(again.toJson(), done.toJson());
      },
    );

    test('latest-complete is empty until a brief has finished', () async {
      expect(await fetch('/api/briefs/latest-complete'), isNull);

      final created = await create();
      clock = clock.add(const Duration(seconds: 3));
      expect(await fetch('/api/briefs/latest-complete'), isNull);

      clock = clock.add(const Duration(minutes: 5));
      final latest = await fetch('/api/briefs/latest-complete');
      expect(latest?.id, created.id);
      expect(latest?.status, BriefStatus.complete);
    });

    test('live mode is unavailable', () async {
      final response = await send(
        'POST',
        '/api/briefs',
        body: {'mode': 'live'},
      );
      expect(response.statusCode, 422);
      final body = await json(response) as Map<String, dynamic>;
      expect(body['error'], contains('not built yet'));
    });

    test('rejects a bad body and an unknown brief', () async {
      expect(
        (await send('POST', '/api/briefs', body: {'mode': 'x'})).statusCode,
        400,
      );
      expect((await send('POST', '/api/briefs')).statusCode, 400);
      expect((await send('GET', '/api/briefs/missing')).statusCode, 404);
    });
  });

  group('cors', () {
    test('allows the web app origin and localhost, not others', () async {
      for (final origin in [
        'https://finalists.sound.fan',
        'http://localhost:9998',
      ]) {
        final response = await send(
          'OPTIONS',
          '/api/briefs',
          headers: {'origin': origin},
        );
        expect(response.statusCode, 204);
        expect(response.headers['access-control-allow-origin'], origin);
        expect(
          response.headers['access-control-allow-methods'],
          contains('POST'),
        );
      }

      final other = await send(
        'GET',
        '/api/submissions',
        headers: {'origin': 'https://evil.example'},
      );
      expect(other.statusCode, 200);
      expect(other.headers.containsKey('access-control-allow-origin'), isFalse);
    });
  });
}
