import 'dart:math' as math;
import 'dart:ui';

import '../representation/project.dart';

class GraphLayout {
  const GraphLayout(this.size, this.nodes);
  final Size size;
  final Map<String, Rect> nodes;
  static const nodeSize = Size(184, 80);
}

/// Deterministic, topology-driven layouts. Projects supply no visual positions.
GraphLayout layoutGraph(SemanticGraph graph) {
  graph.validate();
  final ranks = <String, int>{};
  final pending = graph.nodes.map((n) => n.id).toSet();
  while (pending.isNotEmpty) {
    final ready = pending
        .where(
          (id) => graph.edges
              .where((e) => e.kind == EdgeKind.flow && e.to == id)
              .every((e) => ranks.containsKey(e.from)),
        )
        .toList();
    for (final id in ready) {
      final parents = graph.edges.where(
        (e) => e.kind == EdgeKind.flow && e.to == id,
      );
      ranks[id] = parents.fold(
        0,
        (rank, e) => math.max(rank, ranks[e.from]! + 1),
      );
      pending.remove(id);
    }
  }
  final rects = <String, Rect>{};
  void place(String id, Offset center) {
    rects[id] = Rect.fromCenter(
      center: center,
      width: GraphLayout.nodeSize.width,
      height: GraphLayout.nodeSize.height,
    );
  }

  if (graph.topology == Topology.hub || graph.topology == Topology.loop) {
    const size = Size(1100, 520);
    final center = size.center(Offset.zero);
    final orbit = graph.nodes.where((n) => n.id != graph.focus).toList();
    if (graph.focus != null) place(graph.focus!, center);
    // Loop order follows directed dependencies, not node list order.
    if (graph.topology == Topology.loop) {
      orbit.sort((a, b) => ranks[a.id]!.compareTo(ranks[b.id]!));
    }
    for (var i = 0; i < orbit.length; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / orbit.length;
      place(
        orbit[i].id,
        center + Offset(math.cos(angle) * 390, math.sin(angle) * 170),
      );
    }
    return GraphLayout(size, Map.unmodifiable(rects));
  }
  final maxRank = ranks.values.reduce(math.max);
  final groups = List.generate(
    maxRank + 1,
    (r) => graph.nodes.where((n) => ranks[n.id] == r).map((n) => n.id).toList(),
  );
  // Barycentric ordering keeps related branches together without project rules.
  for (var r = 1; r < groups.length; r++) {
    double barycenter(String id) {
      final parents = graph.edges.where(
        (e) => e.to == id && e.kind == EdgeKind.flow,
      );
      if (parents.isEmpty) return 0;
      return parents
              .map((e) => groups[ranks[e.from]!].indexOf(e.from))
              .reduce((a, b) => a + b) /
          parents.length;
    }

    final original = [...groups[r]];
    groups[r].sort((a, b) {
      final order = barycenter(a).compareTo(barycenter(b));
      return order == 0
          ? original.indexOf(a).compareTo(original.indexOf(b))
          : order;
    });
  }
  final layers = graph.topology == Topology.layers;
  final breadth = groups.map((g) => g.length).reduce(math.max);
  final size = layers
      ? Size(
          math.max(1040, breadth * 230 + 80),
          math.max(480, groups.length * 110 + 70),
        )
      : Size(
          math.max(1040, groups.length * 232 + 60),
          math.max(440, breadth * 112 + 120),
        );
  for (var r = 0; r < groups.length; r++) {
    for (var i = 0; i < groups[r].length; i++) {
      final main = (r + .5) / groups.length;
      final cross = i - (groups[r].length - 1) / 2;
      place(
        groups[r][i],
        layers
            ? Offset(
                size.width / 2 + cross * 230,
                65 + main * (size.height - 130),
              )
            : Offset(
                20 + main * (size.width - 40),
                size.height / 2 + cross * 112,
              ),
      );
    }
  }
  return GraphLayout(size, Map.unmodifiable(rects));
}

/// Normalized dimensions use the same projection in the field and minimap.
Offset projectPosition(
  ProjectRepresentation project,
  Dimension x,
  Dimension y,
  Rect field,
) => Offset(
  field.left + project.dimensions[x]! * field.width,
  field.bottom - project.dimensions[y]! * field.height,
);
