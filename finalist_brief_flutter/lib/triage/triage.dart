import 'dart:convert';

/// Where a triage signal comes from. Deterministic signals and Jev-derived
/// signals are never merged into one value, so the UI can always say which is
/// which.
enum SignalSource {
  links('Links', 'HTTP status of the submitted links, checked by code.'),
  repo(
    'Repository',
    'Computed by code from the repository at the last commit before the deadline.',
  ),
  jev(
    'Jev',
    'Structured extraction from the writeup by Jev. Describes what the team says, not whether it is good.',
  );

  const SignalSource(this.label, this.meaning);
  final String label;
  final String meaning;
}

enum RepoAccess {
  public('Public'),
  notFound('Link returns 404'),
  notLinked('Not linked');

  const RepoAccess(this.label);
  final String label;
}

enum DemoAccess {
  available('Available'),
  private('Private'),
  unavailable('Unavailable'),
  notLinked('Not linked');

  const DemoAccess(this.label);
  final String label;
  bool get playable => this == DemoAccess.available;
}

class LiveLink {
  const LiveLink(this.url, {required this.reachable, required this.http});
  final String url;
  final bool reachable;
  final int http;
}

class CommitTiming {
  const CommitTiming({
    required this.total,
    required this.beforeOpen,
    required this.inWindow,
    required this.afterDeadline,
    required this.activeDays,
    required this.windowSpanMinutes,
    this.first,
    this.last,
  });
  final int total;
  final int beforeOpen;
  final int inWindow;
  final int afterDeadline;
  final int activeDays;
  final int windowSpanMinutes;
  final DateTime? first;
  final DateTime? last;

  factory CommitTiming.fromJson(Map<String, dynamic> json) => CommitTiming(
    total: json['total'] as int,
    beforeOpen: json['beforeOpen'] as int,
    inWindow: json['inWindow'] as int,
    afterDeadline: json['afterDeadline'] as int,
    activeDays: json['activeDays'] as int,
    windowSpanMinutes: json['windowSpanMinutes'] as int,
    first: DateTime.tryParse(json['first'] as String? ?? ''),
    last: DateTime.tryParse(json['last'] as String? ?? ''),
  );
}

/// Code written beyond the exact `serverpod create` template. Generated code
/// and platform runners are excluded; edited template files count only their
/// added lines.
class ScaffoldDelta {
  const ScaffoldDelta({
    required this.templateVersion,
    required this.lines,
    required this.editedTemplateLines,
    required this.byArea,
    required this.byLanguage,
    required this.untouchedTemplateFiles,
  });
  final String templateVersion;
  final int lines;
  final int editedTemplateLines;
  final Map<String, int> byArea;
  final Map<String, int> byLanguage;
  final List<String> untouchedTemplateFiles;

  int area(String name) => byArea[name] ?? 0;

  factory ScaffoldDelta.fromJson(Map<String, dynamic> json) => ScaffoldDelta(
    templateVersion: json['templateVersion'] as String,
    lines: json['delta'] as int,
    editedTemplateLines: json['editedTemplateLines'] as int,
    byArea: Map.unmodifiable((json['byArea'] as Map).cast<String, int>()),
    byLanguage: Map.unmodifiable(
      (json['byLanguage'] as Map).cast<String, int>(),
    ),
    untouchedTemplateFiles: List.unmodifiable(
      (json['untouchedTemplateFiles'] as List).cast<String>(),
    ),
  );
}

/// Which Serverpod capabilities the server package actually uses.
class ServerpodFootprint {
  const ServerpodFootprint({
    required this.models,
    required this.tables,
    required this.endpoints,
    required this.endpointMethods,
    required this.streamMethods,
    required this.dbCallSites,
    required this.futureCalls,
    required this.caching,
    required this.fileUploads,
    required this.authInCustomCode,
    required this.migrations,
    required this.generatedProtocol,
    required this.appCalls,
  });
  final int models;
  final int tables;
  final List<String> endpoints;
  final int endpointMethods;
  final int streamMethods;
  final int dbCallSites;
  final bool futureCalls;
  final bool caching;
  final bool fileUploads;
  final bool authInCustomCode;
  final int migrations;
  final bool generatedProtocol;

