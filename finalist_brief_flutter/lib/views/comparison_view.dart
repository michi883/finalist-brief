import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../representation/project.dart';
import '../visualization/graph_layout.dart';
import '../visualization/graph_view.dart';
import 'inspector.dart';

enum SubmissionFocus { both, idea, integration }

/// What the judge is looking at: a node, an Idea ↔ Integration mapping, or a
/// question. The same value drives emphasis, connectors and the inspector.
sealed class Inspection {
  const Inspection();
}

class NodeInspection extends Inspection {
  const NodeInspection(this.ref);
  final GraphRef ref;
}

class MappingInspection extends Inspection {
  const MappingInspection(this.mapping);
  final Correspondence mapping;
}

class QuestionInspection extends Inspection {
  const QuestionInspection(this.question);
  final JudgeQuestion question;
}

/// Idea and Integration side by side, so the delta between what a project
/// presents and how it is built is visible at once.
class ComparisonView extends StatefulWidget {
  const ComparisonView({
    super.key,
    required this.project,
    this.focus = SubmissionFocus.both,
  });
  final ProjectRepresentation project;
  final SubmissionFocus focus;

  @override
  State<ComparisonView> createState() => ComparisonViewState();
}

class ComparisonViewState extends State<ComparisonView> {
  Inspection? _inspection;
  Inspection? _preview;

  static const _chips = 34.0;
  static const _header = 44.0;
  static const _gutter = 56.0;

  /// Closes the inspector; returns false when there was nothing to close.
  bool dismiss() {
    if (_inspection == null) return false;
    setState(() => _inspection = null);
    return true;
  }

  void _inspect(Inspection? value) => setState(() {
    _inspection = value;
    _preview = null;
  });

