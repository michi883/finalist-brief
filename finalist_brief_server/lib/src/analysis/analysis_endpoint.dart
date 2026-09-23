import 'package:serverpod/serverpod.dart';

import '../demo/demo_fixture.dart';
import '../generated/protocol.dart';

class AnalysisEndpoint extends Endpoint {
  /// The cached analysis of every submission (one per submission).
  Future<List<SubmissionAnalysis>> list(Session session) async {
    return SubmissionAnalysis.db.find(
      session,
      where: (t) => t.promptVersion.equals(goldenPromptVersion),
      orderBy: (t) => t.submissionId,
    );
  }

  /// The cached analysis of one submission, or null if it has none.
  Future<SubmissionAnalysis?> forSubmission(
    Session session,
    int submissionId,
  ) async {
    return SubmissionAnalysis.db.findFirstRow(
      session,
      where: (t) =>
          t.submissionId.equals(submissionId) &
          t.promptVersion.equals(goldenPromptVersion),
    );
  }
}
