import 'package:flutter/material.dart';

import '../hackathon/hackathon.dart';
import '../representation/project.dart';
import '../visualization/graph_view.dart';

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

/// The Submissions table of a hackathon whose whole field is already
/// deep-reviewed: a plain list, with nothing scored or grouped. It shows what
/// exists and lets the judge select some to see in Competition.
class CachedSubmissions extends StatelessWidget {
  const CachedSubmissions({
    super.key,
    required this.hackathon,
    required this.selected,
    required this.onToggle,
    required this.onViewCompetition,
  });
  final Hackathon hackathon;
  final Set<String> selected;
  final void Function(String id, bool on) onToggle;
  final VoidCallback onViewCompetition;

  static const _eyebrow = TextStyle(
    fontSize: 10.5,
    letterSpacing: 1.1,
    color: muted,
  );

  @override
  Widget build(BuildContext context) {
    final projects = hackathon.competition.projects;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Every submission in this study. Select some to see them in Competition.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: muted),
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
                  icon: const Icon(Icons.scatter_plot_outlined, size: 16),
                  label: Text('View ${selected.length} in Competition'),
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
                    padding: EdgeInsets.fromLTRB(56, 14, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text('PROJECT', style: _eyebrow),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text('SOURCES', style: _eyebrow),
                        ),
                        SizedBox(
                          width: 190,
                          child: Text('DEEP REVIEW', style: _eyebrow),
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
                            onChanged: (on) => onToggle(p.id, on),
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
