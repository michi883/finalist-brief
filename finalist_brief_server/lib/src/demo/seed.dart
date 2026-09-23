import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'demo_fixture.dart';

/// Inserts the fixed dataset and its golden analyses if they are not there yet.
/// Safe to call on every boot.
Future<void> seedDemoData(Session session) async {
  final fixture = DemoFixture.instance;

  if (await Submission.db.count(session) == 0) {
    await Submission.db.insert(session, fixture.submissions);
    session.log('Seeded ${fixture.submissions.length} submissions');
  }

  final submissions = await Submission.db.find(session);
  final idBySlug = {for (final s in submissions) s.slug: s.id!};

  final existing = await SubmissionAnalysis.db.find(
    session,
    where: (t) => t.promptVersion.equals(goldenPromptVersion),
  );
  final analyzedIds = existing.map((a) => a.submissionId).toSet();

  final missing = <SubmissionAnalysis>[];
  for (final entry in fixture.analysesBySlug.entries) {
    final submissionId = idBySlug[entry.key];
    if (submissionId == null || analyzedIds.contains(submissionId)) continue;
    missing.add(entry.value.copyWith(submissionId: submissionId));
  }
  if (missing.isNotEmpty) {
    await SubmissionAnalysis.db.insert(session, missing);
    session.log('Seeded ${missing.length} golden analyses');
  }
}