  /// Distinct `endpoint.method` calls found in the Flutter app.
  final List<String> appCalls;

  /// Every name [capabilities] can contain, in display order.
  static const capabilityNames = [
    'Database',
    'Streaming',
    'Future calls',
    'Serverpod auth',
    'File uploads',
    'Caching',
  ];

  /// Named capabilities in use, for display. A list of facts, never a score.
  List<String> get capabilities => [
    if (tables > 0) 'Database',
    if (streamMethods > 0) 'Streaming',
    if (futureCalls) 'Future calls',
    if (authInCustomCode) 'Serverpod auth',
    if (fileUploads) 'File uploads',
    if (caching) 'Caching',
  ];

  factory ServerpodFootprint.fromJson(Map<String, dynamic> json) =>
      ServerpodFootprint(
        models: json['models'] as int,
        tables: json['tables'] as int,
        endpoints: List.unmodifiable(
          (json['endpoints'] as List).cast<String>(),
        ),
        endpointMethods: json['endpointMethods'] as int,
        streamMethods: json['streamMethods'] as int,
        dbCallSites: json['dbCallSites'] as int,
        futureCalls: json['futureCalls'] as bool,
        caching: json['caching'] as bool,
        fileUploads: json['fileUploads'] as bool,
        authInCustomCode: json['authInCustomCode'] as bool,
        migrations: json['migrations'] as int,
        generatedProtocol: json['generatedProtocol'] as bool,
        appCalls: List.unmodifiable((json['appCalls'] as List).cast<String>()),
      );
}

/// Deterministic repository signals at the deadline snapshot.
class RepoSignals {
  const RepoSignals({
    required this.url,
    required this.snapshotSha,
    required this.snapshotIsHead,
    required this.commits,
    required this.serverpodConstraint,
    required this.serverpodMajor,
    required this.unresolvedDeps,
    required this.scaffold,
    required this.footprint,
    required this.testFiles,
    required this.testCases,
    required this.aiInCode,
    required this.otherBackends,
  });
  final String url;
  final String snapshotSha;
  final bool snapshotIsHead;
  final CommitTiming commits;
  final String serverpodConstraint;
  final int? serverpodMajor;
  final List<String> unresolvedDeps;
  final ScaffoldDelta scaffold;
  final ServerpodFootprint footprint;
  final int testFiles;
  final int testCases;
  final List<String> aiInCode;
  final List<String> otherBackends;

  factory RepoSignals.fromJson(Map<String, dynamic> json) {
    final serverpod = json['serverpod'] as Map<String, dynamic>;
    final snapshot = json['snapshot'] as Map<String, dynamic>;
    final tests = json['tests'] as Map<String, dynamic>;
    return RepoSignals(
      url: json['url'] as String,
      snapshotSha: snapshot['sha'] as String,
      snapshotIsHead: snapshot['isHead'] as bool,
      commits: CommitTiming.fromJson(json['commits'] as Map<String, dynamic>),
      serverpodConstraint: serverpod['constraint'] as String,
      serverpodMajor: serverpod['major'] as int?,
      unresolvedDeps: List.unmodifiable(
        (serverpod['unresolvedDeps'] as List).cast<String>(),
      ),
      scaffold: ScaffoldDelta.fromJson(
        json['scaffold'] as Map<String, dynamic>,
      ),
      footprint: ServerpodFootprint.fromJson(
        json['footprint'] as Map<String, dynamic>,
      ),
      testFiles: tests['files'] as int,
      testCases: tests['cases'] as int,
      aiInCode: List.unmodifiable((json['aiInCode'] as List).cast<String>()),
      otherBackends: List.unmodifiable(
        (json['otherBackends'] as List).cast<String>(),
      ),
    );
  }
}

/// A Jev Choice answer: the chosen option and how certain Jev was.
class JevChoice {
  const JevChoice(this.value, this.confidence);
  final String value;
  final double confidence;

  factory JevChoice.fromJson(Map<String, dynamic> json) => JevChoice(
    json['value'] as String,
    (json['confidence'] as num).toDouble(),
  );
}

/// One numbered line of a writeup, as Jev classified it.
class WriteupLine {
  const WriteupLine({
    required this.id,
    required this.text,
    this.section = '',
    this.heading = false,
    this.kind,
    this.probability,
  });
  final String id;
  final String text;
  final String section;
  final bool heading;
  final String? kind;
  final double? probability;

