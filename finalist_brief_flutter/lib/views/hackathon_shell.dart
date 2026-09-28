import 'package:flutter/material.dart';

import '../hackathon/hackathon.dart';
import '../representation/project.dart';
import '../triage/triage_query.dart';
import '../visualization/graph_view.dart';
import 'exploration_screen.dart';
import 'triage_view.dart';

/// Top level of the demo: one workspace per hackathon, all kept alive so
/// switching is instant and each keeps its own selection, mode and filters.
class HackathonShell extends StatefulWidget {
  const HackathonShell({
    super.key,
    this.sources = hackathonSources,
    this.initial,
    this.preloaded = const {},
  });
  final List<HackathonSource> sources;

  /// Hackathon ID to open first, e.g. from `?hackathon=serverpod`.
  final String? initial;

  /// Already-loaded hackathons by ID; tests use this to skip asset loading.
  final Map<String, Hackathon> preloaded;

  @override
  State<HackathonShell> createState() => _HackathonShellState();
}

class _HackathonShellState extends State<HackathonShell> {
  late int _active = widget.sources
      .indexWhere((s) => s.id == widget.initial)
      .clamp(0, widget.sources.length - 1);
  final _loads = <String, Future<Hackathon>>{};

  Future<Hackathon> _load(HackathonSource source) => _loads.putIfAbsent(
    source.id,
    () => widget.preloaded.containsKey(source.id)
        ? Future.value(widget.preloaded[source.id])
        : loadHackathon(source),
  );

  void _switch(int index) => setState(() => _active = index);

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _active,
      sizing: StackFit.expand,
      children: [
        for (final (i, source) in widget.sources.indexed)
          // A hackathon loads the first time it is opened, then stays.
          if (i == _active || _loads.containsKey(source.id))
            _Loaded(
              key: ValueKey('workspace-${source.id}'),
              future: _load(source),
              builder: (hackathon) {
                final switcher = HackathonSwitcher(
                  sources: widget.sources,
                  active: _active,
                  onSelect: _switch,
                );
                return hackathon.triage == null
                    ? ExplorationScreen(
                        competition: hackathon.competition,
                        navigation: switcher,
                        active: i == _active,
                      )
                    : TriageWorkspace(
                        hackathon: hackathon,
                        switcher: switcher,
                        active: i == _active,
                      );
              },
            )
          else
            const SizedBox.shrink(),
      ],
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({super.key, required this.future, required this.builder});
  final Future<Hackathon> future;
  final Widget Function(Hackathon) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<Hackathon>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasData) return builder(snapshot.data!);
      return Scaffold(
        backgroundColor: paper,
        body: Center(
          child: snapshot.hasError
              ? Text('Could not load this hackathon: ${snapshot.error}')
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}

/// A compact segmented control naming each hackathon.
class HackathonSwitcher extends StatelessWidget {
  const HackathonSwitcher({
    super.key,
    required this.sources,
    required this.active,
    required this.onSelect,
  });
  final List<HackathonSource> sources;
  final int active;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => _Segments(
    labels: [for (final s in sources) s.name],
    keys: [for (final s in sources) 'hackathon-${s.id}'],
    active: active,
    onSelect: onSelect,
  );
}

class _Segments extends StatelessWidget {
  const _Segments({
    required this.labels,
    required this.keys,
    required this.active,
    required this.onSelect,
    this.quiet = false,
  });
  final List<String> labels;
  final List<String> keys;
  final int active;
  final ValueChanged<int> onSelect;

  /// Secondary navigation: no outline, lighter selection.
  final bool quiet;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: quiet ? Colors.transparent : Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: quiet ? Colors.transparent : rule),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, label) in labels.indexed)
          Semantics(
            selected: i == active,
            button: true,
            child: InkWell(
              key: ValueKey(keys[i]),
              borderRadius: BorderRadius.circular(6),
              onTap: i == active ? null : () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == active
                      ? (quiet ? const Color(0xFFE3EDE6) : accent)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: i == active ? FontWeight.w600 : FontWeight.w400,
                    color: i == active
                        ? (quiet ? accent : Colors.white)
                        : muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

enum WorkspaceView { triage, competition }

/// A hackathon with a triage table in front of its Competition View. The
/// table chooses which deep reviews the Competition View compares.
class TriageWorkspace extends StatefulWidget {
  const TriageWorkspace({
    super.key,
    required this.hackathon,
    required this.switcher,
    this.active = true,
  });
  final Hackathon hackathon;
  final Widget switcher;
  final bool active;

  @override
  State<TriageWorkspace> createState() => _TriageWorkspaceState();
}

class _TriageWorkspaceState extends State<TriageWorkspace> {
  WorkspaceView _view = WorkspaceView.triage;
  final Set<String> _selected = {};
  final Map<String, ReviewStatus> _reviews = {};
  final _exploration = GlobalKey<ExplorationScreenState>();
  late Competition _comparison = _buildComparison();

  /// The selected deep reviews, or every deep review when none is selected.
  Competition _buildComparison() {
    final all = widget.hackathon.competition;
    final chosen = all.projects.where((p) => _selected.contains(p.id)).toList();
    return Competition(
      title: all.title,
      sponsorTech: all.sponsorTech,
      provenance: all.provenance,
      projects: List.unmodifiable(chosen.isEmpty ? all.projects : chosen),
    );
  }

  void _select(String id, bool on) => setState(() {
    on ? _selected.add(id) : _selected.remove(id);
    _comparison = _buildComparison();
  });

  void _show(WorkspaceView view) => setState(() => _view = view);

  void _openDeepReview(String id) {
    setState(() {
      if (_selected.isNotEmpty && !_selected.contains(id)) _selected.add(id);
      _comparison = _buildComparison();
      _view = WorkspaceView.competition;
    });
    // The field needs one frame with the new comparison set before zooming.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _exploration.currentState?.openProject(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final triage = widget.hackathon.triage!;
    final navigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.switcher,
        const SizedBox(width: 12),
        _Segments(
          labels: ['Triage', 'Competition · ${_comparison.projects.length}'],
          keys: const ['workspace-triage', 'workspace-competition'],
          active: _view.index,
          onSelect: (i) => _show(WorkspaceView.values[i]),
          quiet: true,
        ),
      ],
    );
    return IndexedStack(
      index: _view.index,
      sizing: StackFit.expand,
      children: [
        TriageView(
          hackathon: widget.hackathon,
          navigation: navigation,
          selected: _selected,
          reviews: _reviews,
          active: widget.active && _view == WorkspaceView.triage,
          onSelect: _select,
          onReview: (id, status) => setState(() => _reviews[id] = status),
          onOpenDeepReview: _openDeepReview,
          onViewCompetition: () => _show(WorkspaceView.competition),
        ),
        ExplorationScreen(
          key: _exploration,
          competition: _comparison,
          navigation: navigation,
          active: widget.active && _view == WorkspaceView.competition,
          scopeLabel:
              'DEEP REVIEW  /  ${_comparison.projects.length.toString().padLeft(2, '0')} '
              'OF ${triage.submissions.length} '
              '${triage.submissions.length == triage.fieldSize ? '' : 'PILOT '}SUBMISSIONS',
        ),
      ],
    );
  }
}
