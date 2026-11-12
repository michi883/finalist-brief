// Plain data models for the Finalist Brief API. JSON is the wire and storage
// format: the API returns these as JSON and Firestore documents hold the same
// shape. Dates are ISO 8601 strings in UTC.

/// Where a piece of evidence was found.
enum EvidenceSource { description, repo, video }

/// `replay` walks cached data; `live` is reserved for a later pipeline.
enum BriefMode { replay, live }

enum BriefStatus {
  queued,
  analyzing,
  selecting,
  scripting,
  rendering,
  complete,
  failed,
}

/// Thrown when a requested brief mode cannot run (for example `live`).
class BriefUnavailableException implements Exception {
  const BriefUnavailableException({required this.message});

  final String message;

  @override
  String toString() => 'BriefUnavailableException: $message';
}

/// One hackathon submission from the fixed Humor Genome dataset.
class Submission {
  const Submission({
    this.id,
    required this.slug,
    required this.title,
    required this.creator,
    required this.summary,
    required this.gemmaUse,
    required this.kaggleUrl,
    this.repoUrl,
    this.demoUrl,
    required this.hasDemoVideo,
    required this.coverAsset,
    required this.sortOrder,
  });

  factory Submission.fromJson(Map<String, dynamic> json) => Submission(
    id: json['id'] as int?,
    slug: json['slug'] as String,
    title: json['title'] as String,
    creator: json['creator'] as String,
    summary: json['summary'] as String,
    gemmaUse: json['gemmaUse'] as String,
    kaggleUrl: json['kaggleUrl'] as String,
    repoUrl: json['repoUrl'] as String?,
    demoUrl: json['demoUrl'] as String?,
    hasDemoVideo: json['hasDemoVideo'] as bool,
    coverAsset: json['coverAsset'] as String,
    sortOrder: json['sortOrder'] as int,
  );

  /// Stable id, equal to [sortOrder]; analyses and brief segments refer to it.
  final int? id;

  /// Stable key used for cache files, cover assets and fixture lookups.
  final String slug;
  final String title;
  final String creator;

  /// One-line description from the writeup.
  final String summary;

  /// How the writeup says Gemma is used.
  final String gemmaUse;
  final String kaggleUrl;
  final String? repoUrl;

  /// YouTube video, Kaggle notebook or live site, whichever the writeup links.
  final String? demoUrl;

  /// True when [demoUrl] is an actual video the briefing can cut from.
  final bool hasDemoVideo;

  /// File name of the cover image bundled with the Flutter app.
  final String coverAsset;
  final int sortOrder;

  Submission withId(int id) => Submission(
    id: id,
    slug: slug,
    title: title,
    creator: creator,
    summary: summary,
    gemmaUse: gemmaUse,
    kaggleUrl: kaggleUrl,
    repoUrl: repoUrl,
    demoUrl: demoUrl,
    hasDemoVideo: hasDemoVideo,
    coverAsset: coverAsset,
    sortOrder: sortOrder,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'slug': slug,
    'title': title,
    'creator': creator,
    'summary': summary,
    'gemmaUse': gemmaUse,
    'kaggleUrl': kaggleUrl,
    'repoUrl': repoUrl,
    'demoUrl': demoUrl,
    'hasDemoVideo': hasDemoVideo,
    'coverAsset': coverAsset,
    'sortOrder': sortOrder,
  };
}

/// Assessment of one fixed evaluation area.
class AreaAssessment {
  const AreaAssessment({required this.score, required this.note});

  factory AreaAssessment.fromJson(Map<String, dynamic> json) =>
      AreaAssessment(score: json['score'] as int, note: json['note'] as String);

  /// 1-5, used only for selection; never shown as a number.
  final int score;
  final String note;

  Map<String, dynamic> toJson() => {'score': score, 'note': note};
}

/// A concrete, checkable piece of evidence behind an assessment.
class EvidenceItem {
  const EvidenceItem({required this.source, required this.detail, this.ref});

  factory EvidenceItem.fromJson(Map<String, dynamic> json) => EvidenceItem(
    source: EvidenceSource.values.byName(json['source'] as String),
    detail: json['detail'] as String,
    ref: json['ref'] as String?,
  );

  final EvidenceSource source;
  final String detail;

  /// A URL, a repo path, or `t=<seconds>` for a video timestamp.
  final String? ref;

  Map<String, dynamic> toJson() => {
    'source': source.name,
    'detail': detail,
    'ref': ref,
  };
}

/// A window in the demo video worth watching.
class Highlight {
  const Highlight({
    required this.startSec,
    required this.endSec,
    required this.whatIsShown,
    required this.whyItMatters,
  });

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
    startSec: json['startSec'] as int,
    endSec: json['endSec'] as int,
    whatIsShown: json['whatIsShown'] as String,
    whyItMatters: json['whyItMatters'] as String,
  );

  final int startSec;
  final int endSec;
  final String whatIsShown;
  final String whyItMatters;

  Map<String, dynamic> toJson() => {
    'startSec': startSec,
    'endSec': endSec,
    'whatIsShown': whatIsShown,
    'whyItMatters': whyItMatters,
  };
}

/// Structured analysis of one submission, seeded from `assets/demo`.
class SubmissionAnalysis {
  const SubmissionAnalysis({
    required this.submissionId,
    required this.promptVersion,
    required this.summary,
    required this.technical,
    required this.demonstration,
    required this.idea,
    required this.gemmaUsage,
    required this.worthCloserReview,
    required this.whyWorthAttention,
    this.whyNotSurfaced,
    required this.evidence,
    required this.highlights,
  });

