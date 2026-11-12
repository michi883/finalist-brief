import 'dart:convert';

import 'package:finalist_brief_shared/finalist_brief_shared.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

http.Response _json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _submission = {
  'id': 1,
  'slug': 'crowdwork-copilot',
  'title': 'Crowdwork Copilot',
  'creator': 'Cary Chan',
  'summary': 'A summary.',
  'gemmaUse': 'Few-shot prompting.',
  'kaggleUrl': 'https://example.test/k',
  'repoUrl': null,
  'demoUrl': null,
  'hasDemoVideo': false,
  'coverAsset': 'crowdwork-copilot.jpg',
  'sortOrder': 1,
};

const _brief = {
  'id': 'abc',
  'status': 'analyzing',
  'mode': 'replay',
  'progressPercent': 10,
  'progressMessage': 'Analyzing',
  'stageLog': <String>[],
  'submissionCount': 7,
  'segments': null,
  'videoUrl': null,
  'videoDurationSec': null,
  'createdAt': '2026-11-11T12:00:00.000Z',
  'completedAt': null,
};

void main() {
  FinalistBriefApi apiWith(
    http.Response Function(http.Request request) handler,
  ) => FinalistBriefApi(
    'https://api.test',
    client: MockClient((request) async => handler(request)),
  );

  test('lists submissions from /api/submissions', () async {
    late Uri requested;
    final api = apiWith((request) {
      requested = request.url;
      return _json([_submission]);
    });

    final submissions = await api.listSubmissions();

    expect(requested.toString(), 'https://api.test/api/submissions');
    expect(submissions.single.slug, 'crowdwork-copilot');
    expect(submissions.single.id, 1);
  });

  test('posts the mode when generating a brief', () async {
    late http.Request sent;
    final api = apiWith((request) {
      sent = request;
      return _json(_brief);
    });

    final brief = await api.generateBrief(BriefMode.replay);

    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/briefs');
    expect(jsonDecode(sent.body), {'mode': 'replay'});
    expect(brief.id, 'abc');
    expect(brief.status, BriefStatus.analyzing);
  });

  test('an unavailable mode becomes BriefUnavailableException', () async {
    final api = apiWith((_) => _json({'error': 'Not built yet'}, 422));

    await expectLater(
      api.generateBrief(BriefMode.live),
      throwsA(
        isA<BriefUnavailableException>().having(
          (e) => e.message,
          'message',
          'Not built yet',
        ),
      ),
    );
  });

  test('a missing brief is null, other failures throw', () async {
    final missing = apiWith((_) => _json({'error': 'Not found'}, 404));
    expect(await missing.getBrief('nope'), isNull);
    expect(await missing.latestCompleteBrief(), isNull);

    final broken = apiWith((_) => _json({'error': 'Internal error'}, 500));
    await expectLater(
      broken.listAnalyses(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.message, 'message', 'Internal error'),
      ),
    );
  });

  test('a trailing slash on the base URL does not matter', () async {
    late Uri requested;
    final api = FinalistBriefApi(
      'https://api.test/',
      client: MockClient((request) async {
        requested = request.url;
        return _json(_brief);
      }),
    );

    await api.getBrief('a b');

    expect(requested.toString(), 'https://api.test/api/briefs/a%20b');
  });
}
