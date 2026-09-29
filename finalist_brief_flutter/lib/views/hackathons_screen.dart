import 'package:flutter/material.dart';

import '../hackathon/hackathon.dart';
import '../representation/project.dart';
import '../triage/triage.dart';
import '../visualization/graph_view.dart';
import 'exploration_screen.dart' show BrandMark;

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

String _n(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

/// A workspace's own views (Overview, Competition) as a quiet tab strip.
class WorkspaceTabs extends StatelessWidget {
  const WorkspaceTabs({
    super.key,
    required this.labels,
    this.keys,
    required this.active,
    required this.onSelect,
    this.quiet = true,
  });
  final List<String> labels;
  final List<String>? keys;
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
              key: ValueKey(keys?[i] ?? 'workspace-tab-$i'),
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

/// A workspace that can return to its Overview when entered from Acquisition.
abstract interface class OverviewWorkspace {
  void showOverview();
}

/// A quiet link back to the list of hackathons.
class BackToHackathons extends StatelessWidget {
  const BackToHackathons({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const ValueKey('back-to-hackathons'),
    style: TextButton.styleFrom(
      foregroundColor: muted,
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(fontSize: 12),
    ),
    onPressed: onTap,
    icon: const Icon(Icons.arrow_back, size: 14),
    label: const Text('Hackathons'),
  );
}

/// The entry screen: each hackathon is a workspace with its own status.
class HackathonsScreen extends StatelessWidget {
  const HackathonsScreen({
    super.key,
    required this.sources,
    required this.loads,
    required this.onOpen,
  });
  final List<HackathonSource> sources;
  final Map<String, Future<Hackathon>> loads;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) => _Page(
    header: const SizedBox.shrink(),
    children: [
      const Text(
        'Hackathons',
        style: TextStyle(
          fontSize: 26,
          height: 1.15,
          letterSpacing: -.7,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Choose a hackathon to review.',
        style: TextStyle(fontSize: 13, color: muted),
      ),
      const SizedBox(height: 24),
      for (final (i, source) in sources.indexed) ...[
        _HackathonCard(
          source: source,
          future: loads[source.id]!,
          onTap: () => onOpen(i),
        ),
        const SizedBox(height: 12),
      ],
    ],
  );
}

class _HackathonCard extends StatelessWidget {
  const _HackathonCard({
    required this.source,
    required this.future,
    required this.onTap,
  });
  final HackathonSource source;
  final Future<Hackathon> future;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FutureBuilder<Hackathon>(
    future: future,
    builder: (context, snapshot) {
      final hackathon = snapshot.data;
      final triage = hackathon?.triage;
      final title = triage?.title ?? source.name;
      final ready = hackathon != null;
      final facts = <String>[
        if (hackathon != null) ...[
          _n(
            triage?.submissions.length ?? hackathon.competition.projects.length,
            'submission',
          ),
          _n(hackathon.competition.projects.length, 'deep review'),
        ],
      ];
      final status = switch (snapshot) {
        AsyncSnapshot(hasError: true) => 'Could not load',
        _ when !ready => 'Loading',
        _ when triage == null => 'Cached study',
        _ when triage.submissions.length == triage.fieldSize =>
          'Acquired and indexed',
        _ => 'Pilot sample',
      };
      return Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: rule),
        ),
        child: InkWell(
          key: ValueKey('hackathon-${source.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: ready ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hackathon == null
                            ? ' '
                            : 'Sponsor technology · ${hackathon.sponsorTech}',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 18,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StatusPill(status, done: ready && triage != null),
                          for (final fact in facts)
                            Text(
                              fact,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: ink,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 18, color: muted),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label, {required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? accent : const Color(0xFFB6C6BD),
        ),
      ),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(fontSize: 12.5, color: muted)),
    ],
  );
}

/// What was acquired and indexed for a hackathon with a triage table, before
/// its overview opens. Every figure is counted from the bundled data.
class HackathonStatusScreen extends StatelessWidget {
  const HackathonStatusScreen({
    super.key,
    required this.hackathon,
    required this.onOpenOverview,
    required this.onBack,
  });
  final Hackathon hackathon;
  final VoidCallback onOpenOverview;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final triage = hackathon.triage;
    final projects = hackathon.competition.projects;
    final reviews = projects.length;
    final List<_StatusRow> rows;
    final String title;
    final String subtitle;
    final String footer;
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
      title = triage.title;
      subtitle =
          'Submissions opened ${_date(triage.submissionsOpen)} · '
          'deadline ${_date(triage.deadline)}';
      footer = 'Links checked ${_date(DateTime.parse(checked))}';
      rows = [
        _StatusRow(
          label: 'Gallery',
          value: '$total of ${triage.fieldSize}',
          unit: 'submissions acquired',
          detail: triage.sample,
          done: complete,
        ),
        _StatusRow(
          label: 'Writeups',
          value: '$total of $total',
          unit: 'read',
          detail: '${triage.jevModel} · ${triage.jevScope}',
        ),
        _StatusRow(
          label: 'Repositories',
          value: '$inspected',
          unit: 'inspected at the deadline',
          detail:
              '$notFound links return 404 · $notLinked have no repository linked',
        ),
        _StatusRow(
          label: 'Demo videos',
          value: '$playable',
          unit: 'play',
          detail:
              '$privateDemos private · $unavailable unavailable · $noDemo not linked',
        ),
        _StatusRow(
          label: 'Deep reviews',
          value: '$reviews of $total',
          unit: 'submissions',
          detail:
              'Idea and integration graphs with cited evidence and judge questions.',
          last: true,
        ),
      ];
    } else {
      int cited(SourceKind kind) => projects
          .where((p) => p.sources.values.any((s) => s.kind == kind))
          .length;
      final repos = cited(SourceKind.repo);
      final videos = cited(SourceKind.video);
      final generated = projects.where((p) => p.generated).length;
      title = hackathon.name;
      subtitle = 'Sponsor technology · ${hackathon.sponsorTech} · Cached study';
      footer = 'Cached study';
      rows = [
        _StatusRow(
          label: 'Submissions',
          value: '$reviews',
          unit: 'cached',
          detail: 'A fixed set, stored with the app rather than fetched.',
        ),
        _StatusRow(
          label: 'Writeups',
          value: '${cited(SourceKind.writeup)} of $reviews',
          unit: 'cited',
          detail: 'Each deep review quotes the writeup it was read from.',
        ),
        _StatusRow(
          label: 'Repositories',
          value: '$repos of $reviews',
          unit: 'cited',
          detail: '${reviews - repos} without a repository source.',
        ),
        _StatusRow(
          label: 'Demo videos',
          value: '$videos of $reviews',
          unit: 'cited',
          detail: '${reviews - videos} without a demo video source.',
        ),
        _StatusRow(
          label: 'Deep reviews',
          value: '$reviews of $reviews',
          unit: 'submissions',
          detail: generated == 0
              ? 'Written by hand from the cited sources.'
              : '$generated generated automatically, the rest written by hand.',
          last: true,
        ),
      ];
    }
    return _Page(
      header: BackToHackathons(onTap: onBack),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            height: 1.15,
            letterSpacing: -.7,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: muted)),
        const SizedBox(height: 24),
        ...rows,
        const SizedBox(height: 22),
        Row(
          children: [
            FilledButton.icon(
              key: const ValueKey('open-overview'),
              onPressed: onOpenOverview,
              icon: const Icon(Icons.arrow_forward, size: 16),
              iconAlignment: IconAlignment.end,
              label: const Text('Open overview'),
            ),
            const SizedBox(width: 16),
            Text(footer, style: const TextStyle(fontSize: 12, color: muted)),
          ],
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.detail,
    this.done = true,
    this.last = false,
  });
  final String label;
  final String value;
  final String unit;
  final String detail;
  final bool done;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13),
    decoration: BoxDecoration(
      border: Border(
        top: const BorderSide(color: rule),
        bottom: last ? const BorderSide(color: rule) : BorderSide.none,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              color: muted,
              height: 1.9,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: '  $unit',
                      style: const TextStyle(fontSize: 13, color: ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(fontSize: 12, color: muted, height: 1.4),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(
            done ? Icons.check_circle_outline : Icons.pending_outlined,
            size: 17,
            color: done ? accent : muted,
          ),
        ),
      ],
    ),
  );
}

/// Shared frame: brand, an optional quiet header control, and a centred
/// column that scrolls on short windows.
class _Page extends StatelessWidget {
  const _Page({required this.header, required this.children});
  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final gutter = box.maxWidth > 1100 ? 48.0 : 24.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          const BrandMark(),
                          const SizedBox(width: 24),
                          header,
                        ],
                      ),
                    ),
                    const SizedBox(height: 44),
                    ...children,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