  factory WriteupLine.fromJson(Map<String, dynamic> json) => WriteupLine(
    id: json['id'] as String,
    text: json['text'] as String,
    section: json['section'] as String? ?? '',
    heading: json['heading'] as bool? ?? false,
    kind: json['kind'] as String?,
    probability: (json['p'] as num?)?.toDouble(),
  );
}

/// What Jev extracted from the writeup. Every field describes what the team
/// says; none of them is a quality judgement.
class JevSignals {
  const JevSignals({
    required this.model,
    required this.domain,
    required this.butlerMode,
    required this.aiRole,
    required this.aiProvider,
    required this.serverpodRole,
    required this.mentions,
    required this.admitsUnfinished,
    required this.lineKinds,
    required this.claims,
    required this.majorClaims,
    this.unfinishedLine,
    this.unfinishedLineProbability = 0,
  });
  final String model;
  final JevChoice domain;
  final JevChoice butlerMode;
  final JevChoice aiRole;
  final JevChoice aiProvider;
  final JevChoice serverpodRole;

  /// Noul probabilities that the writeup mentions each capability.
  final Map<String, double> mentions;
  final double admitsUnfinished;
  final WriteupLine? unfinishedLine;
  final double unfinishedLineProbability;
  final Map<String, int> lineKinds;

  /// Lines classified as capability, implementation or outcome statements.
  final int claims;

  /// Whether the writeup states at least one capability, implementation or
  /// outcome. Placeholder writeups ("WIP", an empty template) state none.
  bool get describesWork => claims > 0;
  final List<WriteupLine> majorClaims;

  double mention(String capability) => mentions[capability] ?? 0;

  factory JevSignals.fromJson(Map<String, dynamic> json) {
    final unfinished = json['unfinishedLine'] as Map<String, dynamic>?;
    return JevSignals(
      model: json['model'] as String,
      domain: JevChoice.fromJson(json['domain']),
      butlerMode: JevChoice.fromJson(json['butlerMode']),
      aiRole: JevChoice.fromJson(json['aiRole']),
      aiProvider: JevChoice.fromJson(json['aiProvider']),
      serverpodRole: JevChoice.fromJson(json['serverpodRole']),
      mentions: Map.unmodifiable(
        (json['mentions'] as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      ),
      admitsUnfinished: (json['admitsUnfinished'] as num).toDouble(),
      unfinishedLine: unfinished == null || unfinished['text'] == null
          ? null
          : WriteupLine(
              id: unfinished['line'] as String,
              text: unfinished['text'] as String,
            ),
      unfinishedLineProbability: (unfinished?['p'] as num? ?? 0).toDouble(),
      lineKinds: Map.unmodifiable(
        (json['lineKinds'] as Map).cast<String, int>(),
      ),
      claims: json['claims'] as int,
      majorClaims: List.unmodifiable(
        (json['majorClaims'] as List).map(
          (c) =>
              WriteupLine(id: c['line'] as String, text: c['text'] as String),
        ),
      ),
    );
  }
}

class TriageSubmission {
  const TriageSubmission({
    required this.id,
    required this.title,
    required this.tagline,
    required this.team,
    required this.devpostUrl,
    required this.builtWith,
    required this.repoAccess,
    required this.demoAccess,
    required this.jev,
    this.repoUrl,
    this.videoUrl,
    this.live = const [],
    this.checked,
    this.repo,
  });
  final String id;
  final String title;
  final String tagline;
  final List<String> team;
  final String devpostUrl;
  final List<String> builtWith;
  final String? repoUrl;
  final String? videoUrl;
  final List<LiveLink> live;

  /// When this row's links were checked, if later than the dataset's date.
  final String? checked;
  final RepoAccess repoAccess;
  final DemoAccess demoAccess;

  /// Null unless the repository was public and had a Serverpod package at a
  /// pre-deadline commit.
  final RepoSignals? repo;
  final JevSignals jev;

