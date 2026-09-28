import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:finalist_brief_flutter/representation/project.dart';
import 'package:finalist_brief_flutter/visualization/graph_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'assets/representations/humor_genome.json',
  ).readAsStringSync();
  final competition = parseCompetition(source);
  final projects = competition.projects;
  ProjectRepresentation project(String id) =>
      projects.singleWhere((p) => p.id == id);
  Iterable<(ProjectRepresentation, SubmissionLens, SemanticNode)> nodes() => [
    for (final p in projects)
      for (final lens in SubmissionLens.values)
        for (final n in p.graph(lens).nodes) (p, lens, n),
  ];

  test(
    'Only the six requested contestants are included and credited to source data',
    () {
      expect(competition.sponsorTech, 'Gemma');
      expect(projects.map((p) => p.id).toSet(), {
        'crowdwork-copilot',
        'humor-genome-studio',
        'killjoy',
        'laughlensai',
        'room-sense-text',
        'why-they-laugh',
      });
      final originals =
          jsonDecode(
                File(
                  '../finalist_brief_server/assets/humor_genome/submissions.json',
                ).readAsStringSync(),
              )
              as List;
      for (final p in projects) {
        final original = originals.singleWhere((s) => s['slug'] == p.id);
        expect(p.creator, original['creator']);
        expect(p.summary, original['summary']);
        expect(p.dimensions.length, Dimension.values.length);
        expect(p.dimensionNotes.values, everyElement(isNotEmpty));
      }
    },
  );

  test('Two competition modes match the product contract', () {
    expect(CompetitionLens.values.map((m) => [m.x, m.y]), [
      [Dimension.integrationDepth, Dimension.ideaDistinctiveness],
      [Dimension.sponsorCentrality, Dimension.sponsorEvidence],
    ]);
    expect(Dimension.sponsorCentrality.label('Gemma'), 'Gemma centrality');
    expect(
      CompetitionLens.sponsorTech.question('Gemma'),
      contains('important is Gemma'),
    );
    for (final mode in CompetitionLens.values) {
      expect(mode.corners, hasLength(4));
    }
    // Switching modes moves every project.
    for (final p in projects) {
      final positions = CompetitionLens.values
          .map(
            (mode) => projectPosition(
              p,
              mode.x,
              mode.y,
              const Rect.fromLTWH(0, 0, 100, 100),
            ),
          )
          .toSet();
      expect(positions.length, 2, reason: p.title);
    }
  });

  test(
    'Projection preserves ordering, inverts screen Y, and supports same-axis views',
    () {
      final p = projects.first;
      const area = Rect.fromLTWH(40, 80, 200, 300);
      for (final d in Dimension.values) {
        final at = projectPosition(p, d, d, area);
        expect(
          (at.dx - area.left) / area.width,
          closeTo((area.bottom - at.dy) / area.height, .00001),
        );
      }
    },
  );

  test(
    'Every graph lays out deterministically, wide and compact, without overlapping or clipping nodes',
    () {
      for (final compact in [false, true]) {
        for (final p in projects) {
          for (final lens in SubmissionLens.values) {
            final graph = p.graph(lens);
            final layout = layoutGraph(graph, compact: compact);
            final reason = '${p.id} $lens compact=$compact';
            expect(
              layout.nodes,
              layoutGraph(graph, compact: compact).nodes,
              reason: reason,
            );
            final bounds = Offset.zero & layout.size;
            for (final rect in layout.nodes.values) {
              expect(bounds.contains(rect.topLeft), isTrue, reason: reason);
              expect(bounds.contains(rect.bottomRight), isTrue, reason: reason);
            }
            final rects = layout.nodes.values.toList();
            for (var i = 0; i < rects.length; i++) {
              for (var j = i + 1; j < rects.length; j++) {
                expect(rects[i].overlaps(rects[j]), isFalse, reason: reason);
              }
            }
            // Side by side, flows read top to bottom to fit a half-width panel.
            if (compact && graph.topology == Topology.flow) {
              expect(layout.vertical, isTrue, reason: reason);
            }
            // Rank-skipping edges use the right-hand rail, so both ends must
            // be rightmost in their row or the edge appears to leave a neighbor.
            if (layout.vertical) {
              bool rightmost(Rect r) => layout.nodes.values
                  .where((o) => o.center.dy == r.center.dy)
                  .every((o) => o.right <= r.right);
              for (final e in graph.edges) {
                final from = layout.nodes[e.from]!;
                final to = layout.nodes[e.to]!;
                if (e.kind == EdgeKind.flow &&
                    to.center.dy - from.center.dy > 180) {
                  expect(
                    rightmost(from) && rightmost(to),
                    isTrue,
                    reason: '$reason ${e.from}>${e.to}',
                  );
                }
              }
            }
          }
        }
      }
    },
  );

  test('Idea graphs retain the essential semantic differences', () {
    expect(project('crowdwork-copilot').idea.topology, Topology.loop);
    final studio = project('humor-genome-studio').idea;
    expect(studio.edges.where((e) => e.from == studio.focus).length, 6);
    final room = project('room-sense-text').idea;
    expect(room.edges.where((e) => e.from == 'joke').length, 4);
    expect(room.edges.where((e) => e.to == 'compare').length, 4);
    final why = project('why-they-laugh').idea;
    expect(why.node('observed').kind, NodeKind.signal);
    expect(why.edges.where((e) => e.kind == EdgeKind.feedback), hasLength(1));
    final laugh = project('laughlensai').idea;
    expect(laugh.node('people').kind, NodeKind.human);
    expect(laugh.edges.where((e) => e.to == 'compare'), hasLength(2));
    expect(
      project('killjoy').idea.edges.where((e) => e.from == 'reading'),
      hasLength(3),
    );
    expect(
      projects.map((p) => p.integration.topology).toSet().length,
      greaterThan(1),
    );
    for (final p in projects) {
      expect(
        p.idea.nodes.map((n) => n.label).join(),
        isNot(p.integration.nodes.map((n) => n.label).join()),
      );
    }
  });

  test('Every node explains why it exists, and every frame is bundled', () {
    for (final (p, lens, n) in nodes()) {
      final evidence = n.evidence;
      expect(evidence, isNotNull, reason: '${p.id} ${lens.name}.${n.id}');
      expect(evidence!.note.length, lessThan(140), reason: n.id);
      final frame = evidence.frame;
      if (frame != null) {
        expect(File(frame.image).existsSync(), isTrue, reason: frame.image);
        expect(p.sources[frame.ref.source], isNotNull);
      }
    }
    final statuses = nodes().map((e) => e.$3.evidence!.status).toSet();
    // The dataset exercises every tier, including structure Finalist Brief
    // inferred and must not present as verified.
    expect(statuses, EvidenceStatus.values.toSet());
  });

  test('A status can never claim more than its sources support', () {
    final raw = jsonDecode(source) as Map<String, dynamic>;
    final node = raw['projects'][1]['idea']['nodes'][1] as Map;
    node['evidence'] = {
      'status': 'demonstrated',
      'note': 'Shown in the writeup.',
      'refs': [
        {'source': 'writeup'},
      ],
    };
    expect(() => parseProjects(jsonEncode(raw)), throwsFormatException);
    node['evidence'] = {
      'status': 'foundInCode',
      'note': 'Somewhere in the repo.',
      'refs': [
        {'source': 'repo'},
      ],
    };
    expect(() => parseProjects(jsonEncode(raw)), throwsFormatException);
    node['evidence'] = {
      'status': 'described',
      'note': 'Cites a missing source.',
      'refs': [
        {'source': 'nowhere'},
      ],
    };
    expect(() => parseProjects(jsonEncode(raw)), throwsFormatException);
  });

  test('Questions come from anchored gaps, and mismatches span both views', () {
    for (final p in projects) {
      expect(p.questions, isNotEmpty, reason: p.id);
      for (final q in p.questions) {
        expect(q.hint.isNode, isTrue);
        expect(q.question.trim(), endsWith('?'));
        expect(q.basis, isNotEmpty);
        if (q.kind == QuestionKind.mismatch) {
          expect(
            q.anchors.map((a) => a.lens).toSet(),
            SubmissionLens.values.toSet(),
            reason: '${p.id} ${q.id}',
          );
        }
      }
    }
    final room = project('room-sense-text');
    final audiences = room.questions.singleWhere(
      (q) => q.id == 'four-audiences',
    );
    expect(audiences.kind, QuestionKind.mismatch);
    expect(
      audiences.question,
      'These four audiences appear to use the same model. What mechanism keeps their behavior meaningfully distinct?',
    );
  });

  test('Mappings expose the delta between Idea and Integration', () {
    final room = project('room-sense-text');
    final rooms = room.mapping.singleWhere((m) => m.idea.length == 4);
    expect(rooms.integration, contains('runtime'));
    final studio = project('humor-genome-studio');
    expect(
      studio.mapping.any((m) => m.idea.length == 6 && m.integration.isNotEmpty),
      isTrue,
    );
    // "No counterpart" is recorded explicitly, never implied by omission.
    expect(
      projects.expand((p) => p.mapping).where((m) => m.integration.isEmpty),
      isNotEmpty,
    );
    const audience = GraphRef.node(SubmissionLens.idea, 'room2');
    expect(
      room.related(audience),
      containsAll(const [
        GraphRef.node(SubmissionLens.integration, 'runtime'),
        GraphRef.node(SubmissionLens.idea, 'room4'),
      ]),
    );
  });

  test(
    'Relationships carry the same evidence model and can anchor questions',
    () {
      final why = project('why-they-laugh');
      final loop = why.idea.edges.singleWhere(
        (e) => e.kind == EdgeKind.feedback,
      );
      expect(loop.evidence?.status, EvidenceStatus.described);
      expect(
        why.questions.expand((q) => q.anchors).where((a) => !a.isNode),
        contains(
          const GraphRef.edge(SubmissionLens.idea, 'revise', 'performance'),
        ),
      );
    },
  );

  test(
    'Invalid dimensions and dangling relationships fail at the data boundary',
    () {
      Map<String, dynamic> fresh() =>
          jsonDecode(source) as Map<String, dynamic>;
      var raw = fresh();
      raw['projects'][0]['competitionDimensions']['sponsorEvidence']['value'] =
          1.2;
      expect(() => parseProjects(jsonEncode(raw)), throwsFormatException);
      raw = fresh();
      raw['projects'][0]['questions'][0]['anchors'][0]['node'] = 'missing';
      expect(() => parseProjects(jsonEncode(raw)), throwsFormatException);
      raw = fresh();
      raw['projects'][0]['mapping'][0]['integration'] = ['missing'];
      expect(() => parseProjects(jsonEncode(raw)), throwsFormatException);
      const node = SemanticNode('a', 'A', NodeKind.artifact, '');
      expect(
        () => const SemanticGraph(
          topology: Topology.flow,
          description: '',
          nodes: [node],
          edges: [SemanticEdge('a', 'missing')],
        ).validate(),
        throwsFormatException,
      );
      const other = SemanticNode('b', 'B', NodeKind.artifact, '');
      expect(
        () => const SemanticGraph(
          topology: Topology.flow,
          description: '',
          nodes: [node, other],
          edges: [SemanticEdge('a', 'b'), SemanticEdge('b', 'a')],
        ).validate(),
        throwsFormatException,
      );
      expect(
        () => const SemanticGraph(
          topology: Topology.flow,
          description: '',
          nodes: [node, other],
          edges: [
            SemanticEdge('a', 'b'),
            SemanticEdge('b', 'a', kind: EdgeKind.feedback),
          ],
        ).validate(),
        returnsNormally,
      );
    },
  );
}
