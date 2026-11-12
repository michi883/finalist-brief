import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:finalist_brief_shared/finalist_brief_shared.dart';

/// `promptVersion` of the hand-curated analyses.
const goldenPromptVersion = 'golden';

/// The hand-curated demo data under `assets/`, parsed once at startup.
///
/// Firestore is seeded from it, and [hash] says whether the stored copy is
/// current. Submission ids equal their `sortOrder`.
class Fixture {
  Fixture._({
    required this.submissions,
    required this.analyses,
    required this.videoFile,
    required this.videoDurationSec,
    required this.segments,
    required this.hash,
  });

  /// Submissions in display order, with ids assigned.
  final List<Submission> submissions;

  /// One golden analysis per submission, keyed by `submissionId`.
  final List<SubmissionAnalysis> analyses;

  /// File name of the briefing video, hosted by Firebase Hosting at `/briefs/`.
  final String videoFile;
  final int videoDurationSec;

  /// Segments in playback order, with `submissionId` and `title` resolved.
  final List<BriefSegment> segments;

  /// Content hash of the source files.
  final String hash;

  factory Fixture.load(String assetsDir) {
    final raw = {
      for (final name in const [
        'humor_genome/submissions.json',
        'demo/analyses.json',
        'demo/golden_brief.json',
      ])
        name: File('$assetsDir/$name').readAsStringSync(),
    };

    final submissions = [
      for (final json
          in jsonDecode(raw['humor_genome/submissions.json']!) as List)
        Submission.fromJson(json as Map<String, dynamic>),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final withIds = [for (final s in submissions) s.withId(s.sortOrder)];
    final bySlug = {for (final s in withIds) s.slug: s};

    final analyses = <SubmissionAnalysis>[];
    for (final json in jsonDecode(raw['demo/analyses.json']!) as List) {
      final map = json as Map<String, dynamic>;
      analyses.add(
        SubmissionAnalysis.fromJson({
          ...map,
          'submissionId': bySlug[map['slug']]!.id,
          'promptVersion': goldenPromptVersion,
        }),
      );
    }
    analyses.sort((a, b) => a.submissionId.compareTo(b.submissionId));

    final golden =
        jsonDecode(raw['demo/golden_brief.json']!) as Map<String, dynamic>;
    final segments = [
      for (final json in golden['segments'] as List)
        () {
          final map = json as Map<String, dynamic>;
          final submission = bySlug[map['slug']]!;
          return BriefSegment.fromJson({
            ...map,
            'submissionId': submission.id,
            'title': submission.title,
          });
        }(),
    ]..sort((a, b) => a.position.compareTo(b.position));

    return Fixture._(
      submissions: withIds,
      analyses: analyses,
      videoFile: golden['videoFile'] as String,
      videoDurationSec: golden['videoDurationSec'] as int,
      segments: segments,
      hash: sha256.convert(utf8.encode(raw.values.join('\n'))).toString(),
    );
  }
}
