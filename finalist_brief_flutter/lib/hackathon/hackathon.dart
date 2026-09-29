import 'package:flutter/services.dart';

import '../representation/project.dart';
import '../triage/lanes.dart';
import '../triage/triage.dart';

/// Where one hackathon's bundled data lives. Each hackathon reads only its own
/// assets, so switching never mixes submissions, evidence or questions.
class HackathonSource {
  const HackathonSource({
    required this.id,
    required this.name,
    required this.representations,
    this.triage,
    this.writeups,
  });
  final String id;
  final String name;

  /// Deep-review representations: the Competition and Submission views.
  final String representations;

  /// Optional triage table data, and the writeup lines it loads on demand.
  final String? triage;
  final String? writeups;
}

const hackathonSources = [
  HackathonSource(
    id: 'serverpod',
    name: 'Serverpod',
    representations: 'assets/representations/serverpod.json',
    triage: 'assets/triage/serverpod.json',
    writeups: 'assets/triage/serverpod_writeups.json',
  ),
  HackathonSource(
    id: 'humor-genome',
    name: 'Humor Genome',
    representations: 'assets/representations/humor_genome.json',
  ),
];

/// A loaded hackathon: its competition (sponsor technology, deep-review
/// projects and the shared competition modes) and, when the field is too
/// large to compare at once, a triage dataset with lanes derived by rule.
class Hackathon {
  Hackathon({
    required this.source,
    required this.competition,
    this.triage,
    Map<String, TriageAssessment>? assessments,
    AssetBundle? bundle,
  }) : assessments =
           assessments ??
           (triage == null ? const {} : Map.unmodifiable(assessField(triage))),
       _bundle = bundle ?? rootBundle {
    final triage = this.triage;
    if (triage == null) return;
    for (final p in competition.projects) {
      if (triage.byId(p.id) == null) {
        throw FormatException('${p.id} has a representation but no triage row');
      }
    }
  }

  final HackathonSource source;
  final Competition competition;
  final TriageDataset? triage;
  final Map<String, TriageAssessment> assessments;
  final AssetBundle _bundle;
  Future<Map<String, List<WriteupLine>>>? _writeups;
  final _lines = <String, Future<List<WriteupLine>>>{};
  final _loadedLines = <String, List<WriteupLine>>{};

  String get id => source.id;
  String get name => source.name;
  String get sponsorTech => competition.sponsorTech;

  bool hasRepresentation(String id) =>
      competition.projects.any((p) => p.id == id);

  /// Numbered writeup lines, loaded the first time a submission is opened.
  /// The same future is returned on every call, so rebuilds never reload.
  Future<List<WriteupLine>> writeup(String id) => _lines.putIfAbsent(id, () {
    final path = source.writeups;
    if (path == null) return Future.value(const []);
    _writeups ??= _bundle.loadString(path).then(parseWriteups);
    return _writeups!.then(
      (all) => _loadedLines[id] = all[id] ?? const [],
    );
  });

  /// Lines already loaded for [id], so a reopened panel renders at once.
  List<WriteupLine>? loadedWriteup(String id) => _loadedLines[id];
}

Future<Hackathon> loadHackathon(
  HackathonSource source, {
  AssetBundle? bundle,
}) async {
  final assets = bundle ?? rootBundle;
  final competition = parseCompetition(
    await assets.loadString(source.representations),
  );
  final triagePath = source.triage;
  return Hackathon(
    source: source,
    competition: competition,
    triage: triagePath == null
        ? null
        : parseTriage(await assets.loadString(triagePath)),
    bundle: assets,
  );
}
