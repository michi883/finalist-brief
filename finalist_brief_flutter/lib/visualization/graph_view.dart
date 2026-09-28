import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../representation/project.dart';
import 'graph_layout.dart';

const ink = Color(0xFF263B3C);
const muted = Color(0xFF677875);
const accent = Color(0xFF26776D);
const paper = Color(0xFFF7F8F3);
const rule = Color(0xFFD4DED5);

/// Judge questions use one calm, distinct hue: attention, not alarm.
const questionColor = Color(0xFF4C5AA8);

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

/// One glyph per evidence tier, from solid (seen working) to dotted (read in).
class EvidenceGlyph extends StatelessWidget {
  const EvidenceGlyph(this.status, {super.key, this.size = 10});
  final EvidenceStatus status;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _GlyphPainter(status)),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.status);
  final EvidenceStatus status;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 - .75;
    final c = size.center(Offset.zero);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = status == EvidenceStatus.inferred ? muted : accent;
    switch (status) {
      case EvidenceStatus.demonstrated:
        canvas.drawCircle(c, r + .6, Paint()..color = accent);
      case EvidenceStatus.foundInCode:
        canvas.drawCircle(c, r, stroke);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          math.pi / 2,
          math.pi,
          true,
          Paint()..color = accent,
        );
      case EvidenceStatus.described:
        canvas.drawCircle(c, r, stroke);
      case EvidenceStatus.inferred:
        for (var i = 0; i < 8; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r),
            i * math.pi / 4,
            math.pi / 8,
            false,
            stroke,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.status != status;
}

/// How a node participates in the current focus.
enum NodeEmphasis { normal, related, selected, dimmed }

class GraphView extends StatelessWidget {
  const GraphView({
    super.key,
    required this.graph,
    this.lens,
    this.compact = false,
    this.maxScale = 1.25,
    this.emphasis = const {},
    this.dimEdges = false,
    this.onNodeTap,
    this.onNodeHover,
  });
  final SemanticGraph graph;
  final SubmissionLens? lens;
  final bool compact;

  /// Caps the fit, so graphs shown together can share one scale.
  final double maxScale;
  final Map<String, NodeEmphasis> emphasis;

  /// Fades edges that do not join two emphasized nodes.
  final bool dimEdges;
  final ValueChanged<String>? onNodeTap;
  final ValueChanged<String?>? onNodeHover;

  @override
  Widget build(BuildContext context) {
    final layout = layoutGraph(graph, compact: compact);
    return LayoutBuilder(
      builder: (context, box) {
        final fit = GraphFit(layout.size, box.biggest, maxScale: maxScale);
        return Stack(
          children: [
            Positioned.fromRect(
              rect: fit.rect,
              child: FittedBox(
                child: SizedBox.fromSize(
                  size: layout.size,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: GraphEdges(
                            graph,
                            layout,
                            dimEdges
                                ? {
                                    for (final e in emphasis.entries)
                                      if (e.value != NodeEmphasis.dimmed) e.key,
                                  }
                                : null,
                          ),
                        ),
                      ),
                      for (final node in graph.nodes)
                        Positioned.fromRect(
                          rect: layout.nodes[node.id]!,
                          child: SemanticNodeView(
                            key: lens == null
                                ? null
                                : ValueKey('node-${lens!.name}-${node.id}'),
                            node: node,
                            emphasis: emphasis[node.id] ?? NodeEmphasis.normal,
                            onTap: onNodeTap == null
                                ? null
                                : () => onNodeTap!(node.id),
                            onHover: onNodeHover == null
                                ? null
                                : (inside) =>
                                      onNodeHover!(inside ? node.id : null),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SemanticNodeView extends StatelessWidget {
  const SemanticNodeView({
    super.key,
    required this.node,
    this.emphasis = NodeEmphasis.normal,
    this.onTap,
    this.onHover,
  });
  final SemanticNode node;
  final NodeEmphasis emphasis;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHover;

  @override
  Widget build(BuildContext context) {
    final evidence = node.evidence ?? Evidence.unrecorded;
    final inferred = evidence.status == EvidenceStatus.inferred;
    final radius = BorderRadius.circular(node.kind == NodeKind.human ? 26 : 9);
    final ring = switch (emphasis) {
      NodeEmphasis.selected => Border.all(color: accent, width: 2),
      NodeEmphasis.related => Border.all(
        color: accent.withValues(alpha: .7),
        width: 1.6,
      ),
      _ =>
        inferred
            ? null
            : Border.all(color: node.kind.color.withValues(alpha: .3)),
    };
    Widget card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        // Inferred structure is drawn lighter: no fill, dotted outline.
        color: inferred
            ? paper
            : node.kind == NodeKind.model
            ? const Color(0xFFEAF3EF)
            : Colors.white,
        border: ring,
        borderRadius: radius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
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
              const Spacer(),
              Tooltip(
                message: evidence.status.label,
                child: EvidenceGlyph(evidence.status, size: 9),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            node.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: inferred ? muted : ink,
            ),
          ),
          if (node.detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              node.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: muted),
            ),
          ],
        ],
      ),
    );
    if (inferred && ring == null) {
      card = CustomPaint(
        foregroundPainter: _DottedOutline(radius, node.kind.color),
        child: card,
      );
    }
    card = AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: emphasis == NodeEmphasis.dimmed ? .3 : 1,
      child: card,
    );
    return Semantics(
      button: onTap != null,
      label:
          '${node.kind.label}: ${node.label}. '
          '${node.detail.isEmpty ? '' : '${node.detail}. '}'
          'Evidence: ${evidence.status.label}.',
      child: onTap == null
          ? card
          : MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => onHover?.call(true),
              onExit: (_) => onHover?.call(false),
              child: GestureDetector(onTap: onTap, child: card),
            ),
    );
  }
}

class _DottedOutline extends CustomPainter {
  _DottedOutline(this.radius, this.color);
  final BorderRadius radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: .45);
    final path = Path()..addRRect(radius.toRRect(Offset.zero & size));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DottedOutline oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}

