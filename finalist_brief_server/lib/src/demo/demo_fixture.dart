import 'dart:convert';
import 'dart:io';

import '../generated/protocol.dart';

/// The hand-curated demo data under `assets/`. Loaded lazily, parsed once.
///
/// Phase 1 replaces every live pipeline stage with these files; see PLAN.md
/// §10–11. Paths are relative to the server package directory, which is the
/// working directory both under `serverpod start` and `dart test`.
class DemoFixture {
  DemoFixture._({
    required this.submissions,
    required this.analysesBySlug,
    required this.videoFile,
    required this.videoDurationSec,
    required this.intro,
    required this.outro,
    required this.segments,
  });

  static DemoFixture? _instance;

  static DemoFixture get instance => _instance ??= _load();

  /// Seed submissions in `sortOrder`.
  final List<Submission> submissions;

  /// Golden analyses keyed by submission slug; `submissionId` is 0 until seeded.
  final Map<String, SubmissionAnalysis> analysesBySlug;

  /// File name under `web/static/briefs/`.
  final String videoFile;
  final int videoDurationSec;
  final String intro;
  final String outro;

  /// Segments in playback order; `submissionId` is 0 until resolved.
  final List<BriefSegment> segments;

  static DemoFixture _load() {
    final submissions =
        (_readJson('assets/humor_genome/submissions.json') as List)
            .cast<Map<String, dynamic>>()
            .map(Submission.fromJson)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final analyses = <String, SubmissionAnalysis>{};
    for (final raw
        in (_readJson('assets/demo/analyses.json') as List)
            .cast<Map<String, dynamic>>()) {
      final slug = raw['slug'] as String;
      analyses[slug] = SubmissionAnalysis.fromJson({
        ...raw,
        'submissionId': 0,
        'promptVersion': goldenPromptVersion,
      });
    }

    final golden =
        _readJson('assets/demo/golden_brief.json') as Map<String, dynamic>;
    final segments =
        (golden['segments'] as List).cast<Map<String, dynamic>>().map((raw) {
          final slug = raw['slug'] as String;
          final submission = submissions.firstWhere((s) => s.slug == slug);
          return BriefSegment.fromJson({
            ...raw,
            'submissionId': 0,
            'title': submission.title,
          });
        }).toList()..sort((a, b) => a.position.compareTo(b.position));

    return DemoFixture._(
      submissions: submissions,
      analysesBySlug: analyses,
      videoFile: golden['videoFile'] as String,
      videoDurationSec: golden['videoDurationSec'] as int,
      intro: golden['intro'] as String,
      outro: golden['outro'] as String,
      segments: segments,
    );
  }

  static Object? _readJson(String path) =>
      jsonDecode(File(path).readAsStringSync());
}

/// `promptVersion` of the hand-curated analyses.
const goldenPromptVersion = 'golden';
