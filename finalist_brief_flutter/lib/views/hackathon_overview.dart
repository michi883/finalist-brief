import 'package:flutter/material.dart';

import '../hackathon/hackathon.dart';
import '../representation/project.dart';
import '../triage/triage.dart';
import '../visualization/graph_view.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _date(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// What was acquired for a hackathon and what can be done with it. Every
/// figure is counted from the bundled data. The two actions lead to the
/// hackathon's other workspaces, exactly as their tabs do.
class HackathonOverview extends StatelessWidget {
  const HackathonOverview({
    super.key,
    required this.hackathon,
    required this.onBrowse,
    required this.onExplore,
  });
  final Hackathon hackathon;
  final VoidCallback onBrowse;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final (subtitle, footer, facts) = _facts();
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, box) {
                  final narrow = box.maxWidth < 900;
                  final tiles = [
                    for (final fact in facts) _Tile(fact, narrow: narrow),
                  ];
                  return narrow
                      ? Wrap(spacing: 14, runSpacing: 14, children: tiles)
                      : IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final (i, tile) in tiles.indexed) ...[
                                if (i > 0) const SizedBox(width: 14),
                                Expanded(child: tile),
                              ],
                            ],
                          ),
                        );
                },
              ),
              const SizedBox(height: 28),
              const Text(
                'WHAT CAN I DO NEXT',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: muted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.icon(
                    key: const ValueKey('overview-browse'),
                    onPressed: onBrowse,
                    icon: const Icon(Icons.table_rows_outlined, size: 16),
                    label: const Text('Browse submissions'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('overview-explore'),
                    onPressed: onExplore,
                    icon: const Icon(Icons.scatter_plot_outlined, size: 16),
                    label: const Text('Explore competition'),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    footer,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, String, List<_Fact>) _facts() {
    final triage = hackathon.triage;
    final projects = hackathon.competition.projects;
    final reviews = projects.length;
    if (triage != null) {
      final all = triage.submissions;
      final total = all.length;
      int count(bool Function(TriageSubmission) test) => all.where(test).length;
      final inspected = count((s) => s.repo != null);
      final notFound = count((s) => s.repoAccess == RepoAccess.notFound);
      final notLinked = count((s) => s.repoAccess == RepoAccess.notLinked);
      final playable = count((s) => s.demoAccess == DemoAccess.available);
      final privateDemos = count((s) => s.demoAccess == DemoAccess.private);
      final unavailable = count((s) => s.demoAccess == DemoAccess.unavailable);
      final noDemo = count((s) => s.demoAccess == DemoAccess.notLinked);
      final checked = ([
        triage.checked,
        for (final s in all)
          if (s.checked != null) s.checked!,
      ]..sort()).last;
      final complete = total == triage.fieldSize;
      return (
        'Sponsor technology · ${triage.sponsorTech} · submissions opened '
            '${_date(triage.submissionsOpen)} · deadline ${_date(triage.deadline)}',
        'Links checked ${_date(DateTime.parse(checked))}',
        [
          _Fact(
            label: 'Submissions',
            value: '$total',
            unit: complete
                ? 'acquired, the full field'
                : 'acquired of ${triage.fieldSize}',
            detail: triage.sample,
            done: complete,
          ),
          _Fact(
            label: 'Writeups',
            value: '$total',
            unit: 'read',
            detail: '${triage.jevModel} · ${triage.jevScope}',
          ),
          _Fact(
            label: 'Repositories',
            value: '$inspected',
            unit: 'inspected at the deadline',
            detail:
                '$notFound links return 404 · $notLinked have no repository linked',
          ),
          _Fact(
            label: 'Demo videos',
            value: '$playable',
            unit: 'available',
            detail:
                '$privateDemos private · $unavailable unavailable · $noDemo not linked',
          ),
          _Fact(
            label: 'Deep reviews',
            value: '$reviews',
            unit: 'of $total submissions',
            detail:
                'Idea and integration graphs with cited evidence and judge questions.',
          ),
        ],
      );
    }
    int cited(SourceKind kind) => projects
        .where((p) => p.sources.values.any((s) => s.kind == kind))
        .length;
    final repos = cited(SourceKind.repo);
    final videos = cited(SourceKind.video);
    final generated = projects.where((p) => p.generated).length;
    return (
      'Sponsor technology · ${hackathon.sponsorTech} · cached study',
      'Cached study',
      [
        _Fact(
          label: 'Submissions',
          value: '$reviews',
          unit: 'cached',
          detail: 'A fixed set, stored with the app rather than fetched.',
        ),
        _Fact(
          label: 'Writeups',
          value: '${cited(SourceKind.writeup)}',
          unit: 'cited',
          detail: 'Each deep review quotes the writeup it was read from.',
        ),
        _Fact(
          label: 'Repositories',
          value: '$repos',
          unit: 'cited',
          detail: '${reviews - repos} without a repository source.',
        ),
        _Fact(
          label: 'Demo videos',
          value: '$videos',
          unit: 'cited',
          detail: '${reviews - videos} without a demo video source.',
        ),
        _Fact(
          label: 'Deep reviews',
          value: '$reviews',
          unit: 'of $reviews submissions',
          detail: generated == 0
              ? 'Written by hand from the cited sources.'
              : '$generated generated automatically, the rest written by hand.',
        ),
      ],
    );
  }
}

class _Fact {
  const _Fact({
    required this.label,
    required this.value,
    required this.unit,
    required this.detail,
    this.done = true,
  });
  final String label;
  final String value;
  final String unit;
  final String detail;
  final bool done;
}

class _Tile extends StatelessWidget {
  const _Tile(this.fact, {required this.narrow});
  final _Fact fact;
  final bool narrow;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('overview-${fact.label.toLowerCase().replaceAll(' ', '-')}'),
    width: narrow ? 280 : null,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: rule),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fact.label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            color: muted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          fact.value,
          style: const TextStyle(
            fontSize: 32,
            height: 1.1,
            letterSpacing: -.8,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(fact.unit, style: const TextStyle(fontSize: 13, color: ink)),
        const SizedBox(height: 8),
        Text(
          fact.detail,
          style: const TextStyle(fontSize: 12, color: muted, height: 1.4),
        ),
      ],
    ),
  );
}
