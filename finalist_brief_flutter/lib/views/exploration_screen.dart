import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../representation/project.dart';
import '../visualization/graph_layout.dart';
import '../visualization/graph_view.dart';
import 'comparison_view.dart';
import 'inspector.dart';

class ExplorationScreen extends StatefulWidget {
  const ExplorationScreen({
    super.key,
    this.competition,
    this.navigation,
    this.active = true,
    this.scopeLabel,
  });
  final Competition? competition;

  /// Hackathon and workspace controls, shown beside the brand.
  final Widget? navigation;

  /// Whether this screen is the visible one; it reclaims keyboard focus when
  /// it becomes visible again, so Esc keeps working after a switch.
  final bool active;

  /// Replaces the default `CACHED STUDY / NN SUBMISSIONS` label.
  final String? scopeLabel;

  @override
  State<ExplorationScreen> createState() => ExplorationScreenState();
}

const _counts = [
  'Zero',
  'One',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Eleven',
  'Twelve',
  'Thirteen',
  'Fourteen',
  'Fifteen',
  'Sixteen',
  'Seventeen',
  'Eighteen',
  'Nineteen',
  'Twenty',
];

/// Below this window width, a screen with navigation shows only the icon.
const brandBreakpoint = 1200.0;

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.bubble_chart_outlined, color: accent, size: 22),
      if (!compact) ...[
        const SizedBox(width: 9),
        const Text(
          'FINALIST BRIEF',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ],
  );
}

/// `6` → `Six`; larger numbers stay numeric.
String countWord(int n) => n < _counts.length ? _counts[n] : '$n';