  @override
  void didUpdateWidget(ComparisonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project != widget.project ||
        oldWidget.focus != widget.focus) {
      _inspection = null;
      _preview = null;
    }
  }

  List<SubmissionLens> get _lenses => switch (widget.focus) {
    SubmissionFocus.both => SubmissionLens.values,
    SubmissionFocus.idea => [SubmissionLens.idea],
    SubmissionFocus.integration => [SubmissionLens.integration],
  };

  Set<GraphRef> _highlight(Inspection? inspection) => switch (inspection) {
    NodeInspection(:final ref) => widget.project.related(ref),
    MappingInspection(:final mapping) => mapping.refs,
    QuestionInspection(:final question) => {
      for (final a in question.anchors)
        if (a.isNode) a,
    },
    null => const {},
  };

  List<Correspondence> _connected(Inspection? inspection) {
    final project = widget.project;
    return switch (inspection) {
      NodeInspection(:final ref) => project.mappingFor(ref),
      MappingInspection(:final mapping) => [mapping],
      QuestionInspection(:final question) =>
        project.mapping
            .where((m) => question.anchors.any(m.refs.contains))
            .toList(),
      null => const [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final lenses = _lenses;
    final compact = lenses.length == 2;
    return LayoutBuilder(
      builder: (context, box) {
        final top = _chips + _header;
        final width = compact ? (box.maxWidth - _gutter) / 2 : box.maxWidth;
        Rect panel(SubmissionLens lens) => Rect.fromLTWH(
          lenses.indexOf(lens) * (width + _gutter),
          top,
          width,
          math.max(0, box.maxHeight - top),
        );
        final layouts = {
          for (final lens in lenses)
            lens: layoutGraph(project.graph(lens), compact: compact),
        };
        // Panels share one scale, so node size never hints that one side
        // matters more; none shrinks below natural size to match the other.
        final own = {
          for (final lens in lenses)
            lens: GraphFit(layouts[lens]!.size, panel(lens).size).scale,
        };
        final shared = own.values.reduce(math.min);
        final fits = {
          for (final lens in lenses)
            lens: GraphFit(
              layouts[lens]!.size,
              panel(lens).size,
              maxScale: math.max(shared, math.min(own[lens]!, 1.0)),
            ),
        };
        Rect? nodeRect(GraphRef ref) {
          if (!ref.isNode || !lenses.contains(ref.lens)) return null;
          return fits[ref.lens]!
              .map(layouts[ref.lens]!.nodes[ref.node]!)
              .shift(panel(ref.lens).topLeft);
        }

        final active = _inspection ?? _preview;
        final highlight = _highlight(active);
        final selected = switch (_inspection) {
          NodeInspection(:final ref) => ref,
          _ => null,
        };
        final dim = _inspection != null;
        Map<String, NodeEmphasis> emphasis(SubmissionLens lens) => {
          for (final node in project.graph(lens).nodes)
            node.id: switch (GraphRef.node(lens, node.id)) {
              final ref when ref == selected => NodeEmphasis.selected,
              final ref when highlight.contains(ref) => NodeEmphasis.related,
              _ when dim => NodeEmphasis.dimmed,
              _ => NodeEmphasis.normal,
            },
        };

        final hints = <Widget>[];
        final perNode = <GraphRef, int>{};
        for (final q in project.questions) {
          final rect = nodeRect(q.hint);
          if (rect == null) continue;
          final index = perNode.update(q.hint, (i) => i + 1, ifAbsent: () => 0);
          final chosen = switch (_inspection) {
            QuestionInspection(:final question) => question == q,
            _ => false,
          };
          hints.add(
            Positioned(
              left: rect.right - 8 + index * 22,
              top: rect.top - 12,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: dim && !chosen && !highlight.contains(q.hint)
                    ? .35
                    : 1,
                child: QuestionHint(
                  key: ValueKey('hint-${q.id}'),
                  question: q,
                  selected: chosen,
                  onTap: () => _inspect(chosen ? null : QuestionInspection(q)),
                ),
              ),
            ),
          );
        }

        final links = compact
            ? [
                for (final m in _connected(active))
                  _Link(
                    [
                      for (final id in m.idea)
                        ?nodeRect(GraphRef.node(SubmissionLens.idea, id)),
                    ],
                    [
                      for (final id in m.integration)
                        ?nodeRect(
                          GraphRef.node(SubmissionLens.integration, id),
                        ),
                    ],
                    m.evidence.status,
                  ),
              ]
            : const <_Link>[];

        Widget? inspector;
        Rect? anchor;
        var below = false;
        final maxHeight = math.max(200.0, box.maxHeight - 16);
        switch (_inspection) {
          case NodeInspection(:final ref):
            anchor = nodeRect(ref);
            inspector = NodeInspector(
              project: project,
              ref: ref,
              maxHeight: maxHeight,
              onClose: () => _inspect(null),
              onMapping: (m) => _inspect(MappingInspection(m)),
              onQuestion: (q) => _inspect(QuestionInspection(q)),
            );
          case MappingInspection(:final mapping):
            anchor = Rect.fromLTWH(
              compact ? width : 0,
              0,
              compact ? _gutter : box.maxWidth,
              _chips + 6,
            );
            below = true;
            inspector = MappingInspector(
              project: project,
              mapping: mapping,
              maxHeight: maxHeight - _chips,
              onClose: () => _inspect(null),
              onNode: (ref) => _inspect(NodeInspection(ref)),
              onQuestion: (q) => _inspect(QuestionInspection(q)),
            );
          case QuestionInspection(:final question):
            anchor =
                nodeRect(question.hint) ??
                question.anchors.map(nodeRect).nonNulls.firstOrNull;
            inspector = QuestionInspector(
              project: project,
              question: question,
              maxHeight: maxHeight,
              onClose: () => _inspect(null),
              onNode: (ref) => _inspect(NodeInspection(ref)),
            );
          case null:
        }

        final view = GestureDetector(
          key: ValueKey('${project.id}-${widget.focus.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _inspect(null),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _chips,
                child: _MappingStrip(
                  mapping: project.mapping,
                  selected: switch (_inspection) {
                    MappingInspection(:final mapping) => mapping,
                    _ => null,
                  },
                  onHover: (m) => setState(
                    () => _preview = m == null ? null : MappingInspection(m),
                  ),
                  onTap: (m) => _inspect(MappingInspection(m)),
                ),
              ),
              for (final lens in lenses)
                Positioned(
                  left: panel(lens).left,
                  width: panel(lens).width,
                  top: _chips + 6,
                  height: _header - 6,
                  child: _PanelHeader(lens, project.graph(lens)),
                ),
              if (compact)
                Positioned(
                  left: width + _gutter / 2 - .5,
                  top: top,
                  bottom: 0,
                  width: 1,
                  child: const ColoredBox(color: Color(0xFFE3E9E2)),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _Connectors(links, width + _gutter / 2),
                  ),
                ),
              ),
              for (final lens in lenses)
                Positioned.fromRect(
                  rect: panel(lens),
                  child: GraphView(
                    key: ValueKey('graph-${lens.name}'),
                    graph: project.graph(lens),
                    lens: lens,
                    compact: compact,
                    maxScale: fits[lens]!.scale,
                    emphasis: emphasis(lens),
                    dimEdges: dim,
                    onNodeTap: (id) {
                      final ref = GraphRef.node(lens, id);
                      _inspect(ref == selected ? null : NodeInspection(ref));
                    },
                    onNodeHover: (id) => setState(
                      () => _preview = id == null
                          ? null
                          : NodeInspection(GraphRef.node(lens, id)),
                    ),
                  ),
                ),
              ...hints,
              if (inspector != null)
                Positioned.fill(
                  child: CustomSingleChildLayout(
                    delegate: _Placement(
                      anchor ??
                          Rect.fromCenter(
                            center: box.biggest.center(Offset.zero),
                            width: 0,
                            height: 0,
                          ),
                      below: below,
                    ),
                    child: inspector,
                  ),
                ),
            ],
          ),
        );
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [...previous, ?current],
          ),
          child: view,
        );
      },
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader(this.lens, this.graph);
  final SubmissionLens lens;
  final SemanticGraph graph;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: lens == SubmissionLens.idea ? 'IDEA' : 'INTEGRATION',
              style: const TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            TextSpan(
              text: lens == SubmissionLens.idea
                  ? '   What the submission presents'
                  : '   How it is actually built',
              style: const TextStyle(fontSize: 11.5, color: ink),
            ),
          ],
        ),
      ),
      const SizedBox(height: 3),
      Text(
        graph.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: muted),
      ),
    ],
  );
}

