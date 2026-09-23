import 'package:finalist_brief_client/finalist_brief_client.dart';
import 'package:flutter/material.dart';

import '../links.dart';
import '../widgets/cover_image.dart';
import '../widgets/link_chip.dart';
import '../widgets/page_column.dart';

/// Step 7 of the demo flow: why a project surfaced and the evidence behind it.
/// Also used for non-surfaced submissions, where it shows why not.
class FinalistDetailScreen extends StatelessWidget {
  const FinalistDetailScreen({
    super.key,
    required this.submission,
    required this.analysis,
    this.segment,
  });

  final Submission submission;
  final SubmissionAnalysis? analysis;
  final BriefSegment? segment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final analysis = this.analysis;
    final surfaced = segment != null;
    final evidence = segment?.evidence ?? analysis?.evidence ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(surfaced ? 'Worth closer review' : 'Also analyzed'),
        backgroundColor: Colors.transparent,
      ),
      body: PageColumn(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverImage(asset: submission.coverAsset, width: 160),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.title,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      submission.creator,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        LinkChip(
                          label: 'Writeup',
                          url: submission.kaggleUrl,
                          icon: Icons.article_outlined,
                        ),
                        if (submission.repoUrl != null)
                          LinkChip(
                            label: 'Repo',
                            url: submission.repoUrl!,
                            icon: Icons.code,
                          ),
                        if (submission.demoUrl != null)
                          LinkChip(
                            label: submission.hasDemoVideo
                                ? 'Demo video'
                                : 'Demo',
                            url: submission.demoUrl!,
                            icon: submission.hasDemoVideo
                                ? Icons.play_circle_outline
                                : Icons.science_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            title: surfaced ? 'Why it surfaced' : 'Why it was not surfaced',
            accent: true,
            child: Text(
              segment?.whySurfaced ??
                  analysis?.whyNotSurfaced ??
                  analysis?.whyWorthAttention ??
                  '',
              style: textTheme.bodyLarge,
            ),
          ),
          if (analysis != null) ...[
            _Section(
              title: 'Summary',
              child: Text(analysis.summary, style: textTheme.bodyMedium),
            ),
            _Section(
              title: 'Evidence',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in evidence)
                    _EvidenceTile(item: item, submission: submission),
                ],
              ),
            ),
            _Section(
              title: 'Assessment by area',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AreaNote('Technical implementation', analysis.technical),
                  _AreaNote('Demonstration', analysis.demonstration),
                  _AreaNote('Quality of idea', analysis.idea),
                  _AreaNote('Gemma usage', analysis.gemmaUsage),
                ],
              ),
            ),
            if (analysis.highlights.isNotEmpty)
              _Section(
                title: 'Moments worth watching',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final h in analysis.highlights)
                      _HighlightTile(highlight: h, submission: submission),
                  ],
                ),
              ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.accent = false,
  });

  final String title;
  final Widget child;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent ? scheme.secondary : null,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.item, required this.submission});

  final EvidenceItem item;
  final Submission submission;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final seconds = timestampOf(item.ref);
    final (label, icon) = switch (item.source) {
      EvidenceSource.video => ('Demo video', Icons.play_circle_outline),
      EvidenceSource.repo => ('Repo', Icons.code),
      EvidenceSource.description => ('Writeup', Icons.article_outlined),
    };

    String? url;
    String? action;
    if (seconds != null && submission.demoUrl != null) {
      url = demoUrlAt(submission.demoUrl!, seconds);
      action = 'Open demo at ${formatTimestamp(seconds)}';
    } else if (item.ref != null && item.ref!.startsWith('http')) {
      url = item.ref;
      action = switch (item.source) {
        EvidenceSource.repo => 'Open repo',
        EvidenceSource.description => 'Open',
        EvidenceSource.video => 'Open demo',
      };
    }

    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(
              avatar: Icon(icon, size: 16),
              label: Text(label),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(item.detail, style: textTheme.bodyMedium),
              ),
            ),
            if (url != null && action != null)
              TextButton.icon(
                onPressed: () => openUrl(url!),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(action),
              ),
          ],
        ),
      ),
    );
  }
}

class _AreaNote extends StatelessWidget {
  const _AreaNote(this.area, this.assessment);

  final String area;
  final AreaAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            area,
            style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(assessment.note, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({required this.highlight, required this.submission});

  final Highlight highlight;
  final Submission submission;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final range =
        '${formatTimestamp(highlight.startSec)}–'
        '${formatTimestamp(highlight.endSec)}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Chip(
        label: Text(range),
        visualDensity: VisualDensity.compact,
      ),
      title: Text(highlight.whatIsShown, style: textTheme.bodyMedium),
      subtitle: Text(
        highlight.whyItMatters,
        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: submission.demoUrl == null
          ? null
          : IconButton(
              tooltip: 'Open demo at ${formatTimestamp(highlight.startSec)}',
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: () =>
                  openUrl(demoUrlAt(submission.demoUrl!, highlight.startSec)),
            ),
    );
  }
}
