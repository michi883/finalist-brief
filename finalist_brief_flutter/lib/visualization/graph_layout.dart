import 'dart:math' as math;
import 'dart:ui';

import '../representation/project.dart';

class GraphLayout {
  const GraphLayout(this.size, this.nodes, {this.vertical = false});
  final Size size;
  final Map<String, Rect> nodes;

  /// Ranks run top to bottom: always for layers, and for flows when compact.
  final bool vertical;
  static const nodeSize = Size(184, 80);
  static const compactNodeSize = Size(172, 78);
}

/// Deterministic, topology-driven layouts. Projects supply no visual positions.
/// [compact] fits a half-width panel, so Idea and Integration can be read side
/// by side: flows run top to bottom and orbits become rounder.
GraphLayout layoutGraph(SemanticGraph graph, {bool compact = false}) {
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
  final nodeSize = compact ? GraphLayout.compactNodeSize : GraphLayout.nodeSize;
  void place(String id, Offset center) {
    rects[id] = Rect.fromCenter(
      center: center,
      width: nodeSize.width,
      height: nodeSize.height,
    );
  }

  if (graph.topology == Topology.hub || graph.topology == Topology.loop) {
    final size = compact ? const Size(780, 540) : const Size(1100, 520);
    final radius = compact ? const Size(275, 190) : const Size(390, 170);
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
        center +
            Offset(
              math.cos(angle) * radius.width,
              math.sin(angle) * radius.height,
            ),
      );
    }
    return GraphLayout(size, Map.unmodifiable(rects));
  }
  final maxRank = ranks.values.reduce(math.max);
  final groups = List.generate(
    maxRank + 1,
    (r) => graph.nodes.where((n) => ranks[n.id] == r).map((n) => n.id).toList(),
  );
  final layers = graph.topology == Topology.layers;
  final vertical = layers || compact;
  final skips = graph.edges
      .where(
        (e) => e.kind == EdgeKind.flow && ranks[e.to]! - ranks[e.from]! > 1,
      )
      .toList();
  // Vertical skip edges run on a right-hand rail, so their endpoints sit
  // rightmost in their rank; otherwise an edge seems to leave a neighbor.
  final Set<String> onRail = vertical
      ? {
          for (final e in skips) ...[e.from, e.to],
        }
      : {};
  // Barycentric ordering keeps related branches together without project rules.
  for (var r = 0; r < groups.length; r++) {
    double barycenter(String id) {
      final parents = graph.edges.where(
        (e) => e.to == id && e.kind == EdgeKind.flow,
      );
      final order = parents.isEmpty
          ? 0.0
          : parents
                    .map((e) => groups[ranks[e.from]!].indexOf(e.from))
                    .reduce((a, b) => a + b) /
                parents.length;
      return order + (onRail.contains(id) ? 1000 : 0);
    }

    final original = [...groups[r]];
    groups[r].sort((a, b) {
      final order = barycenter(a).compareTo(barycenter(b));
      return order == 0
          ? original.indexOf(a).compareTo(original.indexOf(b))
          : order;
    });
  }
  final breadth = groups.map((g) => g.length).reduce(math.max);
  // Compact columns reserve side margins only for rails the graph actually
  // uses: feedback climbs on the left, rank-skipping edges run on the right.
  final left = graph.edges.any((e) => e.kind == EdgeKind.feedback) ? 96 : 24;
  final right = skips.isNotEmpty ? 125 : 24;
  const spacing = 190.0;
  final size = compact
      ? Size(
          math.max(520, left + breadth * spacing + right),
          math.max(400, groups.length * 100 + 48),
        )
      : layers
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
        compact
            ? Offset(
                left + (size.width - left - right) / 2 + cross * spacing,
                24 + main * (size.height - 48),
              )
            : layers
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
  return GraphLayout(size, Map.unmodifiable(rects), vertical: vertical);
}

/// Contain-fit of a layout into a box, shared by the graph and any overlay
/// that must line up with its nodes (hints, connectors, evidence cards).
class GraphFit {
  factory GraphFit(Size content, Size box, {double maxScale = 1.25}) {
    final scale = math.min(
      maxScale,
      math.min(box.width / content.width, box.height / content.height),
    );
    final size = content * scale;
    return GraphFit._(
      scale,
      Offset((box.width - size.width) / 2, (box.height - size.height) / 2),
      size,
    );
  }
  const GraphFit._(this.scale, this.offset, this.size);
  final double scale;
  final Offset offset;
  final Size size;
  Rect get rect => offset & size;
  Rect map(Rect r) => Rect.fromLTWH(
    offset.dx + r.left * scale,
    offset.dy + r.top * scale,
    r.width * scale,
    r.height * scale,
  );
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
