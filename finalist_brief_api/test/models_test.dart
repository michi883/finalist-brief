import 'dart:convert';

import 'package:finalist_brief_api/finalist_brief_api.dart';
import 'package:finalist_brief_shared/finalist_brief_shared.dart';
import 'package:test/test.dart';

/// The models are stored in Firestore as plain JSON maps, so they must survive
/// a trip through JSON unchanged.
void main() {
  Map<String, dynamic> roundTrip(Map<String, dynamic> json) =>
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

  test('every fixture model survives a JSON round trip', () {
    final fixture = Fixture.load('assets');

    for (final s in fixture.submissions) {
      expect(Submission.fromJson(roundTrip(s.toJson())).toJson(), s.toJson());
    }
    for (final a in fixture.analyses) {
      expect(
        SubmissionAnalysis.fromJson(roundTrip(a.toJson())).toJson(),
        a.toJson(),
      );
    }
    final brief = Brief(
      id: 'abc',
      status: BriefStatus.complete,
      mode: BriefMode.replay,
      progressPercent: 100,
      progressMessage: 'Briefing ready',
      stageLog: const ['one', 'two'],
      submissionCount: 7,
      segments: fixture.segments,
      videoUrl: 'https://example.test/v.mp4',
      videoDurationSec: 60,
      createdAt: DateTime.utc(2026, 11, 11, 12),
      completedAt: DateTime.utc(2026, 11, 11, 12, 1),
    );
    expect(Brief.fromJson(roundTrip(brief.toJson())).toJson(), brief.toJson());
  });
}
