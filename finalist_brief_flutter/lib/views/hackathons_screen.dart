import 'package:flutter/material.dart';

import '../hackathon/hackathon.dart';
import '../visualization/graph_view.dart';
import 'exploration_screen.dart' show BrandMark;

String _n(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

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
