import 'package:flutter/material.dart';

import '../hackathon/hackathon.dart';
import '../representation/project.dart';
import '../triage/triage_query.dart';
import '../visualization/graph_view.dart';
import 'cached_submissions.dart';
import 'exploration_screen.dart';
import 'hackathon_overview.dart';
import 'triage_view.dart';
import 'workspace_frame.dart';

/// Where the judge is inside one hackathon, as a path:
/// `/hackathons/serverpod`, `.../submissions`, `.../competition` and, for a
/// project, `.../competition/naggy` or `.../submissions/naggy`, so the
/// origin survives in the address.
class WorkspaceLocation {
  const WorkspaceLocation(
    this.hackathonId, [
    this.tab = WorkspaceTab.overview,
    this.project,
  ]);
  final String hackathonId;
  final WorkspaceTab tab;
  final String? project;

  /// `null` for the Hackathons list or anything unrecognised.
  static WorkspaceLocation? parse(String? path) {
    final parts = (path ?? '')
        .split('?')
        .first
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length < 2 || parts[0] != 'hackathons') return null;
    final tab = parts.length > 2
        ? WorkspaceTab.values.where((t) => t.name == parts[2]).firstOrNull
        : WorkspaceTab.overview;
    if (tab == null) return WorkspaceLocation(parts[1]);
    final project = parts.length > 3 && tab != WorkspaceTab.overview
        ? parts[3]
        : null;
    return WorkspaceLocation(parts[1], tab, project);
  }

  String get path => [
    '/hackathons',
    hackathonId,
    if (tab != WorkspaceTab.overview) tab.name,
    ?project,
  ].join('/');
}

/// A workspace that can be sent back to its Overview.
abstract interface class OverviewWorkspace {
  void showOverview();
}

/// One hackathon: Overview, Submissions and Competition behind a persistent
/// header, with a project as the only level below the last two. The same
/// widget serves every hackathon; only the Submissions table differs (a
/// triage table for a large field, a plain list for a small one).
///
/// Selection is shared by Submissions and Competition. Filters, the
/// Competition mode and scroll position live in their own views, which stay
/// alive while another workspace is shown.
class HackathonWorkspace extends StatefulWidget {
  const HackathonWorkspace({
    super.key,
    required this.hackathon,
    required this.onHackathons,
    this.location,
    this.onLocation,
    this.active = true,
  });
  final Hackathon hackathon;
  final VoidCallback onHackathons;

  /// Where to start, e.g. from a link. Defaults to the Overview.
  final WorkspaceLocation? location;

  /// Told the new location after every navigation.
  final ValueChanged<WorkspaceLocation>? onLocation;
  final bool active;

  @override
  State<HackathonWorkspace> createState() => HackathonWorkspaceState();
}

