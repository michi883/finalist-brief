import 'package:finalist_brief_shared/finalist_brief_shared.dart';

import 'fixture.dart';

/// Moves a `replay` brief through a fixed stage schedule based on the time
/// elapsed since it was created, so the result looks exactly like a pipeline
/// wrote it. Nothing runs in the background and progress is never stored:
/// [view] derives it from `createdAt` and the clock on every read.
class Replay {
  Replay({
    required this.fixture,
    required this.submissions,
    required this.webOrigin,
  }) : _stages = _schedule(fixture, submissions);

  static const _perSubmission = Duration(milliseconds: 1400);
  static const _selecting = Duration(milliseconds: 2000);
  static const _scripting = Duration(milliseconds: 2500);
  static const _perHighlight = Duration(milliseconds: 1200);
  static const _assembling = Duration(milliseconds: 2200);

  final Fixture fixture;
  final List<Submission> submissions;

  /// Origin of the web app, where `/briefs/<video>` is hosted.
  final String webOrigin;

  final List<_Stage> _stages;
  late final Duration _total = _stages.fold(
    Duration.zero,
    (sum, s) => sum + s.duration,
  );

  Duration get totalDuration => _total;

  /// A fresh, queued brief.
  Brief start(DateTime now) => Brief(
    status: BriefStatus.queued,
    mode: BriefMode.replay,
    progressPercent: 0,
    progressMessage: 'Queued',
    stageLog: const [],
    submissionCount: submissions.length,
    createdAt: now.toUtc(),
  );

  /// Whether [brief] has run through every stage by [now].
  bool isComplete(Brief brief, DateTime now) =>
      now.toUtc().difference(brief.createdAt) >= _total;

  /// The brief as it stands at [now].
  Brief view(Brief stored, DateTime now) {
    if (stored.mode != BriefMode.replay ||
        stored.status == BriefStatus.failed) {
      return stored;
    }
    final elapsed = now.toUtc().difference(stored.createdAt);
    if (elapsed >= _total) return _complete(stored);

    var cursor = Duration.zero;
    for (var i = 0; i < _stages.length; i++) {
      final stage = _stages[i];
      if (elapsed < cursor + stage.duration || i == _stages.length - 1) {
        final percent = (cursor.inMilliseconds * 100 / _total.inMilliseconds)
            .floor()
            .clamp(0, 99);
        return _copy(
          stored,
          status: stage.status,
          progressPercent: percent,
          progressMessage: stage.label,
          stageLog: [for (final done in _stages.take(i)) done.label],
        );
      }
      cursor += stage.duration;
    }
    return stored;
  }

  Brief _complete(Brief stored) {
    final idBySlug = {for (final s in submissions) s.slug: s.id!};
    return _copy(
      stored,
      status: BriefStatus.complete,
      progressPercent: 100,
      progressMessage: 'Briefing ready',
      stageLog: [for (final s in _stages) s.label],
      segments: [
        for (final segment in fixture.segments)
          BriefSegment(
            position: segment.position,
            submissionId: idBySlug[segment.slug] ?? 0,
            slug: segment.slug,
            title: segment.title,
            whySurfaced: segment.whySurfaced,
            evidence: segment.evidence,
            clipStartSec: segment.clipStartSec,
            clipEndSec: segment.clipEndSec,
            narration: segment.narration,
          ),
      ],
      videoUrl: '$webOrigin/briefs/${fixture.videoFile}',
      videoDurationSec: fixture.videoDurationSec,
      completedAt: stored.createdAt.add(_total),
    );
  }

  Brief _copy(
    Brief b, {
    required BriefStatus status,
    required int progressPercent,
    required String progressMessage,
    required List<String> stageLog,
    List<BriefSegment>? segments,
    String? videoUrl,
    int? videoDurationSec,
    DateTime? completedAt,
  }) => Brief(
    id: b.id,
    status: status,
    mode: b.mode,
    progressPercent: progressPercent,
    progressMessage: progressMessage,
    stageLog: stageLog,
    submissionCount: b.submissionCount,
    segments: segments,
    videoUrl: videoUrl,
    videoDurationSec: videoDurationSec,
    createdAt: b.createdAt,
    completedAt: completedAt,
  );

  static List<_Stage> _schedule(Fixture fixture, List<Submission> submissions) {
    final n = submissions.length;
    final highlights = fixture.segments;
    return [
      for (var i = 0; i < n; i++)
        _Stage(
          BriefStatus.analyzing,
          'Analyzing writeup, repo and demo · ${submissions[i].title} '
          '(${i + 1}/$n)',
          _perSubmission,
        ),
      const _Stage(
        BriefStatus.selecting,
        'Selecting projects worth closer review',
        _selecting,
      ),
      const _Stage(BriefStatus.scripting, 'Writing the narration', _scripting),
      for (var i = 0; i < highlights.length; i++)
        _Stage(
          BriefStatus.rendering,
          'Cutting highlight from ${highlights[i].title} '
          '(${i + 1}/${highlights.length})',
          _perHighlight,
        ),
      const _Stage(
        BriefStatus.rendering,
        'Assembling the briefing video',
        _assembling,
      ),
    ];
  }
}

class _Stage {
  const _Stage(this.status, this.label, this.duration);

  final BriefStatus status;
  final String label;
  final Duration duration;
}