  factory TriageSubmission.fromJson(Map<String, dynamic> json) {
    final access = json['access'] as Map<String, dynamic>;
    final demo = access['demo'] as Map<String, dynamic>;
    final repoAccess = RepoAccess.values.byName(access['repo'] as String);
    // A public repository without a pre-deadline Serverpod package has no
    // signals to show; the lane rules report that gap explicitly.
    final raw = json['repo'] as Map<String, dynamic>?;
    final repo = raw != null && raw.containsKey('scaffold') ? raw : null;
    if (repo != null && repoAccess != RepoAccess.public) {
      throw FormatException('${json['id']}: signals for an inaccessible repo');
    }
    return TriageSubmission(
      id: json['id'] as String,
      title: json['title'] as String,
      tagline: json['tagline'] as String,
      team: List.unmodifiable((json['team'] as List).cast<String>()),
      devpostUrl: json['devpostUrl'] as String,
      builtWith: List.unmodifiable((json['builtWith'] as List).cast<String>()),
      repoUrl: json['links']['repo'] as String?,
      videoUrl: demo['url'] as String?,
      live: List.unmodifiable(
        (access['live'] as List).map(
          (l) => LiveLink(
            l['url'] as String,
            reachable: l['status'] == 'reachable',
            http: l['http'] as int,
          ),
        ),
      ),
      checked: access['checked'] as String?,
      repoAccess: repoAccess,
      demoAccess: DemoAccess.values.byName(demo['status'] as String),
      repo: repo == null ? null : RepoSignals.fromJson(repo),
      jev: JevSignals.fromJson(json['jev'] as Map<String, dynamic>),
    );
  }
}

class TriageDataset {
  const TriageDataset({
    required this.title,
    required this.sponsorTech,
    required this.gallery,
    required this.fieldSize,
    required this.submissionsOpen,
    required this.deadline,
    required this.sample,
    required this.checked,
    required this.jevModel,
    required this.jevScope,
    required this.jevInputTokens,
    required this.deterministicMethod,
    required this.submissions,
  });
  final String title;
  final String sponsorTech;
  final String gallery;

  /// Submissions in the whole hackathon, of which [submissions] is a sample.
  final int fieldSize;
  final DateTime submissionsOpen;
  final DateTime deadline;
  final String sample;
  final String checked;
  final String jevModel;
  final String jevScope;
  final int jevInputTokens;
  final String deterministicMethod;
  final List<TriageSubmission> submissions;

  TriageSubmission? byId(String id) {
    for (final s in submissions) {
      if (s.id == id) return s;
    }
    return null;
  }
}

TriageDataset parseTriage(String source) {
  final json = jsonDecode(source) as Map<String, dynamic>;
  final hackathon = json['hackathon'] as Map<String, dynamic>;
  final pilot = json['pilot'] as Map<String, dynamic>;
  final extraction = json['extraction'] as Map<String, dynamic>;
  final jev = extraction['jev'] as Map<String, dynamic>;
  final submissions = (json['submissions'] as List)
      .map((s) => TriageSubmission.fromJson(s as Map<String, dynamic>))
      .toList();
  if (submissions.map((s) => s.id).toSet().length != submissions.length) {
    throw const FormatException('Duplicate submission IDs');
  }
  return TriageDataset(
    title: hackathon['title'] as String,
    sponsorTech: hackathon['sponsorTech'] as String,
    gallery: hackathon['gallery'] as String,
    fieldSize: hackathon['fieldSize'] as int,
    submissionsOpen: DateTime.parse(hackathon['submissionsOpen'] as String),
    deadline: DateTime.parse(hackathon['deadline'] as String),
    sample: pilot['sample'] as String,
    checked: pilot['checked'] as String,
    jevModel: jev['model'] as String,
    jevScope: jev['scope'] as String,
    jevInputTokens: jev['inputTokens'] as int,
    deterministicMethod: extraction['deterministic'] as String,
    submissions: List.unmodifiable(submissions),
  );
}

/// Every numbered writeup line, keyed by submission. Loaded on demand, so the
/// table asset stays small as the field grows.
Map<String, List<WriteupLine>> parseWriteups(String source) {
  final json = jsonDecode(source) as Map<String, dynamic>;
  return {
    for (final e in json.entries)
      e.key: List.unmodifiable(
        (e.value as List).map((l) => WriteupLine.fromJson(l)),
      ),
  };
}