class HackathonWorkspaceState extends State<HackathonWorkspace>
    implements OverviewWorkspace {
  late WorkspaceTab _tab = widget.location?.tab ?? WorkspaceTab.overview;

  /// The workspace a project was opened from, and where "Back" returns to.
  WorkspaceTab _origin = WorkspaceTab.competition;
  ProjectRepresentation? _project;
  final Set<String> _selected = {};
  final Map<String, ReviewStatus> _reviews = {};
  final _exploration = GlobalKey<ExplorationScreenState>();
  late Competition _comparison = _buildComparison();

  Hackathon get _hackathon => widget.hackathon;
  bool get _triaged => _hackathon.triage != null;

  @override
  void initState() {
    super.initState();
    final project = widget.location?.project;
    if (project != null && _hackathon.hasRepresentation(project)) {
      _origin = _tab == WorkspaceTab.submissions
          ? WorkspaceTab.submissions
          : WorkspaceTab.competition;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _exploration.currentState?.openProject(project),
      );
    }
  }

  /// The selected deep reviews, or every deep review when none is selected.
  Competition _buildComparison() {
    final all = _hackathon.competition;
    final chosen = all.projects.where((p) => _selected.contains(p.id)).toList();
    return Competition(
      title: all.title,
      sponsorTech: all.sponsorTech,
      provenance: all.provenance,
      projects: List.unmodifiable(chosen.isEmpty ? all.projects : chosen),
    );
  }

  WorkspaceTab get _shownTab => _project == null ? _tab : _origin;

  /// The layer on screen: a project is always drawn by the Competition
  /// screen, whichever workspace it was opened from.
  int get _layer =>
      _project == null ? _tab.index : WorkspaceTab.competition.index;

  void _report() => widget.onLocation?.call(
    WorkspaceLocation(_hackathon.id, _shownTab, _project?.id),
  );

  void _select(String id, bool on) => setState(() {
    on ? _selected.add(id) : _selected.remove(id);
    _comparison = _buildComparison();
  });

  /// Shows a workspace. An open project closes first, without ceremony:
  /// choosing a workspace always lands on that workspace's own view.
  void _show(WorkspaceTab tab) {
    if (_project != null) {
      _exploration.currentState?.closeProject(animate: false);
    }
    setState(() {
      _project = null;
      _origin = WorkspaceTab.competition;
      _tab = tab;
    });
    _report();
  }

  @override
  void showOverview() => _show(WorkspaceTab.overview);

  void _onProject(ProjectRepresentation? project) {
    if (!mounted || _project?.id == project?.id) return;
    setState(() {
      _project = project;
      if (project == null) _origin = WorkspaceTab.competition;
    });
    _report();
  }

  /// One action, one meaning: return to where the project was opened from,
  /// with that view exactly as it was left.
  void _backFromProject() {
    if (_project == null) return;
    if (_origin == WorkspaceTab.submissions) {
      _show(WorkspaceTab.submissions);
    } else {
      _exploration.currentState?.closeProject();
    }
  }

  void _openFromSubmissions(String id) {
    setState(() {
      _origin = WorkspaceTab.submissions;
      if (_selected.isNotEmpty && !_selected.contains(id)) _selected.add(id);
      _comparison = _buildComparison();
    });
    // The field needs one frame with the new comparison set before zooming.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _exploration.currentState?.openProject(id),
    );
  }

  String get _scope {
    final n = _comparison.projects.length.toString().padLeft(2, '0');
    final triage = _hackathon.triage;
    if (triage == null) {
      return '$n OF ${_hackathon.competition.projects.length.toString().padLeft(2, '0')} SUBMISSIONS';
    }
    final partial = triage.submissions.length != triage.fieldSize;
    return '$n OF ${triage.submissions.length} ${partial ? 'PILOT ' : ''}SUBMISSIONS';
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shownTab;
    final submissions =
        _hackathon.triage?.submissions.length ??
        _hackathon.competition.projects.length;
    return WorkspaceFrame(
      hackathonName: _hackathon.name,
      title: _hackathon.triage?.title ?? _hackathon.name,
      active: shown,
      counts: {
        WorkspaceTab.submissions: submissions,
        WorkspaceTab.competition: _comparison.projects.length,
      },
      onTab: _show,
      onHackathons: widget.onHackathons,
      projectTitle: _project?.title,
      child: IndexedStack(
        index: _layer,
        sizing: StackFit.expand,
        children: [
          HackathonOverview(
            hackathon: _hackathon,
            onBrowse: () => _show(WorkspaceTab.submissions),
            onExplore: () => _show(WorkspaceTab.competition),
          ),
          _triaged
              ? TriageView(
                  hackathon: _hackathon,
                  selected: _selected,
                  reviews: _reviews,
                  active:
                      widget.active && _layer == WorkspaceTab.submissions.index,
                  onSelect: _select,
                  onReview: (id, status) =>
                      setState(() => _reviews[id] = status),
                  onOpenDeepReview: _openFromSubmissions,
                  onViewCompetition: () => _show(WorkspaceTab.competition),
                )
              : CachedSubmissions(
                  hackathon: _hackathon,
                  selected: _selected,
                  onToggle: _select,
                  onViewCompetition: () => _show(WorkspaceTab.competition),
                ),
          ExplorationScreen(
            key: _exploration,
            embedded: true,
            competition: _comparison,
            active: widget.active && _layer == WorkspaceTab.competition.index,
            scopeLabel: _scope,
            onProject: _onProject,
            onBackRequested: _backFromProject,
            projectBack: _project == null ? null : _back(),
          ),
        ],
      ),
    );
  }

  Widget _back() => TextButton.icon(
    key: ValueKey('back-to-${_origin.name}'),
    style: TextButton.styleFrom(
      foregroundColor: accent,
      backgroundColor: const Color(0xFFE3EDE6),
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
    ),
    onPressed: _backFromProject,
    icon: const Icon(Icons.arrow_back, size: 15),
    label: Text('Back to ${_origin.label}'),
  );
}
