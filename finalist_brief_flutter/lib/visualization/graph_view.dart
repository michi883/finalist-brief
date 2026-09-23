import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../representation/project.dart';
import 'graph_layout.dart';

const ink = Color(0xFF263B3C);
const muted = Color(0xFF677875);
const accent = Color(0xFF26776D);
const paper = Color(0xFFF7F8F3);

extension NodeAppearance on NodeKind {
  String get label => switch (this) {
    NodeKind.human => 'HUMAN',
    NodeKind.surface => 'SURFACE',
    NodeKind.model => 'AI / MODEL',
    NodeKind.transformation => 'TRANSFORM',
    NodeKind.external => 'SYSTEM',
    NodeKind.signal => 'OBSERVED',
    NodeKind.artifact => 'ARTIFACT',
  };
  IconData get icon => switch (this) {
    NodeKind.human => Icons.person_outline,
    NodeKind.surface => Icons.web_asset_outlined,
    NodeKind.model => Icons.auto_awesome_outlined,
    NodeKind.transformation => Icons.call_split,
    NodeKind.external => Icons.dns_outlined,
    NodeKind.signal => Icons.graphic_eq,
    NodeKind.artifact => Icons.article_outlined,
  };
  Color get color => switch (this) {
    NodeKind.model => accent,
    NodeKind.human || NodeKind.signal => const Color(0xFF916223),
    _ => ink,
  };
}

class GraphView extends StatelessWidget {
  const GraphView({super.key, required this.graph});
  final SemanticGraph graph;

  @override
  Widget build(BuildContext context) {
    final layout = layoutGraph(graph);
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox.fromSize(
        size: layout.size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: GraphEdges(graph, layout)),
            ),
            for (final node in graph.nodes)
              Positioned.fromRect(
                rect: layout.nodes[node.id]!,
                child: SemanticNodeView(node: node),
              ),
          ],
        ),
      ),
    );
  }
}

class SemanticNodeView extends StatelessWidget {
  const SemanticNodeView({super.key, required this.node});
  final SemanticNode node;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${node.kind.label}: ${node.label}. ${node.detail}',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: node.kind == NodeKind.model
            ? const Color(0xFFEAF3EF)
            : Colors.white,
        border: Border.all(color: node.kind.color.withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(
          node.kind == NodeKind.human ? 26 : 9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(node.kind.icon, size: 12, color: node.kind.color),
              const SizedBox(width: 5),
              Text(
                node.kind.label,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1,
                  color: node.kind.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            node.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            node.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: muted),
          ),
        ],
      ),
    ),
  );
}

class GraphEdges extends CustomPainter {
  GraphEdges(this.graph, this.layout);
  final SemanticGraph graph;
  final GraphLayout layout;

  Offset _boundary(Rect rect, Offset toward) {
    final delta = toward - rect.center;
    final scale = math.min(
      rect.width / 2 / delta.dx.abs(),
      rect.height / 2 / delta.dy.abs(),
    );
    return rect.center + delta * scale;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < graph.edges.length; index++) {
      final edge = graph.edges[index];
      final from = layout.nodes[edge.from]!;
      final to = layout.nodes[edge.to]!;
      final feedback = edge.kind == EdgeKind.feedback;
      final path = Path();
      final radial =
          graph.topology == Topology.hub || graph.topology == Topology.loop;
      if (feedback && !radial) {
        final rail = size.height - 38 - index % 2 * 16;
        path.moveTo(from.bottomCenter.dx, from.bottomCenter.dy);
        path.cubicTo(
          from.center.dx,
          rail,
          to.center.dx,
          rail,
          to.bottomCenter.dx,
          to.bottomCenter.dy,
        );
      } else if (radial) {
        final orbitLink =
            graph.topology == Topology.hub &&
            edge.from != graph.focus &&
            edge.to != graph.focus;
        final middle = (from.center + to.center) / 2;
        final away = middle - size.center(Offset.zero);
        final delta = to.center - from.center;
        // Orbit-to-orbit links bend around the hub, never disappear behind it.
        final control = away.distance < 1
            ? middle +
                  Offset(-delta.dy, delta.dx) /
                      delta.distance *
                      size.height *
                      .42
            : middle + away * .7;
        final start = _boundary(from, orbitLink ? control : to.center);
        final end = _boundary(to, orbitLink ? control : from.center);
        path.moveTo(start.dx, start.dy);
        if (orbitLink) {
          path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
        } else if (graph.topology == Topology.loop) {
          final middle = (start + end) / 2;
          final outward = (middle - size.center(Offset.zero)) * .7;
          path.quadraticBezierTo(
            middle.dx + outward.dx,
            middle.dy + outward.dy,
            end.dx,
            end.dy,
          );
        } else {
          path.lineTo(end.dx, end.dy);
        }
      } else if (graph.topology == Topology.layers) {
        if (to.center.dy - from.center.dy > 180) {
          final start = from.centerRight;
          final end = to.centerRight;
          final rail =
              layout.nodes.values.map((r) => r.right).reduce(math.max) + 75;
          path.moveTo(start.dx, start.dy);
          path.cubicTo(rail, start.dy, rail, end.dy, end.dx, end.dy);
        } else {
          final start = from.bottomCenter;
          final end = to.topCenter;
          final mid = (start.dy + end.dy) / 2;
          path.moveTo(start.dx, start.dy);
          path.cubicTo(start.dx, mid, end.dx, mid, end.dx, end.dy);
        }
      } else {
        final start = from.centerRight;
        final end = to.centerLeft;
        path.moveTo(start.dx, start.dy);
        if ((to.center.dx - from.center.dx) > 340) {
          // Long skip edges travel above intermediate ranks.
          final rail = math.min(from.top, to.top) - 90;
          path.cubicTo(start.dx + 50, rail, end.dx - 50, rail, end.dx, end.dy);
        } else {
          final mid = (start.dx + end.dx) / 2;
          path.cubicTo(mid, start.dy, mid, end.dy, end.dx, end.dy);
        }
      }
      final paint = Paint()
        ..color = feedback ? accent : const Color(0xFFABB8B2)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      final metric = path.computeMetrics().first;
      if (feedback) {
        for (double distance = 0; distance < metric.length; distance += 10) {
          canvas.drawPath(
            metric.extractPath(distance, math.min(distance + 5, metric.length)),
            paint,
          );
        }
      } else {
        canvas.drawPath(path, paint);
      }
      final tangent = metric.getTangentForOffset(metric.length)!;
      final end = tangent.position;
      final direction = tangent.vector;
      final normal = Offset(-direction.dy, direction.dx);
      canvas.drawPath(
        Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(
            (end - direction * 8 + normal * 3.5).dx,
            (end - direction * 8 + normal * 3.5).dy,
          )
          ..lineTo(
            (end - direction * 8 - normal * 3.5).dx,
            (end - direction * 8 - normal * 3.5).dy,
          )
          ..close(),
        Paint()..color = paint.color,
      );
      if (edge.label.isNotEmpty) {
        final at = metric.getTangentForOffset(metric.length * .5)!.position;
        final label = TextPainter(
          text: TextSpan(
            text: edge.label,
            style: TextStyle(
              fontSize: 10,
              color: feedback ? accent : muted,
              backgroundColor: paper,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, at - Offset(label.width / 2, label.height + 4));
      }
    }
  }

  @override
  bool shouldRepaint(GraphEdges oldDelegate) =>
      oldDelegate.graph != graph || oldDelegate.layout != layout;
}
