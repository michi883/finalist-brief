import 'dart:convert';
import 'dart:io';

import 'package:finalist_brief_flutter/hackathon/hackathon.dart';
import 'package:finalist_brief_flutter/representation/project.dart';
import 'package:finalist_brief_flutter/triage/lanes.dart';
import 'package:finalist_brief_flutter/triage/review_lens.dart';
import 'package:finalist_brief_flutter/triage/triage.dart';
import 'package:finalist_brief_flutter/triage/triage_query.dart';
import 'package:finalist_brief_flutter/visualization/graph_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final triageSource = File('assets/triage/serverpod.json').readAsStringSync();
  final triage = parseTriage(triageSource);
  final competition = parseCompetition(
    File('assets/representations/serverpod.json').readAsStringSync(),
  );
  final assessments = assessField(triage);
  TriageAssessment assessment(String id) => assessments[id]!;
  List<TriageRow> rows() => [
    for (final s in triage.submissions)
      TriageRow(
        submission: s,
        assessment: assessments[s.id]!,
        hasRepresentation: competition.projects.any((p) => p.id == s.id),
      ),
  ];

  test('Triage covers all 117 Serverpod submissions', () {
    expect(triage.submissions, hasLength(117));
    expect(triage.fieldSize, 117);
    expect(triage.sponsorTech, 'Serverpod');
    expect(triage.deadline, DateTime.utc(2026, 1, 30, 16));
    expect(triage.jevModel, 'jev-1.13.0');
  });

  test('Outcome, popularity and score fields never enter the dataset', () {
    // Prose may say what is excluded; no key may carry such data.
    const forbidden = [
      'winner',
      'prize',
      'like',
      'star',
      'fork',
      'comment',
      'score',
      'rank',
      'merit',
      'rating',
    ];
    void walk(Object? value, String path) {
      if (value is Map) {
        for (final e in value.entries) {
          final key = (e.key as String).toLowerCase();
          expect(forbidden.any(key.contains), isFalse, reason: '$path.$key');
          walk(e.value, '$path.$key');
        }
      } else if (value is List) {
        for (final v in value) {
          walk(v, path);
        }
      }
    }

    walk(jsonDecode(triageSource), r'$');
  });

  test('Deterministic and Jev signals stay separate and labelled', () {
    for (final s in triage.submissions) {
      expect(s.jev.model, 'jev-1.13.0');
      expect(s.repo == null, s.repoAccess != RepoAccess.public, reason: s.id);
      for (final lane in assessment(s.id).lanes) {
        expect(lane.sources, isNotEmpty);
        switch (lane.lane) {
          case Lane.substantialBuild:
            expect(lane.sources, {SignalSource.repo});
          case Lane.distinctiveIdea:
            expect(lane.sources, {SignalSource.jev});
          case Lane.underTold:
            expect(lane.sources, {SignalSource.repo, SignalSource.jev});
          case Lane.unresolved:
            break;
        }
      }
    }
  });

  test('Every lane has a concise named reason and the rules are stable', () {
    final again = assessField(triage);
    for (final s in triage.submissions) {
      final a = assessment(s.id);
      expect(
        again[s.id]!.lanes.map((l) => (l.lane, l.reason)),
        a.lanes.map((l) => (l.lane, l.reason)),
      );
      for (final lane in a.lanes) {
        expect(lane.reason.trim(), isNotEmpty);
        expect(lane.reason.length, lessThan(90), reason: lane.reason);
      }
      // Lanes appear once each, in their fixed order.
      final order = a.lanes.map((l) => l.lane.index).toList();
      expect(order, [...order]..sort());
      expect(order.toSet().length, order.length);
      for (final q in a.questions) {
        expect(q.question.trim(), endsWith('?'), reason: q.question);
      }
    }
  });

  test('Lane rules name the specific gap or strength', () {
    expect(
      assessment('course-craft-ai').lanes.single.reason,
      'Only the writeup can be inspected',
    );
    expect(
      assessment('doby-rna2yf').lanes.single.reason,
      'Central AI claim; no model call in code',
    );
    final social = assessment('social-fabric');
    expect(social.lanes.map((l) => l.lane), [Lane.underTold, Lane.unresolved]);
    expect(social.centrality, SponsorCentrality.peripheral);
    expect(
      social.questions.first.question,
      contains('never calls the server’s 39 endpoint methods'),
    );
    expect(
      assessment(
        'pulse-the-autonomous-corporate-memory-knowledge-graph',
      ).lanes.last.reason,
      'Depends on serverpod_postgres, not on pub.dev',
    );
    // Distinctive is relative to the sample: at 117 rows the rare-area limit
    // is 5 (5% of 117), and the reason counts the three automation projects.
    final vault = assessment('vaultnbinder');
    expect(vault.lanes.single.lane, Lane.substantialBuild);
    expect(vault.coverage, EvidenceCoverage.codeAndDemo);
    expect(
      assessment('bubbdy-ai-lancher').lanes.first.reason,
      '3 automation projects in the sample · answers in chat',
    );
    // A placeholder writeup ("WIP") states nothing, so Jev's area guess from
    // the title and built-with tags cannot make it distinctive, and the
    // missing evidence is named instead.
    final placeholder = assessment('papiertiger');
    expect(
      placeholder.lanes.single.reason,
      'No repository, demo or described writeup',
    );
    expect(placeholder.coverage, EvidenceCoverage.none);
    expect(placeholder.questions.map((q) => q.gap), contains(Gap.emptyWriteup));
    expect(
      assessment('focus-buttler').questions.map((q) => q.gap),
      contains(Gap.emptyWriteup),
    );
  });

  test('Triage queries sort and search deterministically', () {
    final all = rows();
    const query = TriageQuery();
    final byBuild = query.sortedBy(TriageColumn.build).apply(all);
    expect(byBuild.first.id, 'crewboard');
    expect(byBuild.last.submission.repo, isNull);
    // Sorting the same column again reverses it; Code substance shares the
    // key, so it counts as the same column.
    final reversed = query
        .sortedBy(TriageColumn.build)
        .sortedBy(TriageColumn.substance)
        .apply(all);
    expect(reversed.last.id, 'crewboard');

    expect(
      query.copyWith(search: 'dermatologist').apply(all).single.id,
      'skinaware',
    );
    // Search applies within the chosen lens.
    expect(
      TriageQuery.forLens(
        ReviewLens.substantial,
      ).copyWith(search: 'dermatologist').apply(all).single.id,
      'skinaware',
    );
    expect(
      TriageQuery.forLens(
        ReviewLens.underTold,
      ).copyWith(search: 'dermatologist').apply(all),
      isEmpty,
    );
    // Ties fall back to title, so identical keys never reorder.
    final byEvidence = query.sortedBy(TriageColumn.evidence);
    expect(
      byEvidence.apply(all).map((r) => r.id),
      byEvidence.apply(all.reversed).map((r) => r.id),
    );
  });

  test('Each lens selects its rows by a named rule and never reranks', () {
    final all = rows();
    Set<String> ids(ReviewLens lens) =>
        TriageQuery.forLens(lens).apply(all).map((r) => r.id).toSet();
    Set<String> inLane(Lane lane) => {
      for (final r in all)
        if (r.assessment.inLane(lane)) r.id,
    };
    expect(ids(ReviewLens.all), hasLength(117));
    expect(ids(ReviewLens.sponsor), hasLength(117));
    expect(ids(ReviewLens.substantial), inLane(Lane.substantialBuild));
    expect(ids(ReviewLens.distinctive), inLane(Lane.distinctiveIdea));
    expect(ids(ReviewLens.underTold), inLane(Lane.underTold));
    // Needs verification: every Unresolved row, plus rows whose writeup
    // describes something the code or links do not show.
    expect(ids(ReviewLens.verify), {
      ...inLane(Lane.unresolved),
      'adex-adaptive-data-extraction-system',
      'btlr-2xcw9f',
      'butlrapp',
      'gitradar',
      'glowcare',
      'insomnia-butler',
      'legal-lens-foazyi',
      'road-trip-butler',
      'root-radar',
      'skinaware',
      'vaultnbinder',
    });
    expect(ids(ReviewLens.verify), hasLength(95));

    // Lenses choose a few columns and an order; lane membership is
    // untouched.
    for (final lens in ReviewLens.values) {
      final query = TriageQuery.forLens(lens);
      expect(query.columns.first, TriageColumn.project);
      expect(query.columns.length, lessThanOrEqualTo(4));
      expect(query.columns, contains(lens.sort));
    }
    expect(TriageQuery.forLens(ReviewLens.all).columns, [
      TriageColumn.project,
      TriageColumn.why,
      TriageColumn.evidence,
    ]);
    expect(
      TriageQuery.forLens(ReviewLens.substantial).apply(all).first.id,
      'crewboard',
    );
    // Most fundamental gap first: no repository, then title order.
    expect(
      TriageQuery.forLens(
        ReviewLens.verify,
      ).apply(all).take(2).map((r) => r.id).toSet(),
      {'textpilot-your-system-wide-flutter-butler', 'ai-butler-c6abte'},
    );
    final roles = TriageQuery.forLens(
      ReviewLens.sponsor,
    ).apply(all).map((r) => r.assessment.centrality.index).toList();
    expect(roles, [...roles]..sort());
  });

  test('Switching lens restores its order and keeps the search', () {
    final carried = TriageQuery.forLens(ReviewLens.verify)
        .copyWith(search: 'a')
        .sortedBy(TriageColumn.project)
        .withLens(ReviewLens.substantial);
    expect(carried.lens, ReviewLens.substantial);
    expect(carried.sort, ReviewLens.substantial.sort);
    expect(carried.ascending, isFalse);
    expect(carried.search, 'a');
  });

  test('Why it matters reuses a lane or question, never a new signal', () {
    // What blocks checking the server comes first…
    expect(
      sponsorFinding(assessment('social-fabric')),
      'App never calls its 39 endpoint methods',
    );
    expect(
      sponsorFinding(
        assessment('pulse-the-autonomous-corporate-memory-knowledge-graph'),
      ),
      'Depends on serverpod_postgres, not on pub.dev',
    );
    // …then Serverpod features described but not found; AI claims are not
    // Serverpod findings.
    expect(
      sponsorFinding(assessment('doby-rna2yf')),
      'Described but not found: real-time updates, scheduled work',
    );
    // …then what the writeup leaves out.
    expect(
      sponsorFinding(assessment('lifesync-ai-zm1hp4')),
      assessment('lifesync-ai-zm1hp4').lane(Lane.underTold)!.reason,
    );
    expect(sponsorFinding(assessment('butler-xlrjsp')), isNull);
    // Every finding is a lane reason or names described-but-missing claims.
    for (final s in triage.submissions) {
      final a = assessment(s.id);
      final finding = sponsorFinding(a);
      if (finding == null) continue;
      expect(
        a.lanes.any((l) => l.reason == finding) ||
            finding.startsWith('Described but not found: '),
        isTrue,
        reason: s.id,
      );
    }
  });

  test('Every question and Unresolved lane names its gap', () {
    for (final s in triage.submissions) {
      final a = assessment(s.id);
      final blocking = a.lane(Lane.unresolved);
      if (blocking != null) {
        expect(blocking.gap, isNotNull, reason: s.id);
        // Every blocking gap except a missing package raises its question.
        if (blocking.gap != Gap.noServerpodPackage) {
          expect(a.leadQuestion!.gap, blocking.gap, reason: s.id);
        }
      }
      for (final gap in a.unsupportedClaims) {
        expect(gap.claimed, isNotNull);
      }
    }
    // DOBY's first question is its private demo, but the one to ask first
    // is the gap that made it Unresolved.
    final doby = assessment('doby-rna2yf');
    expect(doby.questions.first.gap, Gap.demoPrivate);
    expect(doby.leadQuestion!.gap, Gap.ai);
    expect(assessment('glowcare').leadQuestion!.gap, Gap.signIn);
    expect(assessment('butler-xlrjsp').leadQuestion, isNull);
  });

  test('The query scales to a large field without changing semantics', () {
    final base = rows();
    final many = [
      for (var i = 0; i < 80; i++)
        for (final r in base) r,
    ];
    final watch = Stopwatch()..start();
    final result = TriageQuery.forLens(ReviewLens.substantial).apply(many);
    watch.stop();
    expect(
      result.length,
      80 * base.where((r) => r.assessment.inLane(Lane.substantialBuild)).length,
    );
    expect(watch.elapsedMilliseconds, lessThan(500));
  });

  test('Deep reviews are valid representations tied to triage rows', () {
    expect(competition.sponsorTech, 'Serverpod');
    expect(competition.projects.map((p) => p.id).toSet(), {
      'a3-artificial-assistant-for-anything',
      'astrea',
      'btlr-2xcw9f',
      'butler-xlrjsp',
      'butlrapp',
      'contextual-lifeflow-butler',
      'daypilot-qv2drx',
      'doby-rna2yf',
      'elderly-j462fy',
      'gitradar',
      'glowcare',
      'hushflow-a0fls4',
      'legal-lens-foazyi',
      'lifesync-ai-zm1hp4',
      'lume-zero',
      'mamacare-ufjnk7',
      'merlin-0lhx6z',
      'recodiary',
      'road-trip-butler',
      'root-radar',
      'scriptly-jpmr47',
      'social-fabric',
      'the-bolt-chef',
      'vigil-the-high-stakes-compliance-butler',
    });
    // The Hackathon refuses a representation without a triage row.
    expect(
      Hackathon(
        source: hackathonSources.last,
        competition: competition,
        triage: triage,
      ).hasRepresentation('social-fabric'),
      isTrue,
    );
    for (final p in competition.projects) {
      expect(triage.byId(p.id), isNotNull);
      expect(p.questions, isNotEmpty, reason: p.id);
      expect(
        p.sources['repo']!.revision,
        triage.byId(p.id)!.repo!.snapshotSha,
        reason: 'Repository links pin the deadline snapshot',
      );
      for (final lens in SubmissionLens.values) {
        for (final n in p.graph(lens).nodes) {
          final evidence = n.evidence!;
          expect(evidence.note.length, lessThan(140), reason: n.id);
          final frame = evidence.frame;
          if (frame != null) {
            expect(File(frame.image).existsSync(), isTrue, reason: frame.image);
            expect(frame.image, startsWith('assets/evidence/serverpod/'));
          }
        }
      }
      for (final q in p.questions.where(
        (q) => q.kind == QuestionKind.mismatch,
      )) {
        expect(
          q.anchors.map((a) => a.lens).toSet(),
          SubmissionLens.values.toSet(),
          reason: '${p.id} ${q.id}',
        );
      }
    }
    // A private demo can never support "demonstrated".
    final doby = competition.projects.singleWhere((p) => p.id == 'doby-rna2yf');
    for (final lens in SubmissionLens.values) {
      expect(
        doby.graph(lens).nodes.map((n) => n.evidence!.status),
        isNot(contains(EvidenceStatus.demonstrated)),
      );
    }
  });

  test('Generated deep reviews say how they were made', () {
    final raw = {
      for (final p
          in (jsonDecode(
                File(
                  'assets/representations/serverpod.json',
                ).readAsStringSync(),
              )['projects']
              as List))
        p['id'] as String: p as Map<String, dynamic>,
    };
    for (final p in competition.projects) {
      final origin = raw[p.id]!['origin'] as Map<String, dynamic>?;
      expect(p.generated, origin?['method'] == 'generated', reason: p.id);
      if (!p.generated) continue;
      expect(origin!['pipeline'], 'tool/deep_review');
      expect(origin['handEdited'], isFalse, reason: p.id);
      // A demo frame appears only beside a demonstrated element.
      for (final lens in SubmissionLens.values) {
        for (final n in p.graph(lens).nodes) {
          if (n.evidence!.frame != null) {
            expect(n.evidence!.status, EvidenceStatus.demonstrated);
          }
        }
      }
    }
    expect(
      competition.projects.where((p) => p.generated).map((p) => p.id),
      [
        'contextual-lifeflow-butler',
        'glowcare',
        'lifesync-ai-zm1hp4',
        'gitradar',
        'root-radar',
        'merlin-0lhx6z',
        'hushflow-a0fls4',
        'a3-artificial-assistant-for-anything',
        'astrea',
        'road-trip-butler',
        'lume-zero',
        'daypilot-qv2drx',
        'legal-lens-foazyi',
        'scriptly-jpmr47',
        'vigil-the-high-stakes-compliance-butler',
        'btlr-2xcw9f',
        'recodiary',
        'butlrapp',
        'the-bolt-chef',
        'mamacare-ufjnk7',
      ],
    );
  });

  test('Deep reviews stay readable at a glance', () {
    for (final p in competition.projects) {
      expect(p.summary.length, lessThan(160), reason: p.id);
      expect(p.mapping.length, lessThanOrEqualTo(4), reason: p.id);
      for (final m in p.mapping) {
        expect(m.label.length, lessThanOrEqualTo(40), reason: m.label);
      }
      for (final lens in SubmissionLens.values) {
        final graph = p.graph(lens);
        expect(graph.nodes.length, lessThanOrEqualTo(6), reason: p.id);
        for (final n in graph.nodes) {
          expect(n.label.length, lessThanOrEqualTo(22), reason: n.label);
          expect(n.detail.length, lessThanOrEqualTo(18), reason: n.detail);
        }
        for (final e in graph.edges) {
          expect(e.label.length, lessThanOrEqualTo(18), reason: e.label);
        }
      }
    }
  });

  test('Serverpod graphs lay out without overlapping or clipping', () {
    for (final compact in [false, true]) {
      for (final p in competition.projects) {
        for (final lens in SubmissionLens.values) {
          final layout = layoutGraph(p.graph(lens), compact: compact);
          final bounds = Offset.zero & layout.size;
          final rects = layout.nodes.values.toList();
          for (var i = 0; i < rects.length; i++) {
            expect(bounds.contains(rects[i].topLeft), isTrue);
            expect(bounds.contains(rects[i].bottomRight), isTrue);
            for (var j = i + 1; j < rects.length; j++) {
              expect(
                rects[i].overlaps(rects[j]),
                isFalse,
                reason: '${p.id} $lens compact=$compact',
              );
            }
          }
        }
      }
    }
  });

  test('Hackathon data stays isolated', () {
    final humor = parseCompetition(
      File('assets/representations/humor_genome.json').readAsStringSync(),
    );
    expect(humor.sponsorTech, 'Gemma');
    final humorIds = humor.projects.map((p) => p.id).toSet();
    expect(
      triage.submissions.map((s) => s.id).toSet().intersection(humorIds),
      isEmpty,
    );
    final assets = [
      for (final s in hackathonSources) ...[
        s.representations,
        ?s.triage,
        ?s.writeups,
      ],
    ];
    expect(assets.toSet().length, assets.length);
    expect(hackathonSources.first.triage, isNull);
  });

  test('Writeup lines load separately and match the row counts', () {
    final writeups = parseWriteups(
      File('assets/triage/serverpod_writeups.json').readAsStringSync(),
    );
    for (final s in triage.submissions) {
      final lines = writeups[s.id]!;
      final claims = lines.where(
        (l) =>
            const {'capability', 'implementation', 'outcome'}.contains(l.kind),
      );
      expect(claims.length, s.jev.claims, reason: s.id);
      for (final claim in s.jev.majorClaims) {
        expect(lines.any((l) => l.id == claim.id), isTrue);
      }
    }
  });
}
