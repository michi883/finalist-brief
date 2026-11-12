import 'package:finalist_brief_shared/finalist_brief_shared.dart';

import 'fixture.dart';

/// Where the API keeps its data. Firestore in production, memory in tests and
/// for local runs without Google Cloud credentials.
abstract interface class Store {
  /// All submissions in display order.
  Future<List<Submission>> listSubmissions();

  /// Analyses of one prompt version, ordered by `submissionId`.
  Future<List<SubmissionAnalysis>> listAnalyses(String promptVersion);

  /// Content hash of the fixture last written by [seed], if any.
  Future<String?> seedVersion();

  /// Writes the fixture's submissions and analyses and records its hash.
  Future<void> seed(Fixture fixture);

  /// Stores a new brief and returns it with its id.
  Future<Brief> insertBrief(Brief brief);

  Future<Brief?> findBrief(String id);

  /// The newest briefs first, at most [limit].
  Future<List<Brief>> newestBriefs(int limit);
}

/// Writes the fixture unless the store already holds this exact version.
Future<bool> ensureSeeded(Store store, Fixture fixture) async {
  if (await store.seedVersion() == fixture.hash) return false;
  await store.seed(fixture);
  return true;
}

/// A [Store] held in memory.
class MemoryStore implements Store {
  List<Submission> _submissions = [];
  List<SubmissionAnalysis> _analyses = [];
  String? _version;
  final _briefs = <String, Brief>{};
  var _nextBriefId = 1;

  @override
  Future<List<Submission>> listSubmissions() async => List.of(_submissions);

  @override
  Future<List<SubmissionAnalysis>> listAnalyses(String promptVersion) async => [
    for (final a in _analyses)
      if (a.promptVersion == promptVersion) a,
  ];

  @override
  Future<String?> seedVersion() async => _version;

  @override
  Future<void> seed(Fixture fixture) async {
    _submissions = List.of(fixture.submissions);
    _analyses = List.of(fixture.analyses);
    _version = fixture.hash;
  }

  @override
  Future<Brief> insertBrief(Brief brief) async {
    final stored = brief.withId('${_nextBriefId++}');
    _briefs[stored.id!] = stored;
    return stored;
  }

  @override
  Future<Brief?> findBrief(String id) async => _briefs[id];

  @override
  Future<List<Brief>> newestBriefs(int limit) async {
    final all = _briefs.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(limit).toList();
  }
}
