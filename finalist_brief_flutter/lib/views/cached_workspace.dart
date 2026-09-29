import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../hackathon/hackathon.dart';
import '../representation/project.dart';
import '../visualization/graph_view.dart';
import 'exploration_screen.dart';
import 'hackathons_screen.dart';

extension on SourceKind {
  String get label => switch (this) {
    SourceKind.writeup => 'Writeup',
    SourceKind.repo => 'Repository',
    SourceKind.video => 'Demo video',
    SourceKind.notebook => 'Notebook',
    SourceKind.site => 'Live site',
    SourceKind.image => 'Screenshots',
  };
}

/// A hackathon whose whole field is already deep-reviewed: a plain Overview
/// table in front of the same Competition View the triage workspace uses.
/// Nothing here is scored or grouped; it lists what exists.
class CachedWorkspace extends StatefulWidget {
  const CachedWorkspace({
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
  State<CachedWorkspace> createState() => CachedWorkspaceState();
}

class CachedWorkspaceState extends State<CachedWorkspace>
    implements OverviewWorkspace {
  bool _competition = false;
  final Set<String> _selected = {};
  late Competition _comparison = _buildComparison();

  /// The selected projects, or all of them when none is selected.
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

  /// Returns to the Overview table, keeping its selection.
  @override
  void showOverview() => setState(() => _competition = false);

  void _toggle(String id, bool on) => setState(() {
    on ? _selected.add(id) : _selected.remove(id);
    _comparison = _buildComparison();
  });

  @override
  Widget build(BuildContext context) {
    final navigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.home,
        const SizedBox(width: 8),
        WorkspaceTabs(
          labels: ['Overview', 'Competition · ${_comparison.projects.length}'],
          keys: const ['workspace-triage', 'workspace-competition'],
          active: _competition ? 1 : 0,
          onSelect: (i) => setState(() => _competition = i == 1),
        ),
      ],
    );
    final total = widget.hackathon.competition.projects.length;
    return IndexedStack(
      index: _competition ? 1 : 0,
      sizing: StackFit.expand,
      children: [
        _Overview(
          hackathon: widget.hackathon,
          navigation: navigation,
          selected: _selected,
          onToggle: _toggle,
          onViewCompetition: () => setState(() => _competition = true),
          active: widget.active && !_competition,
        ),
        ExplorationScreen(
          competition: _comparison,
          navigation: navigation,
          active: widget.active && _competition,
          scopeLabel:
              'CACHED STUDY  /  ${_comparison.projects.length.toString().padLeft(2, '0')} '
              'OF ${total.toString().padLeft(2, '0')} SUBMISSIONS',
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.hackathon,
    required this.navigation,
    required this.selected,
    required this.onToggle,
    required this.onViewCompetition,
    required this.active,
  });
  final Hackathon hackathon;
  final Widget navigation;
  final Set<String> selected;
  final void Function(String id, bool on) onToggle;
  final VoidCallback onViewCompetition;
  final bool active;

  static const _eyebrow = TextStyle(
    fontSize: 10.5,
    letterSpacing: 1.1,
    color: muted,
  );

  @override
  Widget build(BuildContext context) {
    final projects = hackathon.competition.projects;
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final width = math.max(960.0, box.maxWidth);
            final height = math.max(600.0, box.maxHeight);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  child: SizedBox(
                    height: height,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 40,
                            child: Row(
                              children: [
                                BrandMark(compact: width < brandBreakpoint),
                                const SizedBox(width: 24),
                                navigation,
                                const SizedBox(width: 20),
                                Flexible(
                                  child: Text(
                                    hackathon.competition.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${projects.length} submissions',
                                style: const TextStyle(
                                  fontSize: 26,
                                  height: 1.15,
                                  letterSpacing: -.7,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'cached study',
                                style: TextStyle(fontSize: 12.5, color: muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: rule),
                          SizedBox(
                            height: 52,
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Every submission in this study. Select some to compare them.',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: muted,
                                    ),
                                  ),
                                ),
                                if (selected.isNotEmpty)
                                  FilledButton.icon(
                                    key: const ValueKey('view-in-competition'),
                                    style: ButtonStyle(
                                      visualDensity: VisualDensity.compact,
                                      textStyle: WidgetStateProperty.all(
                                        const TextStyle(fontSize: 12.5),
                                      ),
                                    ),
                                    onPressed: onViewCompetition,
                                    icon: const Icon(
                                      Icons.scatter_plot_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'View ${selected.length} in Competition',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: rule),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        56,
                                        14,
                                        16,
                                        10,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: Text(
                                              'PROJECT',
                                              style: _eyebrow,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              'SOURCES',
                                              style: _eyebrow,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 190,
                                            child: Text(
                                              'DEEP REVIEW',
                                              style: _eyebrow,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, color: rule),
                                    Flexible(
                                      child: ListView(
                                        shrinkWrap: true,
                                        children: [
                                          for (final p in projects)
                                            _OverviewRow(
                                              project: p,
                                              selected: selected.contains(p.id),
                                              onChanged: (on) =>
                                                  onToggle(p.id, on),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.project,
    required this.selected,
    required this.onChanged,
  });
  final ProjectRepresentation project;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final kinds = {for (final s in project.sources.values) s.kind}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return InkWell(
      key: ValueKey('row-${project.id}'),
      onTap: () => onChanged(!selected),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE9F1EC) : null,
          border: const Border(bottom: BorderSide(color: rule)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Checkbox(
                key: ValueKey('select-${project.id}'),
                value: selected,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      project.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (final k in kinds)
                    Text(
                      k.label,
                      style: const TextStyle(fontSize: 12.5, color: ink),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 190,
              child: Text(
                project.generated
                    ? 'Generated automatically'
                    : 'Written by hand',
                style: const TextStyle(fontSize: 12.5, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
