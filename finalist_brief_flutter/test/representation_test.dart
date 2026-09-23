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
  final projects = parseProjects(source);
  ProjectRepresentation project(String id) =>
      projects.singleWhere((p) => p.id == id);

  test(
    'Only the six requested contestants are included and credited to source data',
    () {
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
        expect(p.dimensions.length, 7);
        expect(p.dimensionNotes.values, everyElement(isNotEmpty));
      }
    },
  );

  test(
    'Preset axes match the product contract; every switch moves all six',
    () {
      expect(CompetitionLens.values.map((p) => [p.x, p.y]), [
        [Dimension.structuralDistinctiveness, Dimension.evidenceInspectability],
        [Dimension.humanWorldGrounding, Dimension.interactionDepth],
        [Dimension.systemOrchestration, Dimension.creativeScope],
        [Dimension.audienceCentrality, Dimension.humanWorldGrounding],
      ]);
      for (final p in projects) {
        final positions = CompetitionLens.values
            .map(
              (lens) => projectPosition(
                p,
                lens.x,
                lens.y,
                const Rect.fromLTWH(0, 0, 100, 100),
              ),
            )
            .toSet();
        expect(positions.length, 4, reason: p.title);
      }
    },
  );

  test(
    'Projection preserves ordering, inverts screen Y, and supports same-axis custom views',
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
    'Every graph lays out deterministically without overlapping or clipping nodes',
    () {
      for (final p in projects) {
        for (final lens in SubmissionLens.values) {
          final graph = p.graph(lens);
          final layout = layoutGraph(graph);
          expect(layout.nodes, layoutGraph(graph).nodes);
          final bounds = Offset.zero & layout.size;
          for (final rect in layout.nodes.values) {
            expect(
              bounds.contains(rect.topLeft),
              isTrue,
              reason: '${p.id} $lens',
            );
            expect(
              bounds.contains(rect.bottomRight),
              isTrue,
              reason: '${p.id} $lens',
            );
          }
          final rects = layout.nodes.values.toList();
          for (var i = 0; i < rects.length; i++) {
            for (var j = i + 1; j < rects.length; j++) {
              expect(
                rects[i].overlaps(rects[j]),
                isFalse,
                reason: '${p.id} $lens',
              );
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
    expect(
      why.nodes.singleWhere((n) => n.id == 'observed').kind,
      NodeKind.signal,
    );
    expect(why.edges.where((e) => e.kind == EdgeKind.feedback), hasLength(1));
    final laugh = project('laughlensai').idea;
    expect(
      laugh.nodes.singleWhere((n) => n.id == 'people').kind,
      NodeKind.human,
    );
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

  test(
    'Invalid dimensions and dangling graph relationships fail at the data boundary',
    () {
      final raw = jsonDecode(source) as Map<String, dynamic>;
      raw['projects'][0]['competitionDimensions']['creativeScope']['value'] =
          1.2;
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