  factory SubmissionAnalysis.fromJson(Map<String, dynamic> json) =>
      SubmissionAnalysis(
        submissionId: json['submissionId'] as int,
        promptVersion: json['promptVersion'] as String,
        summary: json['summary'] as String,
        technical: AreaAssessment.fromJson(
          json['technical'] as Map<String, dynamic>,
        ),
        demonstration: AreaAssessment.fromJson(
          json['demonstration'] as Map<String, dynamic>,
        ),
        idea: AreaAssessment.fromJson(json['idea'] as Map<String, dynamic>),
        gemmaUsage: AreaAssessment.fromJson(
          json['gemmaUsage'] as Map<String, dynamic>,
        ),
        worthCloserReview: json['worthCloserReview'] as bool,
        whyWorthAttention: json['whyWorthAttention'] as String,
        whyNotSurfaced: json['whyNotSurfaced'] as String?,
        evidence: _objects(json['evidence'], EvidenceItem.fromJson),
        highlights: _objects(json['highlights'], Highlight.fromJson),
      );

  final int submissionId;
  final String promptVersion;
  final String summary;
  final AreaAssessment technical;
  final AreaAssessment demonstration;
  final AreaAssessment idea;
  final AreaAssessment gemmaUsage;
  final bool worthCloserReview;
  final String whyWorthAttention;

  /// Short reason shown under "also analyzed" when not surfaced.
  final String? whyNotSurfaced;
  final List<EvidenceItem> evidence;
  final List<Highlight> highlights;

  Map<String, dynamic> toJson() => {
    'submissionId': submissionId,
    'promptVersion': promptVersion,
    'summary': summary,
    'technical': technical.toJson(),
    'demonstration': demonstration.toJson(),
    'idea': idea.toJson(),
    'gemmaUsage': gemmaUsage.toJson(),
    'worthCloserReview': worthCloserReview,
    'whyWorthAttention': whyWorthAttention,
    'whyNotSurfaced': whyNotSurfaced,
    'evidence': [for (final e in evidence) e.toJson()],
    'highlights': [for (final h in highlights) h.toJson()],
  };
}

/// One surfaced project inside a briefing, in playback order.
class BriefSegment {
  const BriefSegment({
    required this.position,
    required this.submissionId,
    required this.slug,
    required this.title,
    required this.whySurfaced,
    required this.evidence,
    required this.clipStartSec,
    required this.clipEndSec,
    required this.narration,
  });

  factory BriefSegment.fromJson(Map<String, dynamic> json) => BriefSegment(
    position: json['position'] as int,
    submissionId: json['submissionId'] as int,
    slug: json['slug'] as String,
    title: json['title'] as String,
    whySurfaced: json['whySurfaced'] as String,
    evidence: _objects(json['evidence'], EvidenceItem.fromJson),
    clipStartSec: json['clipStartSec'] as int,
    clipEndSec: json['clipEndSec'] as int,
    narration: json['narration'] as String,
  );

  final int position;
  final int submissionId;
  final String slug;
  final String title;
  final String whySurfaced;
  final List<EvidenceItem> evidence;
  final int clipStartSec;
  final int clipEndSec;
  final String narration;

  Map<String, dynamic> toJson() => {
    'position': position,
    'submissionId': submissionId,
    'slug': slug,
    'title': title,
    'whySurfaced': whySurfaced,
    'evidence': [for (final e in evidence) e.toJson()],
    'clipStartSec': clipStartSec,
    'clipEndSec': clipEndSec,
    'narration': narration,
  };
}

/// A finalist briefing run and its result.
class Brief {
  const Brief({
    this.id,
    required this.status,
    required this.mode,
    required this.progressPercent,
    required this.progressMessage,
    required this.stageLog,
    required this.submissionCount,
    this.segments,
    this.videoUrl,
    this.videoDurationSec,
    required this.createdAt,
    this.completedAt,
  });

  factory Brief.fromJson(Map<String, dynamic> json) => Brief(
    id: json['id'] as String?,
    status: BriefStatus.values.byName(json['status'] as String),
    mode: BriefMode.values.byName(json['mode'] as String),
    progressPercent: json['progressPercent'] as int,
    progressMessage: json['progressMessage'] as String,
    stageLog: [for (final s in json['stageLog'] as List) s as String],
    submissionCount: json['submissionCount'] as int,
    segments: json['segments'] == null
        ? null
        : _objects(json['segments'], BriefSegment.fromJson),
    videoUrl: json['videoUrl'] as String?,
    videoDurationSec: json['videoDurationSec'] as int?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
  );

  /// Firestore document id; null until stored.
  final String? id;
  final BriefStatus status;
  final BriefMode mode;
  final int progressPercent;
  final String progressMessage;
  final List<String> stageLog;
  final int submissionCount;

  /// Exactly three when complete.
  final List<BriefSegment>? segments;
  final String? videoUrl;
  final int? videoDurationSec;
  final DateTime createdAt;
  final DateTime? completedAt;

  Brief withId(String id) => Brief(
    id: id,
    status: status,
    mode: mode,
    progressPercent: progressPercent,
    progressMessage: progressMessage,
    stageLog: stageLog,
    submissionCount: submissionCount,
    segments: segments,
    videoUrl: videoUrl,
    videoDurationSec: videoDurationSec,
    createdAt: createdAt,
    completedAt: completedAt,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'status': status.name,
    'mode': mode.name,
    'progressPercent': progressPercent,
    'progressMessage': progressMessage,
    'stageLog': stageLog,
    'submissionCount': submissionCount,
    'segments': segments == null
        ? null
        : [for (final s in segments!) s.toJson()],
    'videoUrl': videoUrl,
    'videoDurationSec': videoDurationSec,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
  };
}

List<T> _objects<T>(Object? json, T Function(Map<String, dynamic>) parse) => [
  for (final item in (json as List? ?? const []))
    parse(item as Map<String, dynamic>),
];
