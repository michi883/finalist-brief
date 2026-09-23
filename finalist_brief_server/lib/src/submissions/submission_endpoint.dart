import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

class SubmissionEndpoint extends Endpoint {
  /// All submissions of the fixed Humor Genome dataset, in display order.
  Future<List<Submission>> list(Session session) async {
    return Submission.db.find(session, orderBy: (t) => t.sortOrder);
  }
}
