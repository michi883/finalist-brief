import 'dart:async';

import 'package:finalist_brief_client/finalist_brief_client.dart';
import 'package:flutter/material.dart';

import '../client.dart';
import '../widgets/cover_image.dart';
import '../widgets/link_chip.dart';
import '../widgets/page_column.dart';
import 'briefing_screen.dart';

/// Step 1–4 of the demo flow: the dataset, the one button, staged progress.
class SubmissionsScreen extends StatefulWidget {
  const SubmissionsScreen({super.key, required this.demoMode});

  final bool demoMode;

  @override
  State<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends State<SubmissionsScreen> {
  List<Submission>? _submissions;
  Brief? _latest;
  Brief? _running;
  String? _error;
  Timer? _poll;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final submissions = await client.submission.list();
      final latest = await client.brief.latestComplete();
      setState(() {
        _submissions = submissions;
        _latest = latest;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not reach the server: $e');
    }
  }

  Future<void> _generate() async {
    try {
      final brief = await client.brief.generate(BriefMode.replay);
      setState(() {
        _running = brief;
        _error = null;
      });
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } on BriefUnavailableException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _tick() async {
    final id = _running?.id;
    if (id == null || _polling) return;
    _polling = true;
    try {
      final brief = await client.brief.get(id);
      if (!mounted || brief == null) return;
      setState(() => _running = brief);
      if (brief.status == BriefStatus.complete ||
          brief.status == BriefStatus.failed) {
        _poll?.cancel();
        if (brief.status == BriefStatus.complete) {
          setState(() {
            _latest = brief;
            _running = null;
          });
          await _openBriefing(brief);
        }
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _openBriefing(Brief brief) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BriefingScreen(
          brief: brief,
          submissions: _submissions ?? const [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submissions = _submissions;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: PageColumn(
        children: [
          Text('Finalist Brief', style: textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'Humor Genome: Build with Gemma',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            submissions == null
                ? 'Loading submissions…'
                : '${submissions.length} submissions · Kaggle community hackathon',
            style: textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_running != null)
            _ProgressPanel(brief: _running!)
          else
            _ActionRow(
              demoMode: widget.demoMode,
              enabled: submissions != null,
              latest: _latest,
              onGenerate: _generate,
              onReplay: () => _openBriefing(_latest!),
            ),
          const SizedBox(height: 28),
          if (submissions != null)
            for (final submission in submissions) ...[
              _SubmissionCard(submission: submission),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.demoMode,
    required this.enabled,
    required this.latest,
    required this.onGenerate,
    required this.onReplay,
  });

  final bool demoMode;
  final bool enabled;
  final Brief? latest;
  final VoidCallback onGenerate;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: demoMode && enabled ? onGenerate : null,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Finalist Brief'),
            ),
            if (latest != null)
              OutlinedButton.icon(
                onPressed: onReplay,
                icon: const Icon(Icons.replay),
                label: const Text('Replay last brief'),
              ),
          ],
        ),
        if (!demoMode)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Live analysis is not available yet. Open this page with ?demo=1 '
              'to run the cached demo.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// Stage checklist driven by `Brief.stageLog` / `progressMessage`.
class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final done = brief.stageLog;
    final recent = done.length > 4 ? done.sublist(done.length - 4) : done;
    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Generating Finalist Brief',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text('${brief.progressPercent}%', style: textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: brief.progressPercent / 100,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
            if (done.length > recent.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${done.length - recent.length} earlier steps done',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final line in recent)
              _StageLine(
                icon: Icon(Icons.check_circle, size: 18, color: scheme.primary),
                text: line,
                muted: true,
              ),
            _StageLine(
              icon: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              text: brief.progressMessage,
              muted: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _StageLine extends StatelessWidget {
  const _StageLine({
    required this.icon,
    required this.text,
    required this.muted,
  });

  final Widget icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: icon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
                fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.submission});

  final Submission submission;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverImage(asset: submission.coverAsset),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    submission.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    submission.creator,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(submission.summary, style: textTheme.bodyMedium),
                  const SizedBox(height: 10),
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
      ),
    );
  }
}
