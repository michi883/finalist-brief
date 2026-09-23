import 'package:serverpod/serverpod.dart';

import '../cache_busting.dart';
import '../demo/demo_fixture.dart';
import '../generated/protocol.dart';

/// Advances a `replay` brief through a fixed stage schedule based on the time
/// elapsed since it was created, then persists the row. No background work:
/// every `brief.get` call moves the row forward, so the result looks exactly
/// like a pipeline wrote it (PLAN.md §11).
class ReplayRunner {
  static const _perSubmission = Duration(milliseconds: 1400);
  static const _selecting = Duration(milliseconds: 2000);
  static const _scripting = Duration(milliseconds: 2500);
  static const _perHighlight = Duration(milliseconds: 1200);
  static const _assembling = Duration(milliseconds: 2200);

  static Future<Brief> advance(Session session, Brief brief) async {
    final stages = await _schedule(session);
    final total = stages.fold(Duration.zero, (sum, s) => sum + s.duration);
    final elapsed = DateTime.now().toUtc().difference(brief.createdAt);

    if (elapsed >= total) {
      final completed = await _complete(session, brief, stages);
      return Brief.db.updateRow(session, completed);
    }

    var cursor = Duration.zero;
    for (var i = 0; i < stages.length; i++) {
      final stage = stages[i];
      if (elapsed < cursor + stage.duration) {
        final percent = (cursor.inMilliseconds * 100 / total.inMilliseconds)
            .floor()
            .clamp(0, 99);
        final updated = brief.copyWith(
          status: stage.status,
          progressPercent: percent,
          progressMessage: stage.label,
          stageLog: [for (final done in stages.take(i)) done.label],
        );
        if (_same(updated, brief)) return brief;
        return Brief.db.updateRow(session, updated);
      }
      cursor += stage.duration;
    }
    // Unreachable: elapsed < total means one of the stages matched.
    return brief;
  }

  static Future<Brief> _complete(
    Session session,
    Brief brief,
    List<_Stage> stages,
  ) async {
    final fixture = DemoFixture.instance;
    final submissions = await Submission.db.find(session);
    final idBySlug = {for (final s in submissions) s.slug: s.id!};

    final videoUrl = await _videoUrl(session, fixture.videoFile);
    return brief.copyWith(
      status: BriefStatus.complete,
      progressPercent: 100,
      progressMessage: 'Briefing ready',
      stageLog: [for (final s in stages) s.label],
      segments: [
        for (final segment in fixture.segments)
          segment.copyWith(submissionId: idBySlug[segment.slug] ?? 0),
      ],
      videoUrl: videoUrl,
      videoDurationSec: fixture.videoDurationSec,
      completedAt: DateTime.now().toUtc(),
    );
  }

  /// The briefing video is a static file under `web/static/briefs/`, served
  /// by the web server's `StaticRoute` at `/web/briefs/...`. The URL is
  /// cache-busted (`name@hash.mp4`) because that route sends a one-year
  /// `immutable` cache header; a rebuilt video must get a new URL.
  static Future<String> _videoUrl(Session session, String fileName) async {
    final path = await cacheBustingConfig.tryAssetPath(
      '${cacheBustingConfig.mountPrefix}briefs/$fileName',
    );
    final web = session.serverpod.config.webServer;
    if (web == null) return path;
    return Uri(
      scheme: web.publicScheme,
      host: web.publicHost,
      port: web.publicPort,
      path: path,
    ).toString();
  }

  static Future<List<_Stage>> _schedule(Session session) async {
    final submissions = await Submission.db.find(
      session,
      orderBy: (t) => t.sortOrder,
    );
    final fixture = DemoFixture.instance;
    final n = submissions.length;
    return [
      for (var i = 0; i < n; i++)
        _Stage(
          BriefStatus.analyzing,
          'Analyzing writeup, repo and demo · ${submissions[i].title} '
          '(${i + 1}/$n)',
          _perSubmission,
        ),
      _Stage(
        BriefStatus.selecting,
        'Selecting projects worth closer review',
        _selecting,
      ),
      _Stage(BriefStatus.scripting, 'Writing the narration', _scripting),
      for (var i = 0; i < fixture.segments.length; i++)
        _Stage(
          BriefStatus.rendering,
          'Cutting highlight from ${fixture.segments[i].title} '
          '(${i + 1}/${fixture.segments.length})',
          _perHighlight,
        ),
      _Stage(
        BriefStatus.rendering,
        'Assembling the briefing video',
        _assembling,
      ),
    ];
  }

  static bool _same(Brief a, Brief b) =>
      a.status == b.status &&
      a.progressPercent == b.progressPercent &&
      a.progressMessage == b.progressMessage;
}

class _Stage {
  const _Stage(this.status, this.label, this.duration);

  final BriefStatus status;
  final String label;
  final Duration duration;
}
