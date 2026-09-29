import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../representation/project.dart';
import '../visualization/graph_layout.dart';
import '../visualization/graph_view.dart';
import 'comparison_view.dart';
import 'inspector.dart';

/// Selection, dimming and the inspector's entrance all take this long.
const _focusTime = Duration(milliseconds: 200);

/// Space between the field and the inspector rail.
const _railGap = 20.0;

class ExplorationScreen extends StatefulWidget {
  const ExplorationScreen({
    super.key,
    this.competition,
    this.embedded = false,
    this.active = true,
    this.scopeLabel,
    this.onProject,
    this.onBackRequested,
    this.projectBack,
  });
  final Competition? competition;

  /// Shown inside a hackathon workspace, whose header already carries the
  /// brand, hackathon and location; this screen then draws only its content.
  final bool embedded;

  /// Told when a project opens (with it) and when it closes (with null).
  final ValueChanged<ProjectRepresentation?>? onProject;

  /// When set, Esc and the project's back action ask the workspace instead of
  /// closing the project themselves, so it can choose where to return to.
  final VoidCallback? onBackRequested;

  /// The workspace's contextual "Back to …" action, shown while a project is
  /// open.
  final Widget? projectBack;

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

/// Below this window width, the wordmark shrinks to just the icon.
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
    duration: const Duration(milliseconds: 520),
    value: 1,
  );
  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  /// Presence of the spotlight guides, and their hand-over between dots.
  late final AnimationController _spot = AnimationController(
    vsync: this,
    duration: _focusTime,
  );
  late final AnimationController _shift = AnimationController(
    vsync: this,
    duration: _focusTime,
    value: 1,
  );
  String? _spotFrom;
  String? _spotId;
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
      setState(() => _setPreview(project));

  /// The one way the spotlight changes: guides slide to the new dot, or fade
  /// out when the preview clears. Call inside `setState`.
  void _setPreview(ProjectRepresentation? project) {
    final old = _preview;
    if (project == null) {
      _spot.reverse();
    } else {
      if (old != null && old.id != project.id) {
        _spotFrom = old.id;
        _shift.forward(from: 0);
      } else {
        _spotFrom = null;
        _shift.value = 1;
      }
      _spotId = project.id;
      _spot.forward();
    }
    _preview = project;
  }

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
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onProject?.call(null),
        );
      } else if (_selected != null) {
        _selected = competition.projects.singleWhere(
          (p) => p.id == _selected!.id,
        );
      }
      if (_preview != null && !ids.contains(_preview!.id)) _setPreview(null);
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
      _setPreview(project);
      _hover = null;
    });
    _zoom.forward();
    widget.onProject?.call(project);
  }

  /// Leaves the open project: the workspace decides where that returns to
  /// when it is listening, otherwise the field is simply shown again.
  void _requestBack() {
    final ask = widget.onBackRequested;
    if (ask != null) {
      ask();
    } else {
      closeProject();
    }
  }

  /// Returns to the field. Without [animate] the zoom snaps shut, which is
  /// what a workspace needs when it is about to hide this screen.
  Future<void> closeProject({bool animate = true}) async {
    if (_selected == null) return;
    widget.onProject?.call(null);
    if (!animate) {
      _zoom.value = 0;
      setState(() => _selected = null);
      return;
    }
    await _zoom.reverse();
    if (mounted && _zoom.isDismissed) setState(() => _selected = null);
  }

  @override
  void dispose() {
    _motion.dispose();
    _zoom.dispose();
    _spot.dispose();
    _shift.dispose();
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
                _requestBack();
              } else if (_preview != null) {
                setState(() => _setPreview(null));
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
                        final embedded = widget.embedded;
                        final width = math.max(
                          embedded ? 880.0 : 960.0,
                          constraints.maxWidth,
                        );
                        final height = math.max(
                          embedded ? 600.0 : 680.0,
                          constraints.maxHeight,
                        );
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: width,
                            child: SingleChildScrollView(
                              child: SizedBox(
                                height: height,
                                child: Padding(
                                  padding: embedded
                                      ? const EdgeInsets.only(
                                          top: 4,
                                          bottom: 12,
                                        )
                                      : EdgeInsets.fromLTRB(
                                          width > 1100 ? 48 : 24,
                                          20,
                                          width > 1100 ? 48 : 24,
                                          14,
                                        ),
                                  child: AnimatedBuilder(
                                    animation: Listenable.merge([
                                      _motion,
                                      _zoom,
                                      _spot,
                                      _shift,
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
    final reserve = (_PreviewPanel.width + _railGap) * (1 - t);
    // Every row keeps its height in both views, so the field never moves
    // underneath the zoom.
    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) ...[
          SizedBox(
            height: 40,
            child: Row(
              children: [
                const BrandMark(),
                const SizedBox(width: 24),
                if (selected != null)
                  TextButton.icon(
                    key: const ValueKey('back-to-competition'),
                    onPressed: _requestBack,
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
          const SizedBox(height: 6),
        ],
        Expanded(
          // The rail overlays the right edge; every row but the plot leaves
          // room for it, and the plot keeps one width through a zoom.
          child: Padding(
            padding: EdgeInsets.only(right: reserve),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 78,
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
                            const _ControlLabel('MODE'),
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
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        )
                      : LayoutBuilder(
                          builder: (context, box) => Row(
                            children: [
                              // While the field zooms this row is briefly
                              // narrow; its controls shrink rather than clip.
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      if (widget.projectBack != null) ...[
                                        widget.projectBack!,
                                        const SizedBox(width: 18),
                                      ],
                                      const _ControlLabel('SHOW'),
                                      for (final (focus, label) in [
                                        (SubmissionFocus.both, 'Side by side'),
                                        (SubmissionFocus.idea, 'Idea'),
                                        (
                                          SubmissionFocus.integration,
                                          'Integration',
                                        ),
                                      ]) ...[
                                        ChoiceChip(
                                          key: ValueKey('focus-${focus.name}'),
                                          label: Text(label),
                                          labelStyle: const TextStyle(
                                            fontSize: 12,
                                          ),
                                          selected: _focus == focus,
                                          showCheckmark: false,
                                          onSelected: (_) =>
                                              setState(() => _focus = focus),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              if (box.maxWidth > 820) ...[
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
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: box.maxWidth + reserve,
                      maxWidth: box.maxWidth + reserve,
                      child: SizedBox(
                        width: box.maxWidth + reserve,
                        height: box.maxHeight,
                        child: _plot(projects, selected, t),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: selected != null
                      ? _projectStrip(projects, selected)
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _preview == null
                                ? 'Hover to highlight a project. Select it to read why it sits there, then open it to compare its idea with its build.'
                                : 'Select another dot to move focus, or open this project to compare its idea with its build.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: muted,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFDCE3DA)),
                const SizedBox(height: 10),
                // One fixed line, so the field never moves when the words do.
                SizedBox(
                  height: 18,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selected == null
                              ? 'Placements describe inspected materials; they are not judge scores or rankings.'
                              : 'Statuses record what Finalist Brief could inspect. Questions point at gaps; judges decide.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        selected == null
                            ? '${widget.embedded && widget.scopeLabel != null ? '${widget.scopeLabel}  ·  ' : ''}Esc clears'
                            : 'Esc closes, then returns',
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return Stack(
      children: [
        page,
        Positioned(
          top: widget.embedded ? 0 : 46,
          right: 0,
          bottom: 0,
          width: _PreviewPanel.width,
          child: _rail(t, selected != null),
        ),
      ],
    );
  }

  /// The inspector rail, beside the title and above the footer. It fades
  /// out as the field zooms and leaves the tree once the zoom is complete, so
  /// its words never compete with the project's own.
  Widget _rail(double t, bool zoomed) {
    if (zoomed && t >= 1) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) => Align(
        alignment: Alignment.topRight,
        child: IgnorePointer(
          ignoring: zoomed,
          child: Opacity(
            opacity: 1 - t,
            child: _PreviewPanel(
              maxHeight: box.maxHeight - 8,
              project: _preview,
              mode: _mode,
              sponsor: _sponsor,
              onOpen: _preview == null ? null : () => _open(_preview!),
              onDismiss: () => setState(() => _setPreview(null)),
            ),
          ),
        ),
      ),
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
          // The card is the field's surface; dots sit in an inset area of it, so
          // their labels stay inside the card.
          final surface = Rect.fromLTRB(
            0,
            30,
            box.maxWidth - (_PreviewPanel.width + _railGap) * (1 - t),
            box.maxHeight - 32,
          );
          final field = Rect.fromLTRB(
            surface.left + 70,
            surface.top + 46,
            surface.right - 70,
            surface.bottom - 46,
          );
          Offset point(String id) {
            final p = _position(id);
            return Offset(
              field.left + p.dx * field.width,
              field.top + p.dy * field.height,
            );
          }

          // Guide lines from the spotlit dot to both axes; they travel from
          // the previous dot when focus moves.
          Offset? guide() {
            final id = _spotId;
            if (id == null || !projects.any((p) => p.id == id)) return null;
            final to = point(id);
            final from = _spotFrom;
            if (from == null || !projects.any((p) => p.id == from)) return to;
            return Offset.lerp(
              point(from),
              to,
              Curves.easeOut.transform(_shift.value),
            );
          }

          final center = Offset(box.maxWidth / 2, box.maxHeight / 2);
          final origin = selected == null ? center : point(selected.id);
          final travel = Curves.easeInOut.transform(
            ((t - .12) / .88).clamp(0, 1),
          );
          final aperture = Offset.lerp(origin, center, travel)!;
          final labels = _labelPositions(projects, point, surface.deflate(6));
          bool emphasized(ProjectRepresentation p) =>
              p.id == _hover || p.id == _preview?.id;
          // While a project is spotlit, the rest recede but stay legible.
          bool dimmed(ProjectRepresentation p) =>
              _preview != null && !emphasized(p);
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
                child: _Dim(
                  dimmed: dimmed(p),
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
            ),
          );
          Widget labelOf(ProjectRepresentation p) => Positioned.fromRect(
            key: ValueKey('label-at-${p.id}'),
            rect: labels[p.id]!,
            child: IgnorePointer(
              ignoring: selected != null || _motion.isAnimating,
              child: Opacity(
                opacity: (1 - t * 2).clamp(0, 1),
                child: _Dim(
                  dimmed: dimmed(p),
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
            ),
          );

          Widget swap(Object key, Widget child) => AnimatedSwitcher(
            duration: _focusTime,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topLeft,
              children: [...previous, ?current],
            ),
            child: KeyedSubtree(key: ValueKey(key), child: child),
          );
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _FieldPainter(
                    surface,
                    field,
                    1 - t,
                    guide: guide(),
                    guideOpacity: _spot.value,
                  ),
                ),
              ),
              Positioned(
                left: 4,
                top: 7,
                child: Opacity(
                  opacity: 1 - t,
                  child: Tooltip(
                    message: _mode.y.description(_sponsor),
                    child: swap(
                      _mode,
                      Text('↑  ${_mode.y.label(_sponsor)}', style: _axisStyle),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: box.maxWidth - surface.right + 4,
                bottom: 7,
                child: Opacity(
                  opacity: 1 - t,
                  child: Tooltip(
                    message: _mode.x.description(_sponsor),
                    child: swap(
                      _mode,
                      Text('${_mode.x.label(_sponsor)}  →', style: _axisStyle),
                    ),
                  ),
                ),
              ),
              // Corners name combinations; none of them is a winner's corner.
              for (final (i, text) in _mode.corners.indexed)
                Positioned(
                  left: i.isEven ? surface.left + 16 : null,
                  right: i.isOdd ? box.maxWidth - surface.right + 16 : null,
                  top: i < 2 ? surface.top + 12 : null,
                  bottom: i >= 2 ? box.maxHeight - surface.bottom + 12 : null,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 1 - t,
                      child: swap(text, Text(text, style: _cornerStyle)),
                    ),
                  ),
                ),
              // Labels sit under every dot, and the emphasized project is
              // drawn last, so nothing covers a dot or the chosen name.
              for (final p in others) labelOf(p),
              for (final p in others) dotOf(p),
              for (final p in emphasis) ...[labelOf(p), dotOf(p)],
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
  Rect bounds,
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
    final width = math.min(190.0, p.title.length * 7.4 + 22);
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
      // Farther slots, for crowded clusters.
      Offset(18, -height - 16),
      Offset(18, 16),
      Offset(-width - 18, -height - 16),
      Offset(-width - 18, 16),
    ];
    Rect? best;
    var least = double.infinity;
    for (final (i, delta) in candidates.indexed) {
      final rect = Rect.fromLTWH(
        (at.dx + delta.dx)
            .clamp(bounds.left, math.max(bounds.left, bounds.right - width))
            .toDouble(),
        (at.dy + delta.dy)
            .clamp(bounds.top, math.max(bounds.top, bounds.bottom - height))
            .toDouble(),
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

const _axisStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Color(0xFF4A5E5C),
  letterSpacing: .1,
);
const _cornerStyle = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w500,
  color: Color(0xFF5F716E),
  letterSpacing: .2,
);

/// The field's surface: a quiet card, a dotted grid, faint midlines, and, for
/// the spotlit dot, guides to the axes.
const _fieldFill = Color(0xFFFBFCF9);

/// The small caption in front of a row of view controls, so filters and
/// modes read as controls rather than as navigation.
class _ControlLabel extends StatelessWidget {
  const _ControlLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 10, letterSpacing: 1.2, color: muted),
    ),
  );
}

class _FieldPainter extends CustomPainter {
  _FieldPainter(
    this.surface,
    this.field,
    this.opacity, {
    this.guide,
    this.guideOpacity = 0,
  });
  final Rect surface;
  final Rect field;
  final double opacity;
  final Offset? guide;
  final double guideOpacity;

  static void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0, gap = 5.0;
    final length = (b - a).distance;
    if (length == 0) return;
    final step = (b - a) / length;
    for (double d = 0; d < length; d += dash + gap) {
      canvas.drawLine(
        a + step * d,
        a + step * math.min(d + dash, length),
        paint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final card = RRect.fromRectAndRadius(surface, const Radius.circular(12));
    canvas.drawRRect(
      card,
      Paint()..color = _fieldFill.withValues(alpha: opacity),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = rule.withValues(alpha: opacity),
    );
    final grid = Paint()
      ..color = const Color(0xFFC5D1C8).withValues(alpha: .5 * opacity);
    for (double x = surface.left + 14; x <= surface.right - 8; x += 28) {
      for (double y = surface.top + 14; y <= surface.bottom - 8; y += 28) {
        canvas.drawCircle(Offset(x, y), .8, grid);
      }
    }
    final mid = Paint()
      ..color = const Color(0xFFB9C7BE).withValues(alpha: .7 * opacity)
      ..strokeWidth = 1;
    _dashed(
      canvas,
      Offset(field.center.dx, surface.top + 6),
      Offset(field.center.dx, surface.bottom - 6),
      mid,
    );
    _dashed(
      canvas,
      Offset(surface.left + 6, field.center.dy),
      Offset(surface.right - 6, field.center.dy),
      mid,
    );
    final at = guide;
    if (at != null && guideOpacity > 0) {
      final alpha = guideOpacity * opacity;
      final line = Paint()
        ..color = accent.withValues(alpha: .5 * alpha)
        ..strokeWidth = 1.2;
      final foot = Offset(at.dx, surface.bottom);
      final side = Offset(surface.left, at.dy);
      _dashed(canvas, at, foot, line);
      _dashed(canvas, at, side, line);
      final mark = Paint()..color = accent.withValues(alpha: .85 * alpha);
      canvas.drawCircle(foot, 3, mark);
      canvas.drawCircle(side, 3, mark);
    }
  }

  @override
  bool shouldRepaint(_FieldPainter oldDelegate) =>
      oldDelegate.surface != surface ||
      oldDelegate.field != field ||
      oldDelegate.opacity != opacity ||
      oldDelegate.guide != guide ||
      oldDelegate.guideOpacity != guideOpacity;
}

/// Lets a dot or label recede while another project holds the spotlight.
class _Dim extends StatelessWidget {
  const _Dim({required this.dimmed, required this.child});
  final bool dimmed;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: _focusTime,
    curve: Curves.easeOut,
    opacity: dimmed ? .6 : 1,
    child: child,
  );
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

/// A project's dot. Hovering grows it with a soft halo; the spotlit project
/// keeps a larger, darker dot with a ring until another is chosen.
class _Dot extends StatelessWidget {
  const _Dot({required this.hovered, required this.selected});
  final bool hovered;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 22.0 : (hovered ? 19.0 : 15.0);
    return AnimatedContainer(
      duration: _focusTime,
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? ink : accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          if (selected) ...[
            BoxShadow(color: accent.withValues(alpha: .16), spreadRadius: 10),
            const BoxShadow(color: accent, spreadRadius: 3),
          ] else if (hovered)
            BoxShadow(color: accent.withValues(alpha: .28), spreadRadius: 5),
        ],
      ),
    );
  }
}

/// A project's name on the plot: quiet at rest, stronger when hovered, and a
/// solid chip when it holds the spotlight.
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
        duration: _focusTime,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? ink
              : hovered
              ? const Color(0xFFE3EDE6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: AnimatedDefaultTextStyle(
          duration: _focusTime,
          curve: Curves.easeOut,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: selected ? 13.5 : 12.5,
            fontWeight: selected
                ? FontWeight.w700
                : hovered
                ? FontWeight.w600
                : FontWeight.w500,
            color: selected
                ? Colors.white
                : strong
                ? ink
                : const Color(0xFF3F5354),
            shadows: strong
                ? null
                : const [
                    Shadow(color: _fieldFill, blurRadius: 2),
                    Shadow(color: _fieldFill, blurRadius: 4),
                  ],
          ),
          child: Text(title),
        ),
      ),
    );
  }
}

/// The executive briefing for the spotlit project: what it claims, where it
/// sits and why, what stands behind it, and what to ask. Persistent, so
/// nothing important depends on where the pointer is.
class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.project,
    required this.mode,
    required this.sponsor,
    required this.onOpen,
    required this.onDismiss,
    required this.maxHeight,
  });
  final ProjectRepresentation? project;
  final CompetitionLens mode;
  final String sponsor;
  final VoidCallback? onOpen;
  final VoidCallback onDismiss;
  final double maxHeight;

  static const width = 348.0;

  static String _axis(Dimension d) => switch (d) {
    Dimension.ideaDistinctiveness => 'IDEA',
    Dimension.integrationDepth => 'INTEGRATION',
    Dimension.sponsorCentrality => 'CENTRALITY',
    Dimension.sponsorEvidence => 'VERIFIABILITY',
  };

  @override
  Widget build(BuildContext context) {
    final project = this.project;
    return AnimatedContainer(
      key: const ValueKey('project-preview'),
      duration: _focusTime,
      curve: Curves.easeOut,
      constraints: BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: maxHeight,
      ),
      decoration: BoxDecoration(
        color: project == null ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rule),
        boxShadow: [
          if (project != null)
            BoxShadow(
              color: ink.withValues(alpha: .07),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: _focusTime,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(project?.id),
          child: project == null
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Select a project to see where it sits and why.',
                    style: TextStyle(fontSize: 13.5, height: 1.4, color: muted),
                  ),
                )
              : _briefing(project),
        ),
      ),
    );
  }

  Widget _briefing(ProjectRepresentation project) {
    final counts = {for (final s in EvidenceStatus.values) s: 0};
    for (final graph in [project.idea, project.integration]) {
      for (final node in graph.nodes) {
        final status = node.evidence?.status;
        if (status != null) counts[status] = counts[status]! + 1;
      }
    }
    final question = project.questions.firstOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 16),
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      project.title,
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.4,
                        color: ink,
                      ),
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
            const SizedBox(height: 6),
            Text(
              project.summary,
              style: const TextStyle(fontSize: 13, height: 1.4, color: muted),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: rule),
            // Vertical axis first, as it reads on the plot.
            for (final d in [mode.y, mode.x]) ...[
              const SizedBox(height: 11),
              _Eyebrow(_axis(d)),
              const SizedBox(height: 3),
              Text(
                project.dimensionNotes[d] ?? '',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.4, color: ink),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, color: rule),
            const SizedBox(height: 11),
            const _Eyebrow('EVIDENCE'),
            const SizedBox(height: 7),
            _EvidenceBar(counts),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final e in counts.entries)
                  if (e.value > 0)
                    Tooltip(
                      message: e.key.meaning,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EvidenceGlyph(e.key, size: 11),
                          const SizedBox(width: 5),
                          Text(
                            '${e.value} ${e.key.label}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4A5E5C),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
            if (question != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('preview-question'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                decoration: BoxDecoration(
                  color: questionColor.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: questionColor.withValues(alpha: .25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        QuestionMark(size: 15, filled: true),
                        SizedBox(width: 7),
                        Text(
                          'WHAT TO ASK',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                            color: questionColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      question.question,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('open-project'),
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Open project'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      letterSpacing: 1.3,
      fontWeight: FontWeight.w700,
      color: accent,
    ),
  );
}

/// Evidence tiers as one proportional bar, solid for seen-working down to
/// pale for inferred, matching the glyph grammar.
class _EvidenceBar extends StatelessWidget {
  const _EvidenceBar(this.counts);
  final Map<EvidenceStatus, int> counts;

  static Color _tone(EvidenceStatus s) => switch (s) {
    EvidenceStatus.demonstrated => accent,
    EvidenceStatus.foundInCode => accent.withValues(alpha: .62),
    EvidenceStatus.described => accent.withValues(alpha: .3),
    EvidenceStatus.inferred => const Color(0xFFD3DCD6),
  };

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: SizedBox(
      height: 6,
      child: Row(
        children: [
          for (final e in counts.entries)
            if (e.value > 0) ...[
              Expanded(
                flex: e.value,
                child: ColoredBox(
                  color: _tone(e.key),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(width: 1.5),
            ],
        ],
      ),
    ),
  );
}
