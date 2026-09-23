import 'package:finalist_brief_server/src/demo/seed.dart';
import 'package:finalist_brief_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given the seeded Humor Genome dataset', (
    sessionBuilder,
    endpoints,
  ) {
    setUp(() async {
      await seedDemoData(sessionBuilder.build());
    });

    test('when listing submissions then all 7 come back in order', () async {
      final submissions = await endpoints.submission.list(sessionBuilder);
      expect(submissions, hasLength(7));
      expect(
        submissions.map((s) => s.sortOrder),
        orderedEquals([1, 2, 3, 4, 5, 6, 7]),
      );
      expect(submissions.where((s) => s.hasDemoVideo), hasLength(3));
    });

    test('when seeding twice then nothing is duplicated', () async {
      await seedDemoData(sessionBuilder.build());
      expect(await endpoints.submission.list(sessionBuilder), hasLength(7));
      expect(await endpoints.analysis.list(sessionBuilder), hasLength(7));
    });

    test(
      'when reading analyses then every submission has one with evidence',
      () async {
        final analyses = await endpoints.analysis.list(sessionBuilder);
        expect(analyses, hasLength(7));
        for (final analysis in analyses) {
          expect(analysis.evidence, isNotEmpty, reason: analysis.summary);
          expect(analysis.promptVersion, 'golden');
        }
        expect(analyses.where((a) => a.worthCloserReview), hasLength(3));
        expect(
          analyses.where(
            (a) => !a.worthCloserReview && a.whyNotSurfaced == null,
          ),
          isEmpty,
          reason: 'every non-surfaced analysis explains why',
        );
      },
    );

    test('when requesting a live brief then it is unavailable', () async {
      expect(
        () => endpoints.brief.generate(sessionBuilder, BriefMode.live),
        throwsA(isA<BriefUnavailableException>()),
      );
    });

    test(
      'when generating a replay brief then it progresses to completion',
      () async {
        final brief = await endpoints.brief.generate(
          sessionBuilder,
          BriefMode.replay,
        );
        expect(brief.status, BriefStatus.queued);
        expect(brief.submissionCount, 7);

        final started = await endpoints.brief.get(sessionBuilder, brief.id!);
        expect(started!.status, BriefStatus.analyzing);
        expect(started.progressMessage, contains('(1/7)'));
        expect(started.segments, isNull);

        // Backdate the run so that the whole schedule has elapsed.
        final session = sessionBuilder.build();
        await Brief.db.updateRow(
          session,
          started.copyWith(
            createdAt: DateTime.now().toUtc().subtract(
              const Duration(minutes: 5),
            ),
          ),
        );

        final done = await endpoints.brief.get(sessionBuilder, brief.id!);
        expect(done!.status, BriefStatus.complete);
        expect(done.progressPercent, 100);
        expect(done.stageLog.length, greaterThanOrEqualTo(7 + 2 + 3 + 1));
        expect(done.segments, hasLength(3));
        expect(
          done.segments!.map((s) => s.slug),
          orderedEquals(['why-they-laugh', 'humor-genome-studio', 'killjoy']),
        );
        for (final segment in done.segments!) {
          expect(segment.submissionId, greaterThan(0));
          expect(segment.evidence, isNotEmpty);
          expect(segment.clipEndSec, greaterThan(segment.clipStartSec));
        }
        expect(
          done.videoUrl,
          matches(RegExp(r'/web/briefs/humor-genome-golden@[0-9a-f]+\.mp4$')),
        );
        expect(done.completedAt, isNotNull);

        final latest = await endpoints.brief.latestComplete(sessionBuilder);
        expect(latest?.id, brief.id);
      },
    );

    test(
      'when asking for one analysis then it matches the submission',
      () async {
        final submissions = await endpoints.submission.list(sessionBuilder);
        final killjoy = submissions.firstWhere((s) => s.slug == 'killjoy');
        final analysis = await endpoints.analysis.forSubmission(
          sessionBuilder,
          killjoy.id!,
        );
        expect(analysis, isNotNull);
        expect(analysis!.worthCloserReview, isTrue);
        expect(analysis.highlights, isNotEmpty);
        expect(
          analysis.evidence.map((e) => e.source),
          contains(EvidenceSource.video),
        );
      },
    );
  });
}
