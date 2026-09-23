import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../representation/project.dart';
import '../visualization/graph_layout.dart';
import '../visualization/graph_view.dart';

class ExplorationScreen extends StatefulWidget {
  const ExplorationScreen({super.key, this.projects});
  final List<ProjectRepresentation>? projects;

  @override
  State<ExplorationScreen> createState() => _ExplorationScreenState();
}

class _ExplorationScreenState extends State<ExplorationScreen>
    with TickerProviderStateMixin {
  List<ProjectRepresentation>? _projects;
  String? _error;
  ProjectRepresentation? _selected;
  CompetitionLens? _preset = CompetitionLens.standout;
  Dimension _x = Dimension.structuralDistinctiveness;
  Dimension _y = Dimension.evidenceInspectability;
  SubmissionLens _lens = SubmissionLens.idea;
  bool _custom = false;
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );
  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  Map<String, Offset> _from = {};
  Map<String, Offset> _to = {};

  @override
  void initState() {
    super.initState();
    if (widget.projects != null) {
      _setProjects(widget.projects!);
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final projects = parseProjects(
        await rootBundle.loadString('assets/representations/humor_genome.json'),
      );
      if (mounted) setState(() => _setProjects(projects));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = 'Could not load the cached representations: $error',
        );
      }
    }
  }

  void _setProjects(List<ProjectRepresentation> projects) {
    _projects = projects;
    _to = {
      for (final p in projects)
        p.id: projectPosition(p, _x, _y, const Rect.fromLTWH(0, 0, 1, 1)),
    };
    _from = {..._to};
  }

  Offset _position(String id) => Offset.lerp(
    _from[id],
    _to[id],
    Curves.easeInOutCubic.transform(_motion.value),
  )!;

  void _axes(Dimension x, Dimension y, CompetitionLens? preset) {
    setState(() {
      _from = {for (final p in _projects!) p.id: _position(p.id)};
      _x = x;
      _y = y;
      _preset = preset;
      _to = {
        for (final p in _projects!)
          p.id: projectPosition(p, x, y, const Rect.fromLTWH(0, 0, 1, 1)),
      };
      _motion.forward(from: 0);
    });
  }

  void _open(ProjectRepresentation project) {
    // Freeze an in-flight preset at its destination before zooming; the field
    // remains animated until then, so its return position is unambiguous.
    _motion.value = 1;
    setState(() => _selected = project);
    _zoom.forward();
  }

  Future<void> _back() async {
    if (_selected == null) return;
    await _zoom.reverse();
    if (mounted && _zoom.isDismissed) setState(() => _selected = null);
  }

  @override
  void dispose() {
    _motion.dispose();
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = _projects;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _back();
              return null;
            },
          ),
        },
        child: Scaffold(
          backgroundColor: paper,
          body: SafeArea(
            child: projects == null
                ? Center(
                    child: _error == null
                        ? const CircularProgressIndicator()
                        : Text(_error!),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Desktop is the target; smaller windows retain a usable scrollable canvas.
                      final width = math.max(820.0, constraints.maxWidth);
                      final height = math.max(800.0, constraints.maxHeight);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: width,
                          child: SingleChildScrollView(
                            child: SizedBox(
                              height: height,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  width > 1100 ? 48 : 24,
                                  24,
                                  width > 1100 ? 48 : 24,
                                  16,
                                ),
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([_motion, _zoom]),
                                  builder: (context, _) => _content(projects),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _content(List<ProjectRepresentation> projects) {
    final selected = _selected;
    final t = Curves.easeInOutCubic.transform(_zoom.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              const Icon(Icons.bubble_chart_outlined, color: accent, size: 22),
              const SizedBox(width: 9),
              const Text(
                'FINALIST BRIEF',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 24),
              if (selected != null)
                TextButton.icon(
                  key: const ValueKey('back-to-competition'),
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Competition'),
                )
              else
                const Text(
                  'Humor Genome / Build with Gemma',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              const Spacer(),
              const Text(
                'CACHED STUDY  /  06 SUBMISSIONS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 23),
        SizedBox(
          height: 86,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Align(
                    key: ValueKey(selected?.id),
                    alignment: Alignment.topLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected?.title ??
                              'Six projects. Different ways to see them.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 29,
                            height: 1.15,
                            letterSpacing: -.8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          selected == null
                              ? 'Choose a lens. Follow what stands out. Move inside a submission.'
                              : '${selected.creator}  ·  ${selected.graph(_lens).description}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (selected != null) ...[
                const SizedBox(width: 28),
                _minimap(projects, selected),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: selected == null
              ? Row(
                  children: [
                    for (final preset in CompetitionLens.values) ...[
                      ChoiceChip(
                        label: Text(preset.label),
                        labelStyle: const TextStyle(fontSize: 12),
                        selected: _preset == preset,
                        showCheckmark: false,
                        onSelected: (_) {
                          _custom = false;
                          _axes(preset.x, preset.y, preset);
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() => _custom = !_custom),
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Custom axes'),
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Text(
                      'SUBMISSION LENS',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: muted,
                      ),
                    ),
                    const SizedBox(width: 18),
                    for (final lens in SubmissionLens.values) ...[
                      ChoiceChip(
                        key: ValueKey('lens-${lens.name}'),
                        label: Text(
                          lens == SubmissionLens.idea ? 'Idea' : 'Integration',
                        ),
                        selected: _lens == lens,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _lens = lens),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    const Text(
                      'Same project, another structure',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
        ),
        SizedBox(
          height: 62,
          child: _custom && selected == null
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      _axisControl('X', _x, (d) => _axes(d, _y, null)),
                      const SizedBox(width: 18),
                      _axisControl('Y', _y, (d) => _axes(_x, d, null)),
                    ],
                  ),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    selected == null
                        ? '${_x.description}  /  ${_y.description}'
                        : selected.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, box) {
                final field = Rect.fromLTRB(
                  85,
                  45,
                  box.maxWidth - 115,
                  box.maxHeight - 64,
                );
                Offset point(String id) {
                  final p = _position(id);
                  return Offset(
                    field.left + p.dx * field.width,
                    field.top + p.dy * field.height,
                  );
                }

                final center = Offset(box.maxWidth / 2, box.maxHeight / 2);
                final origin = selected == null ? center : point(selected.id);
                final travel = Curves.easeInOut.transform(
                  ((t - .12) / .88).clamp(0, 1),
                );
                final aperture = Offset.lerp(origin, center, travel)!;
                final labels = _labelPositions(projects, point, box.biggest);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _FieldPainter(field, 1 - t)),
                    ),
                    Positioned(
                      left: 12,
                      top: 7,
                      child: Opacity(
                        opacity: 1 - t,
                        child: Text(
                          '↑  ${_y.label}',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 8,
                      child: Opacity(
                        opacity: 1 - t,
                        child: Text(
                          '${_x.label}  →',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                    ),
                    for (final p in projects) ...[
                      Positioned(
                        left:
                            (point(p.id) + (point(p.id) - origin) * t * .5).dx -
                            18,
                        top:
                            (point(p.id) + (point(p.id) - origin) * t * .5).dy -
                            18,
                        child: IgnorePointer(
                          ignoring: selected != null || _motion.isAnimating,
                          child: Opacity(
                            opacity: 1 - t,
                            child: Tooltip(
                              message: p.summary,
                              child: Semantics(
                                button: true,
                                label: 'Explore ${p.title}',
                                child: InkResponse(
                                  key: ValueKey('dot-${p.id}'),
                                  onTap: () => _open(p),
                                  radius: 24,
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Center(
                                      child: Container(
                                        width: 15,
                                        height: 15,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: labels[p.id]!,
                        child: IgnorePointer(
                          ignoring: selected != null || _motion.isAnimating,
                          child: Opacity(
                            opacity: (1 - t * 2).clamp(0, 1),
                            child: TextButton(
                              style: TextButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                foregroundColor: ink,
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onPressed: () => _open(p),
                              child: Text(p.title, maxLines: 1),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (selected != null && t > 0 && t < 1)
                      Positioned(
                        left: aperture.dx - (8 + t * box.maxWidth * .6),
                        top: aperture.dy - (8 + t * box.maxWidth * .6),
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: (1 - t).clamp(0, 1),
                            child: Container(
                              width: 16 + t * box.maxWidth * 1.2,
                              height: 16 + t * box.maxWidth * 1.2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color.lerp(
                                  accent,
                                  const Color(0xFFE3EDE6),
                                  (t * 3).clamp(0, 1),
                                ),
                                border: Border.all(
                                  color: accent.withValues(alpha: .2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (selected != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: t < 1,
                          child: Opacity(
                            opacity: ((t - .25) / .65).clamp(0, 1),
                            child: Transform.translate(
                              offset: (origin - center) * (1 - travel),
                              child: Transform.scale(
                                scale: .025 + .975 * t,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 420),
                                  child: GraphView(
                                    key: ValueKey(
                                      '${selected.id}-${_lens.name}',
                                    ),
                                    graph: selected.graph(_lens),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 70,
          child: selected != null
              ? Column(
                  children: [
                    Row(
                      children: [
                        for (final kind
                            in selected
                                .graph(_lens)
                                .nodes
                                .map((n) => n.kind)
                                .toSet()) ...[
                          Icon(kind.icon, size: 13, color: kind.color),
                          const SizedBox(width: 5),
                          Text(
                            kind.label.toLowerCase(),
                            style: const TextStyle(fontSize: 10, color: muted),
                          ),
                          const SizedBox(width: 17),
                        ],
                        const Spacer(),
                        const Text(
                          'Dashed arrows = iteration',
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _projectStrip(projects, selected),
                  ],
                )
              : const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'A field of relationships. Change the lens to see a different arrangement.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFDCE3DA)),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: Text(
                selected == null
                    ? 'Descriptive dimensions, not judge scores. Top-right means more of these two traits.'
                    : 'Manually mapped from cached submission descriptions and analyses.',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ),
            Text(
              selected == null
                  ? 'Select a dot to explore ↗'
                  : 'Esc to return to the field',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _axisControl(
    String label,
    Dimension value,
    ValueChanged<Dimension> change,
  ) => Expanded(
    child: DropdownButtonFormField<Dimension>(
      key: ValueKey('$label-${value.name}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '$label axis',
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final d in Dimension.values)
          DropdownMenuItem(
            value: d,
            child: Tooltip(
              message: d.description,
              child: Text(d.label, style: const TextStyle(fontSize: 12)),
            ),
          ),
      ],
      onChanged: (d) {
        if (d != null) change(d);
      },
    ),
  );

  Widget _minimap(
    List<ProjectRepresentation> projects,
    ProjectRepresentation selected,
  ) => SizedBox(
    width: 158,
    height: 83,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_preset?.label ?? 'Custom'} · competition',
          style: const TextStyle(fontSize: 10, color: muted),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD4DED5)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Stack(
              children: [
                for (final p in projects)
                  Positioned(
                    left: 8 + _position(p.id).dx * 112,
                    top: 2 + _position(p.id).dy * 32,
                    child: Tooltip(
                      message: p.title,
                      child: Semantics(
                        button: true,
                        label: 'Jump to ${p.title}',
                        child: InkResponse(
                          onTap: () => _open(p),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: Center(
                              child: Container(
                                width: selected.id == p.id ? 10 : 6,
                                height: selected.id == p.id ? 10 : 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected.id == p.id
                                      ? accent
                                      : const Color(0xFFB6C6BD),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _projectStrip(
    List<ProjectRepresentation> projects,
    ProjectRepresentation selected,
  ) => SizedBox(
    height: 38,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        const Center(
          child: Text(
            'EXPLORE NEXT',
            style: TextStyle(fontSize: 9, letterSpacing: 1.2, color: muted),
          ),
        ),
        const SizedBox(width: 16),
        for (final p in projects)
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: TextButton(
              key: ValueKey('jump-${p.id}'),
              onPressed: () => _open(p),
              style: TextButton.styleFrom(
                backgroundColor: selected.id == p.id
                    ? const Color(0xFFE3EDE6)
                    : null,
                foregroundColor: selected.id == p.id ? accent : muted,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: Text(p.title),
            ),
          ),
      ],
    ),
  );
}

Map<String, Rect> _labelPositions(
  List<ProjectRepresentation> projects,
  Offset Function(String) point,
  Size size,
) {
  final labels = <String, Rect>{};
  final dots = projects
      .map((p) => Rect.fromCircle(center: point(p.id), radius: 18))
      .toList();
  for (final p in projects) {
    final at = point(p.id);
    final width = math.min(184.0, p.title.length * 7.0 + 16);
    final candidates = [
      Offset(18, -17),
      Offset(18, 8),
      Offset(-width - 18, -17),
      Offset(-width / 2, -47),
      Offset(-width / 2, 19),
    ];
    Rect? best;
    var least = double.infinity;
    for (final delta in candidates) {
      final rect = Rect.fromLTWH(
        (at.dx + delta.dx).clamp(4, size.width - width - 4),
        (at.dy + delta.dy).clamp(28, size.height - 50),
        width,
        34,
      );
      final penalty = [...labels.values, ...dots].fold(0.0, (sum, obstacle) {
        final overlap = rect.intersect(obstacle);
        return sum + (overlap.isEmpty ? 0 : overlap.width * overlap.height);
      });
      if (penalty < least) {
        least = penalty;
        best = rect;
      }
    }
    labels[p.id] = best!;
  }
  return labels;
}

class _FieldPainter extends CustomPainter {
  _FieldPainter(this.field, this.opacity);
  final Rect field;
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFC5D1C8).withValues(alpha: .5 * opacity);
    for (double x = field.left; x <= field.right; x += 28) {
      for (double y = field.top; y <= field.bottom; y += 28) {
        canvas.drawCircle(Offset(x, y), .8, grid);
      }
    }
    final line = Paint()
      ..color = const Color(0xFFC5D1C8).withValues(alpha: opacity)
      ..strokeWidth = 1;
    canvas.drawLine(field.topLeft, field.bottomLeft, line);
    canvas.drawLine(field.bottomLeft, field.bottomRight, line);
  }

  @override
  bool shouldRepaint(_FieldPainter oldDelegate) =>
      oldDelegate.field != field || oldDelegate.opacity != opacity;
}
