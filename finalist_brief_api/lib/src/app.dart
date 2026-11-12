import 'dart:convert';

import 'package:finalist_brief_shared/finalist_brief_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'fixture.dart';
import 'replay.dart';
import 'store.dart';

/// Origins allowed to call the API from a browser (besides localhost).
const defaultAllowedOrigins = [
  'https://finalists.sound.fan',
  'https://finalists-sound-fan.web.app',
  'https://finalists-sound-fan.firebaseapp.com',
];

/// The Finalist Brief API, as a shelf [Handler].
///
/// [webOrigin] is where the Flutter web app (and the briefing video under
/// `/briefs/`) is hosted. [now] is injectable for tests.
Handler buildHandler({
  required Store store,
  required Fixture fixture,
  String webOrigin = 'https://finalists.sound.fan',
  List<String> allowedOrigins = defaultAllowedOrigins,
  DateTime Function()? now,
  void Function(String severity, Object error, StackTrace stack)? onError,
}) {
  final api = _Api(store, fixture, webOrigin, now ?? DateTime.now);
  final router = Router()
    ..get('/', (Request _) => _json({'service': 'finalist-brief-api'}))
    ..get('/healthz', (Request _) => Response.ok('ok'))
    ..get('/api/submissions', api.submissions)
    ..get('/api/analyses', api.analyses)
    ..post('/api/briefs', api.createBrief)
    // Registered before `<id>`, which would otherwise match it.
    ..get('/api/briefs/latest-complete', api.latestComplete)
    ..get('/api/briefs/<id>', api.getBrief)
    ..all('/<ignored|.*>', (Request _) => _json({'error': 'Not found'}, 404));

  return const Pipeline()
      .addMiddleware(_errors(onError))
      .addMiddleware(_cors(allowedOrigins))
      .addHandler(router.call);
}

class _Api {
  _Api(this._store, this._fixture, this._webOrigin, this._now);

  final Store _store;
  final Fixture _fixture;
  final String _webOrigin;
  final DateTime Function() _now;

  static const _ttl = Duration(minutes: 5);
  static const _maxBody = 4096;

  // The dataset is fixed, so reads are cached to spare Firestore.
  _Cached<List<Submission>>? _submissionCache;
  _Cached<List<SubmissionAnalysis>>? _analysisCache;

  Future<List<Submission>> _submissions() async {
    final cached = _submissionCache;
    if (cached != null && cached.fresh(_now(), _ttl)) return cached.value;
    final value = await _store.listSubmissions();
    _submissionCache = _Cached(value, _now());
    return value;
  }

  Future<Response> submissions(Request request) async => _cacheable([
    for (final s in await _submissions()) s.toJson(),
  ], 'public, max-age=300');

  Future<Response> analyses(Request request) async {
    var cached = _analysisCache;
    if (cached == null || !cached.fresh(_now(), _ttl)) {
      cached = _Cached(await _store.listAnalyses(goldenPromptVersion), _now());
      _analysisCache = cached;
    }
    return _cacheable([
      for (final a in cached.value) a.toJson(),
    ], 'public, max-age=300');
  }

  Future<Response> createBrief(Request request) async {
    if ((request.contentLength ?? 0) > _maxBody) {
      return _json({'error': 'Request too large'}, 413);
    }
    final Object? body;
    try {
      final text = await request.readAsString();
      body = text.isEmpty ? const <String, dynamic>{} : jsonDecode(text);
    } on FormatException {
      return _json({'error': 'Body must be JSON'}, 400);
    }
    final modeName = body is Map ? body['mode'] : null;
    final mode = BriefMode.values.asNameMap()[modeName];
    if (mode == null) {
      return _json({'error': 'mode must be "replay" or "live"'}, 400);
    }
    if (mode == BriefMode.live) {
      return _json({
        'error':
            'Live analysis is not built yet. Open the app with ?demo=1 to '
            'run the cached demo.',
      }, 422);
    }
    final replay = await _replay();
    final stored = await _store.insertBrief(replay.start(_now()));
    return _cacheable(replay.view(stored, _now()).toJson(), 'no-store');
  }

  Future<Response> getBrief(Request request, String id) async {
    // Ids are Firestore auto ids; anything else cannot exist.
    final stored = _validId.hasMatch(id) ? await _store.findBrief(id) : null;
    if (stored == null) return _json({'error': 'Not found'}, 404);
    final replay = await _replay();
    return _cacheable(replay.view(stored, _now()).toJson(), 'no-store');
  }

  Future<Response> latestComplete(Request request) async {
    final replay = await _replay();
    final now = _now();
    for (final brief in await _store.newestBriefs(25)) {
      if (replay.isComplete(brief, now)) {
        return _cacheable(replay.view(brief, now).toJson(), 'no-store');
      }
    }
    return _json({'error': 'No completed briefing yet'}, 404);
  }

  Future<Replay> _replay() async => Replay(
    fixture: _fixture,
    submissions: await _submissions(),
    webOrigin: _webOrigin,
  );
}

class _Cached<T> {
  _Cached(this.value, this.at);

  final T value;
  final DateTime at;

  bool fresh(DateTime now, Duration ttl) => now.difference(at) < ttl;
}

final _validId = RegExp(r'^[A-Za-z0-9]{1,40}$');

Response _json(Object? body, [int status = 200]) => _respond(body, status);

/// A 200 response with a `Cache-Control` header.
Response _cacheable(Object? body, String cacheControl) =>
    _respond(body, 200, cacheControl);

Response _respond(Object? body, int status, [String? cacheControl]) => Response(
  status,
  body: jsonEncode(body),
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': ?cacheControl,
  },
);

final _localhost = RegExp(r'^https?://(localhost|127\.0\.0\.1)(:\d+)?$');

Middleware _cors(List<String> allowed) =>
    (inner) => (request) async {
      final origin = request.headers['origin'];
      final permitted =
          origin != null &&
          (allowed.contains(origin) || _localhost.hasMatch(origin));
      final headers = <String, String>{
        'vary': 'Origin',
        if (permitted) 'access-control-allow-origin': origin,
      };
      if (request.method == 'OPTIONS') {
        return Response(
          204,
          headers: {
            ...headers,
            if (permitted) ...{
              'access-control-allow-methods': 'GET, POST, OPTIONS',
              'access-control-allow-headers': 'content-type',
              'access-control-max-age': '86400',
            },
          },
        );
      }
      final response = await inner(request);
      return response.change(headers: headers);
    };

/// Turns uncaught errors into a JSON 500 and reports them.
Middleware _errors(
  void Function(String severity, Object error, StackTrace stack)? onError,
) =>
    (inner) => (request) async {
      try {
        return await inner(request);
      } on HijackException {
        rethrow;
      } catch (error, stack) {
        onError?.call('ERROR', error, stack);
        return _json({'error': 'Internal error'}, 500);
      }
    };
