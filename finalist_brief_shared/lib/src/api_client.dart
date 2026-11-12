import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Thrown when the API answers with an unexpected status.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Client for the Finalist Brief API (see `finalist_brief_api`).
class FinalistBriefApi {
  FinalistBriefApi(String baseUrl, {http.Client? client})
    : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      _http = client ?? http.Client();

  final Uri _base;
  final http.Client _http;

  /// All submissions of the fixed dataset, in display order.
  Future<List<Submission>> listSubmissions() async {
    final json = await _getJson('api/submissions');
    return [
      for (final item in json as List)
        Submission.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// The cached analysis of every submission.
  Future<List<SubmissionAnalysis>> listAnalyses() async {
    final json = await _getJson('api/analyses');
    return [
      for (final item in json as List)
        SubmissionAnalysis.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Starts a briefing run. Poll [getBrief] for progress.
  Future<Brief> generateBrief(BriefMode mode) async {
    final response = await _http.post(
      _base.resolve('api/briefs'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'mode': mode.name}),
    );
    if (response.statusCode == 422) {
      throw BriefUnavailableException(message: _errorMessage(response));
    }
    return Brief.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// Current state of a briefing run, or null if it does not exist.
  Future<Brief?> getBrief(String id) =>
      _getBrief('api/briefs/${Uri.encodeComponent(id)}');

  /// The most recently completed briefing, if any.
  Future<Brief?> latestCompleteBrief() =>
      _getBrief('api/briefs/latest-complete');

  void close() => _http.close();

  Future<Brief?> _getBrief(String path) async {
    final response = await _http.get(_base.resolve(path));
    if (response.statusCode == 404) return null;
    return Brief.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<Object?> _getJson(String path) async =>
      _decode(await _http.get(_base.resolve(path)));

  Object? _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _errorMessage(response));
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map && body['error'] is String) {
        return body['error'] as String;
      }
    } catch (_) {}
    return response.reasonPhrase ?? 'HTTP ${response.statusCode}';
  }
}
