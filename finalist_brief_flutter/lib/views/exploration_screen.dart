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

  /// The dot under the pointer: only highlighted, never a source of facts.
  String? _hover;

  /// The project whose placement the preview panel explains. It stays until
  /// another is chosen or the judge dismisses it.
  ProjectRepresentation? _preview;

  void _setHover(String? id) => setState(() => _hover = id);

  void _select(ProjectRepresentation project) =>
      setState(() => _preview = project);

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
      if (_preview != null && !ids.contains(_preview!.id)) _preview = null;
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
    setState(() {
      _selected = project;
      _preview = project;
      _hover = null;
    });
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
              if (_comparison.currentState?.dismiss() ?? false) return null;
              if (_selected != null) {
                _back();
              } else if (_preview != null) {
                setState(() => _preview = null);
              }
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
        Expanded(child: _plot(projects, selected, t)),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: selected != null
              ? _projectStrip(projects, selected)
              : const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Hover to highlight a project. Select it to read why it sits there, then open it to compare its idea with its build.',
                    style: TextStyle(fontSize: 13, color: muted),
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
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ),
            Text(
              selected == null
                  ? 'Select a dot to preview  ·  Esc clears'
                  : 'Click any node for evidence  ·  Esc closes, then returns',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _plot(
    List<ProjectRepresentation> projects,
    ProjectRepresentation? selected,
    double t,
  ) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, box) {
          // The preview panel takes the right edge while the field shows.
          final panel = (_PreviewPanel.width + 16) * (1 - t);
          final field = Rect.fromLTRB(
            85,
            38,
            box.maxWidth - 115 - panel,
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
          bool emphasized(ProjectRepresentation p) =>
              p.id == _hover || p.id == _preview?.id;
          final others = projects.where((p) => !emphasized(p)).toList();
          final emphasis = projects.where(emphasized).toList();
          Widget dotOf(ProjectRepresentation p) => Positioned(
            key: ValueKey('dot-at-${p.id}'),
            left: (point(p.id) + (point(p.id) - origin) * t * .5).dx - 18,
            top: (point(p.id) + (point(p.id) - origin) * t * .5).dy - 18,
            child: IgnorePointer(
              ignoring: selected != null || _motion.isAnimating,
              child: Opacity(
                opacity: 1 - t,
                child: Semantics(
                  button: true,
                  selected: _preview?.id == p.id,
                  label: 'Preview ${p.title}',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => _setHover(p.id),
                    onExit: (_) {
                      if (_hover == p.id) _setHover(null);
                    },
                    child: GestureDetector(
                      key: ValueKey('dot-${p.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _select(p),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: _Dot(
                            hovered: _hover == p.id,
                            selected: _preview?.id == p.id,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          Widget labelOf(ProjectRepresentation p) => Positioned.fromRect(
            key: ValueKey('label-at-${p.id}'),
            rect: labels[p.id]!,
            child: IgnorePointer(
              ignoring: selected != null || _motion.isAnimating,
              child: Opacity(
                opacity: (1 - t * 2).clamp(0, 1),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => _setHover(p.id),
                  onExit: (_) {
                    if (_hover == p.id) _setHover(null);
                  },
                  child: GestureDetector(
                    key: ValueKey('label-${p.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _select(p),
                    child: _FieldLabel(
                      p.title,
                      hovered: _hover == p.id,
                      selected: _preview?.id == p.id,
                    ),
                  ),
                ),
              ),
            ),
          );

          const corner = TextStyle(fontSize: 12, color: muted);
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
                  bottom: i >= 2 ? box.maxHeight - field.bottom + 8 : null,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 1 - t,
                      child: Text(text, style: corner),
                    ),
                  ),
                ),
              // Labels sit under every dot, and the emphasized project is
              // drawn last, so nothing covers a dot or the chosen name.
              for (final p in others) labelOf(p),
              for (final p in others) dotOf(p),
              for (final p in emphasis) ...[labelOf(p), dotOf(p)],
              Positioned(
                right: 0,
                top: 0,
                width: _PreviewPanel.width,
                child: IgnorePointer(
                  ignoring: selected != null,
                  child: Opacity(
                    opacity: 1 - t,
                    child: _PreviewPanel(
                      project: _preview,
                      mode: _mode,
                      sponsor: _sponsor,
                      onOpen: _preview == null ? null : () => _open(_preview!),
                      onDismiss: () => setState(() => _preview = null),
                    ),
                  ),
                ),
              ),
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
  const height = 26.0;
  final dots = {
    for (final p in projects)
      p.id: Rect.fromCircle(center: point(p.id), radius: 11),
  };
  double overlap(Rect a, Rect b) {
    final i = a.intersect(b);
    return i.isEmpty ? 0 : i.width * i.height;
  }

  Rect place(ProjectRepresentation p, Iterable<Rect> labels) {
    final at = point(p.id);
    final width = math.min(200.0, p.title.length * 7.6 + 20);
    // Nearest first: right, then beside-and-diagonal, then above and below.
    final candidates = [
      Offset(15, -height / 2),
      Offset(12, -height - 2),
      Offset(12, 2),
      Offset(-width - 15, -height / 2),
      Offset(-width - 12, -height - 2),
      Offset(-width - 12, 2),
      Offset(-width / 2, -height - 14),
      Offset(-width / 2, 14),
    ];
    Rect? best;
    var least = double.infinity;
    for (final (i, delta) in candidates.indexed) {
      final rect = Rect.fromLTWH(
        (at.dx + delta.dx).clamp(4, size.width - width - 4).toDouble(),
        (at.dy + delta.dy).clamp(28, size.height - 50).toDouble(),
        width,
        height,
      );
      var penalty = i * 30.0;
      for (final e in dots.entries) {
        penalty += overlap(rect, e.value) * 4;
      }
      for (final label in labels) {
        penalty += overlap(rect, label) * 2;
      }
      if (penalty < least) {
        least = penalty;
        best = rect;
      }
    }
    return best!;
  }

  // Crowded dots choose first, then every label is re-placed against the rest.
  int neighbours(ProjectRepresentation p) => projects
      .where((q) => q != p && (point(q.id) - point(p.id)).distance < 70)
      .length;
  final order = [...projects]
    ..sort((a, b) => neighbours(b).compareTo(neighbours(a)));
  final labels = <String, Rect>{};
  for (final p in order) {
    labels[p.id] = place(p, labels.values);
  }
  for (var pass = 0; pass < 2; pass++) {
    for (final p in order) {
      labels[p.id] = place(p, [
        for (final e in labels.entries)
          if (e.key != p.id) e.value,
      ]);
    }
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

/// A project's dot. Hovering grows it with a soft halo; the previewed project
/// keeps a ringed, darker dot until another is chosen.
class _Dot extends StatelessWidget {
  const _Dot({required this.hovered, required this.selected});
  final bool hovered;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 22.0 : (hovered ? 19.0 : 15.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? ink : accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          if (selected)
            const BoxShadow(color: accent, spreadRadius: 3.5)
          else if (hovered)
            BoxShadow(color: accent.withValues(alpha: .28), spreadRadius: 5),
        ],
      ),
    );
  }
}

/// A project's name on the plot, readable over the grid and never bare text.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(
    this.title, {
    required this.hovered,
    required this.selected,
  });
  final String title;
  final bool hovered;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final strong = hovered || selected;
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? ink
              : hovered
              ? const Color(0xFFE3EDE6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : ink,
            shadows: strong
                ? null
                : const [
                    Shadow(color: paper, blurRadius: 2),
                    Shadow(color: paper, blurRadius: 4),
                  ],
          ),
        ),
      ),
    );
  }
}

