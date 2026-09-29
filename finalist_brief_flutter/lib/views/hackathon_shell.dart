import 'package:flutter/material.dart';

import '../hackathon/hackathon.dart';
import '../representation/project.dart';
import '../triage/triage_query.dart';
import '../visualization/graph_view.dart';
import 'cached_workspace.dart';
import 'exploration_screen.dart';
import 'hackathons_screen.dart';
import 'triage_view.dart';

/// Where the judge is: choosing a hackathon, reading a hackathon's status, or
/// inside its workspace.
enum _Stage { list, status, workspace }

/// Top level of the demo: a Hackathons list, then one workspace per hackathon.
/// Opened workspaces stay alive, so leaving and returning keeps each one's
/// selection, mode and filters.
class HackathonShell extends StatefulWidget {
  const HackathonShell({
    super.key,
    this.sources = hackathonSources,
    this.initial,
    this.preloaded = const {},
  });
  final List<HackathonSource> sources;

  /// Hackathon ID to open straight into, e.g. from `?hackathon=serverpod`.
  /// Without one, the Hackathons list shows first.
  final String? initial;

  /// Already-loaded hackathons by ID; tests use this to skip asset loading.
  final Map<String, Hackathon> preloaded;

  @override
  State<HackathonShell> createState() => _HackathonShellState();
}

class _HackathonShellState extends State<HackathonShell> {
  late int _active = widget.sources.indexWhere((s) => s.id == widget.initial);
  late _Stage _stage = _active < 0 ? _Stage.list : _Stage.workspace;
  late final Set<String> _opened = {
    if (_active >= 0) widget.sources[_active].id,
  };
  late final Map<String, Future<Hackathon>> _loads = {
    for (final s in widget.sources)
      s.id: widget.preloaded.containsKey(s.id)
          ? Future.value(widget.preloaded[s.id])
          : loadHackathon(s),
  };

  final _workspaceKeys = <String, GlobalKey>{};

  /// Every card opens its hackathon's Acquisition screen, whether or not a
  /// workspace already exists; what the judge did there is kept, not resumed.
  void _open(int index) => setState(() {
    _active = index;
    _stage = _Stage.status;
  });

  /// Open overview always lands on the Overview, with any selection intact.
  void _openOverview() {
    final id = widget.sources[_active].id;
    final first = _opened.add(id);
    setState(() => _stage = _Stage.workspace);
    if (!first) {
      (_workspaceKeys[id]?.currentState as OverviewWorkspace?)?.showOverview();
    }
  }

  void _home() => setState(() => _stage = _Stage.list);

  Widget _homeLayer() {
    if (_stage == _Stage.status) {
      return _Loaded(
        key: ValueKey('status-${widget.sources[_active].id}'),
        future: _loads[widget.sources[_active].id]!,
        builder: (hackathon) => HackathonStatusScreen(
          hackathon: hackathon,
          onOpenOverview: _openOverview,
          onBack: _home,
        ),
      );
    }
    return HackathonsScreen(
      sources: widget.sources,
      loads: _loads,
      onOpen: _open,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inWorkspace = _stage == _Stage.workspace;
    return IndexedStack(
      index: inWorkspace ? 1 + _active : 0,
      sizing: StackFit.expand,
      children: [
        _homeLayer(),
        for (final (i, source) in widget.sources.indexed)
          // A workspace builds the first time it is opened, then stays.
          if (_opened.contains(source.id))
            _Loaded(
              key: ValueKey('workspace-${source.id}'),
              future: _loads[source.id]!,
              builder: (hackathon) {
                final home = BackToHackathons(onTap: _home);
                final visible = inWorkspace && i == _active;
                final key = _workspaceKeys.putIfAbsent(
                  source.id,
                  () => GlobalKey(),
                );
                return hackathon.triage == null
                    ? CachedWorkspace(
                        key: key,
                        hackathon: hackathon,
                        home: home,
                        active: visible,
                      )
                    : TriageWorkspace(
                        key: key,
                        hackathon: hackathon,
                        home: home,
                        active: visible,
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

enum WorkspaceView { triage, competition }

/// A hackathon with a triage table in front of its Competition View. The
/// table chooses which deep reviews the Competition View compares.
class TriageWorkspace extends StatefulWidget {
  const TriageWorkspace({
    super.key,
    required this.hackathon,
    required this.home,
    this.active = true,
  });
  final Hackathon hackathon;

  /// Quiet way back to the Hackathons list.
  final Widget home;
  final bool active;

  @override
  State<TriageWorkspace> createState() => TriageWorkspaceState();
}

class TriageWorkspaceState extends State<TriageWorkspace>
    implements OverviewWorkspace {
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

  @override
  void showOverview() => _show(WorkspaceView.triage);

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
        widget.home,
        const SizedBox(width: 8),
        WorkspaceTabs(
          labels: ['Overview', 'Competition · ${_comparison.projects.length}'],
          keys: const ['workspace-triage', 'workspace-competition'],
          active: _view.index,
          onSelect: (i) => _show(WorkspaceView.values[i]),
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