class ExplorationScreenState extends State<ExplorationScreen>
    with TickerProviderStateMixin {
  Competition? _competition;
  String? _error;
  ProjectRepresentation? _selected;
  CompetitionLens _mode = CompetitionLens.ideaIntegration;
  SubmissionFocus _focus = SubmissionFocus.both;
  final _comparison = GlobalKey<ComparisonViewState>();
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
  final _keyboard = FocusNode(debugLabel: 'exploration');

  String get _sponsor => _competition?.sponsorTech ?? 'Sponsor tech';

  @override
  void initState() {
    super.initState();
    if (widget.competition != null) {
      _setCompetition(widget.competition!);
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final competition = parseCompetition(
        await rootBundle.loadString('assets/representations/humor_genome.json'),
      );
      if (mounted) setState(() => _setCompetition(competition));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = 'Could not load the cached representations: $error',
        );
      }
    }
  }

  Map<String, Offset> _placements(CompetitionLens mode) => {
    for (final p in _competition!.projects)
      p.id: projectPosition(p, mode.x, mode.y, const Rect.fromLTWH(0, 0, 1, 1)),
  };

  void _setCompetition(Competition competition) {
    _competition = competition;
    _to = _placements(_mode);
    _from = {..._to};
  }

  @override
  void didUpdateWidget(ExplorationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final competition = widget.competition;
    if (competition != null && competition != oldWidget.competition) {
      // A new comparison set keeps the mode; a project that left the set
      // closes without animation so the field is never left half-zoomed.
      final ids = competition.projects.map((p) => p.id).toSet();
      if (_selected != null && !ids.contains(_selected!.id)) {
        _selected = null;
        _zoom.value = 0;
      } else if (_selected != null) {
        _selected = competition.projects.singleWhere(
          (p) => p.id == _selected!.id,
        );
      }
      _motion.value = 1;
      _setCompetition(competition);
    }
    if (widget.active && !oldWidget.active) _keyboard.requestFocus();
  }

  /// Zooms into [id] from the field, as if its dot had been selected.
  void openProject(String id) {
    final project = _competition?.projects.where((p) => p.id == id).firstOrNull;
    if (project != null) _open(project);
  }

  Offset _position(String id) => Offset.lerp(
    _from[id],
    _to[id],
    Curves.easeInOutCubic.transform(_motion.value),
  )!;

  void _switchMode(CompetitionLens mode) {
    setState(() {
      _from = {for (final p in _competition!.projects) p.id: _position(p.id)};
      _mode = mode;
      _to = _placements(mode);
      _motion.forward(from: 0);
    });
  }

  void _open(ProjectRepresentation project) {
    // Freeze an in-flight mode switch at its destination before zooming; the
    // field remains animated until then, so its return position is unambiguous.
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
    _keyboard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final competition = _competition;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              // Close the inspector first; a second Esc leaves the project.
              if (!(_comparison.currentState?.dismiss() ?? false)) _back();
              return null;
            },
          ),
        },
        // Keeps keyboard focus inside the shortcuts, so Esc works even when
        // the judge has only clicked non-focusable nodes.
        child: Focus(
          focusNode: _keyboard,
          autofocus: widget.active,
          child: Scaffold(
            backgroundColor: paper,
            body: SafeArea(
              child: competition == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : Text(_error!),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Desktop is the target; smaller windows retain a usable scrollable canvas.
                        final width = math.max(960.0, constraints.maxWidth);
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
                                    20,
                                    width > 1100 ? 48 : 24,
                                    14,
                                  ),
                                  child: AnimatedBuilder(
                                    animation: Listenable.merge([
                                      _motion,
                                      _zoom,
                                    ]),
                                    builder: (context, _) =>
                                        _content(competition, width),
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
      ),
    );
  }

  Widget _content(Competition competition, double width) {
    final projects = competition.projects;
    final selected = _selected;
    final t = Curves.easeInOutCubic.transform(_zoom.value);
    // Every row keeps its height in both views, so the field never moves
    // underneath the zoom.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              // Navigation takes the wordmark's room in narrower windows.
              BrandMark(
                compact: widget.navigation != null && width < brandBreakpoint,
              ),
              const SizedBox(width: 24),
              if (widget.navigation != null) ...[
                widget.navigation!,
                const SizedBox(width: 20),
              ],
              if (selected != null)
                TextButton.icon(
                  key: const ValueKey('back-to-competition'),
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Competition'),
                )
              else
                Flexible(
                  child: Text(
                    competition.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.scopeLabel ??
                      'CACHED STUDY  /  ${projects.length.toString().padLeft(2, '0')} SUBMISSIONS',
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                selected?.title ??
                                    '${countWord(projects.length)} projects. What they claim, and what stands behind it.',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 27,
                                  height: 1.15,
                                  letterSpacing: -.8,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (selected?.generated ?? false) ...[
                              const SizedBox(width: 14),
                              const _GeneratedTag(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selected == null
                              ? 'Read the field, open a project, compare its idea with its build, and inspect why each part is there.'
                              : '${selected.creator}  ·  ${selected.summary}',
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
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: selected == null
              ? Row(
                  children: [
                    for (final mode in CompetitionLens.values) ...[
                      ChoiceChip(
                        key: ValueKey('mode-${mode.name}'),
                        label: Text(
                          mode == CompetitionLens.sponsorTech
                              ? '${mode.label} · $_sponsor'
                              : mode.label,
                        ),
                        labelStyle: const TextStyle(fontSize: 12),
                        selected: _mode == mode,
                        showCheckmark: false,
                        onSelected: (_) => _switchMode(mode),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _mode.question(_sponsor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 12.5),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    for (final (focus, label) in [
                      (SubmissionFocus.both, 'Side by side'),
                      (SubmissionFocus.idea, 'Idea'),
                      (SubmissionFocus.integration, 'Integration'),
                    ]) ...[
                      ChoiceChip(
                        key: ValueKey('focus-${focus.name}'),
                        label: Text(label),
                        labelStyle: const TextStyle(fontSize: 12),
                        selected: _focus == focus,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _focus = focus),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: EvidenceLegend(),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, box) {
                final field = Rect.fromLTRB(
                  85,
                  38,
                  box.maxWidth - 115,
                  box.maxHeight - 56,
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
                const corner = TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF93A29D),
                );
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _FieldPainter(field, 1 - t)),
                    ),
                    Positioned(
                      left: 12,
                      top: 6,
                      child: Opacity(
                        opacity: 1 - t,
                        child: Tooltip(
                          message: _mode.y.description(_sponsor),
                          child: Text(
                            '↑  ${_mode.y.label(_sponsor)}',
                            style: const TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 8,
                      child: Opacity(
                        opacity: 1 - t,
                        child: Tooltip(
                          message: _mode.x.description(_sponsor),
                          child: Text(
                            '${_mode.x.label(_sponsor)}  →',
                            style: const TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                      ),
                    ),
                    // Corners name combinations; none of them is a winner's corner.
                    for (final (i, text) in _mode.corners.indexed)
                      Positioned(
                        left: i.isEven ? field.left + 12 : null,
                        right: i.isOdd ? box.maxWidth - field.right + 12 : null,
                        top: i < 2 ? field.top + 2 : null,
                        bottom: i >= 2
                            ? box.maxHeight - field.bottom + 8
                            : null,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 1 - t,
                            child: Text(text, style: corner),
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
                              message:
                                  '${p.title}\n'
                                  '↑ ${_mode.y.label(_sponsor)}: ${p.dimensionNotes[_mode.y]}\n'
                                  '→ ${_mode.x.label(_sponsor)}: ${p.dimensionNotes[_mode.x]}',
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
                                child: ComparisonView(
                                  key: _comparison,
                                  project: selected,
                                  focus: _focus,
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
          height: 40,
          child: selected != null
              ? _projectStrip(projects, selected)
              : const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Hover a project to see why it sits there. Select it to compare its idea with its build.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: Color(0xFFDCE3DA)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                selected == null
                    ? 'Descriptive placements from inspected materials, not judge scores. Corners describe combinations, not rankings.'
                    : 'Statuses record what Finalist Brief could inspect. Questions point at gaps; judges decide.',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ),
            Text(
              selected == null
                  ? 'Select a dot to explore ↗'
                  : 'Click any node for evidence  ·  Esc closes, then returns',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _minimap(
    List<ProjectRepresentation> projects,
    ProjectRepresentation selected,
  ) => SizedBox(
    width: 158,
    height: 76,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_mode.label} · competition',
          style: const TextStyle(fontSize: 10, color: muted),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: rule),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Stack(
              children: [
                for (final p in projects)
                  Positioned(
                    left: 8 + _position(p.id).dx * 112,
                    top: 1 + _position(p.id).dy * 32,
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
  ) => ListView(
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
          child: Center(
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
        ),
    ],
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

/// Marks a deep review the pipeline generated, so it never passes for one a
/// person wrote and checked.
class _GeneratedTag extends StatelessWidget {
  const _GeneratedTag();

  @override
  Widget build(BuildContext context) => const Tooltip(
    message:
        'Generated automatically from the writeup, repository and demo. '
        'Every status was checked against its cited source, but no person '
        'reviewed this deep review.',
    child: DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: muted, width: .8)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          'Generated automatically',
          style: TextStyle(fontSize: 11.5, color: muted, letterSpacing: .2),
        ),
      ),
    ),
  );
}
