import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'replay_runner.dart';

class BriefEndpoint extends Endpoint {
  /// Starts a briefing run and returns it immediately. Poll [get] for progress.
  ///
  /// Only [BriefMode.replay] runs in Phase 1; it walks the cached demo data.
  Future<Brief> generate(Session session, BriefMode mode) async {
    if (mode == BriefMode.live) {
      throw BriefUnavailableException(
        message:
            'Live analysis is not built yet. Open the app with ?demo=1 to run '
            'the cached demo.',
      );
    }
    final brief = Brief(
      status: BriefStatus.queued,
      mode: mode,
      progressPercent: 0,
      progressMessage: 'Queued',
      stageLog: const [],
      submissionCount: await Submission.db.count(session),
      createdAt: DateTime.now().toUtc(),
    );
    return Brief.db.insertRow(session, brief);
  }

  /// Current state of a briefing run. Replay briefs advance on every call.
  Future<Brief?> get(Session session, int id) async {
    final brief = await Brief.db.findById(session, id);
    if (brief == null) return null;
    final finished =
        brief.status == BriefStatus.complete ||
        brief.status == BriefStatus.failed;
    if (brief.mode == BriefMode.replay && !finished) {
      return ReplayRunner.advance(session, brief);
    }
    return brief;
  }

  /// The most recently completed briefing, if any.
  Future<Brief?> latestComplete(Session session) async {
    return Brief.db.findFirstRow(
      session,
      where: (t) => t.status.equals(BriefStatus.complete),
      orderBy: (t) => t.completedAt.desc(),
    );
  }
}