/// Why the chosen project sits where it does, on the axes now showing.
/// Persistent, so nothing important depends on where the pointer is.
class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.project,
    required this.mode,
    required this.sponsor,
    required this.onOpen,
    required this.onDismiss,
  });
  final ProjectRepresentation? project;
  final CompetitionLens mode;
  final String sponsor;
  final VoidCallback? onOpen;
  final VoidCallback onDismiss;

  static const width = 320.0;

  static String _axis(Dimension d) => switch (d) {
    Dimension.ideaDistinctiveness => 'IDEA',
    Dimension.integrationDepth => 'INTEGRATION',
    Dimension.sponsorCentrality => 'CENTRALITY',
    Dimension.sponsorEvidence => 'EVIDENCE',
  };

  @override
  Widget build(BuildContext context) {
    final project = this.project;
    return Container(
      key: const ValueKey('project-preview'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rule),
      ),
      child: project == null
          ? const Align(
              alignment: Alignment.topLeft,
              child: Text(
                'Select a project to read why it sits where it does.',
                style: TextStyle(fontSize: 14, height: 1.4, color: muted),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          project.title,
                          style: const TextStyle(
                            fontSize: 19,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.3,
                            color: ink,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('close-preview'),
                        tooltip: 'Dismiss',
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        onPressed: onDismiss,
                        icon: const Icon(Icons.close, color: muted),
                      ),
                    ],
                  ),
                  // Vertical axis first, as it reads on the plot.
                  for (final d in [mode.y, mode.x]) ...[
                    const SizedBox(height: 14),
                    Text(
                      _axis(d),
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.dimensionNotes[d] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: ink,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    key: const ValueKey('open-project'),
                    onPressed: onOpen,
                    child: const Text('Open project'),
                  ),
                ],
              ),
            ),
    );
  }
}