class GraphEdges extends CustomPainter {
  GraphEdges(this.graph, this.layout, [this.visible]);
  final SemanticGraph graph;
  final GraphLayout layout;

  /// When set, only edges between these nodes keep full strength.
  final Set<String>? visible;

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
      if (feedback && !radial && layout.vertical) {
        // Iteration climbs a rail on the left; skips use the right.
        final rail =
            layout.nodes.values.map((r) => r.left).reduce(math.min) -
            40 -
            index % 2 * 14;
        path.moveTo(from.centerLeft.dx, from.centerLeft.dy);
        path.cubicTo(
          rail,
          from.centerLeft.dy,
          rail,
          to.centerLeft.dy,
          to.centerLeft.dx,
          to.centerLeft.dy,
        );
      } else if (feedback && !radial) {
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
      } else if (layout.vertical) {
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
      final faded =
          visible != null &&
          !(visible!.contains(edge.from) && visible!.contains(edge.to));
      final base = feedback ? accent : const Color(0xFFABB8B2);
      final paint = Paint()
        ..color = faded ? base.withValues(alpha: .25) : base
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
        // Short vertical hops leave no room above the midpoint, so their
        // labels sit beside a straight line. On a bending one, beside would
        // read as belonging to a neighbour, so the label sits on the line,
        // nearer its source and clear of markers on the target.
        final hop =
            layout.vertical &&
            !feedback &&
            !radial &&
            to.center.dy - from.center.dy <= 180;
        final straight = (to.center.dx - from.center.dx).abs() < 1;
        final bend = hop && !straight;
        final at = metric
            .getTangentForOffset(metric.length * (bend ? .35 : .5))!
            .position;
        final label = TextPainter(
          text: TextSpan(
            text: edge.label,
            style: TextStyle(
              fontSize: 10,
              color: (feedback ? accent : muted).withValues(
                alpha: faded ? .35 : 1,
              ),
              backgroundColor: paper,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final origin = bend
            ? at - Offset(label.width / 2, label.height / 2)
            : hop
            ? at + Offset(6, -label.height / 2)
            : at - Offset(label.width / 2, label.height + 4);
        if (bend) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              (origin & label.size).inflate(3),
              const Radius.circular(4),
            ),
            Paint()..color = paper,
          );
        }
        label.paint(canvas, origin);
      }
    }
  }

  // Edges are decoration; taps fall through to whatever lies beneath.
  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(GraphEdges oldDelegate) =>
      oldDelegate.graph != graph ||
      oldDelegate.layout != layout ||
      oldDelegate.visible?.length != visible?.length ||
      !(oldDelegate.visible?.containsAll(visible ?? const {}) ?? true);
}