/// The delta, stated once per relationship: how each part of the idea is
/// realized. Hovering previews the connection; tapping inspects it.
class _MappingStrip extends StatelessWidget {
  const _MappingStrip({
    required this.mapping,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });
  final List<Correspondence> mapping;
  final Correspondence? selected;
  final ValueChanged<Correspondence?> onHover;
  final ValueChanged<Correspondence> onTap;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        const Text(
          'HOW THE IDEA IS BUILT',
          style: TextStyle(fontSize: 9.5, letterSpacing: 1.1, color: muted),
        ),
        const SizedBox(width: 12),
        if (mapping.isEmpty)
          const Text(
            'No relationships recorded yet.',
            style: TextStyle(fontSize: 11.5, color: muted),
          ),
        for (final m in mapping)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => onHover(m),
              onExit: (_) => onHover(null),
              child: GestureDetector(
                key: ValueKey('mapping-chip-${m.label}'),
                onTap: () => onTap(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected == m
                        ? const Color(0xFFE3EDE6)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected == m ? accent : rule,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EvidenceGlyph(m.evidence.status, size: 9),
                      const SizedBox(width: 6),
                      Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: m.integration.isEmpty ? muted : ink,
                          fontStyle: m.integration.isEmpty
                              ? FontStyle.italic
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Link {
  const _Link(this.idea, this.integration, this.status);
  final List<Rect> idea;
  final List<Rect> integration;
  final EvidenceStatus status;
}

/// Idea nodes bundle through the gutter into their Integration counterparts,
/// so a many-to-one realization reads as convergence.
class _Connectors extends CustomPainter {
  _Connectors(this.links, this.gutter);
  final List<_Link> links;
  final double gutter;

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in links) {
      if (link.idea.isEmpty) continue;
      final ends = [...link.idea, ...link.integration];
      final hub = Offset(
        gutter,
        ends.map((r) => r.center.dy).reduce((a, b) => a + b) / ends.length,
      );
      final tentative =
          link.status == EvidenceStatus.inferred ||
          link.status == EvidenceStatus.described;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = accent.withValues(alpha: tentative ? .45 : .6);
      void draw(Offset a, Offset b) {
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(
            (a.dx + b.dx) / 2,
            a.dy,
            (a.dx + b.dx) / 2,
            b.dy,
            b.dx,
            b.dy,
          );
        if (!tentative) {
          canvas.drawPath(path, paint);
          return;
        }
        for (final metric in path.computeMetrics()) {
          for (double d = 0; d < metric.length; d += 6) {
            canvas.drawPath(metric.extractPath(d, d + 3), paint);
          }
        }
      }

      for (final r in link.idea) {
        draw(r.centerRight, hub);
      }
      for (final r in link.integration) {
        draw(hub, r.centerLeft);
      }
      if (link.integration.isEmpty) {
        canvas.drawCircle(hub, 6, Paint()..color = paper);
        canvas.drawCircle(hub, 6, paint);
      } else {
        canvas.drawCircle(hub, 3.5, Paint()..color = paint.color);
      }
    }
  }

  @override
  bool shouldRepaint(_Connectors oldDelegate) => true;
}

/// Places the inspector beside its anchor, on whichever side has room.
class _Placement extends SingleChildLayoutDelegate {
  _Placement(this.anchor, {this.below = false});
  final Rect anchor;
  final bool below;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    double clampX(double x) =>
        x.clamp(8.0, math.max(8.0, size.width - child.width - 8));
    double clampY(double y) =>
        y.clamp(8.0, math.max(8.0, size.height - child.height - 8));
    if (below) {
      return Offset(
        clampX(anchor.center.dx - child.width / 2),
        clampY(anchor.bottom),
      );
    }
    final right = anchor.right + 14;
    final left = anchor.left - 14 - child.width;
    final x = right + child.width <= size.width - 8
        ? right
        : left >= 8
        ? left
        : clampX(anchor.center.dx - child.width / 2);
    return Offset(x, clampY(anchor.top - 12));
  }

  @override
  bool shouldRelayout(_Placement oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.below != below;
}
