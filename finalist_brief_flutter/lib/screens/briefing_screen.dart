import 'package:finalist_brief_client/finalist_brief_client.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../client.dart';
import '../widgets/cover_image.dart';
import '../widgets/page_column.dart';
import 'finalist_detail_screen.dart';

/// Steps 5–8 of the demo flow: the video, the three surfaced projects, and
/// the rest of the field.
class BriefingScreen extends StatefulWidget {
  const BriefingScreen({
    super.key,
    required this.brief,
    required this.submissions,
  });

  final Brief brief;
  final List<Submission> submissions;

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  Map<int, SubmissionAnalysis> _analyses = const {};

  @override
  void initState() {
    super.initState();
    _loadAnalyses();
  }

  Future<void> _loadAnalyses() async {
    final analyses = await client.analysis.list();
    if (!mounted) return;
    setState(() {
      _analyses = {for (final a in analyses) a.submissionId: a};
    });
  }

  Submission? _submission(int id) {
    for (final s in widget.submissions) {
      if (s.id == id) return s;
    }
    return null;
  }

  void _openDetail(Submission submission, {BriefSegment? segment}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FinalistDetailScreen(
          submission: submission,
          analysis: _analyses[submission.id],
          segment: segment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brief = widget.brief;
    final segments = brief.segments ?? const <BriefSegment>[];
    final surfacedIds = segments.map((s) => s.submissionId).toSet();
    final others = widget.submissions
        .where((s) => !surfacedIds.contains(s.id))
        .toList();
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finalist Brief'),
        backgroundColor: Colors.transparent,
      ),
      body: PageColumn(
        children: [
          Text(
            'Humor Genome: Build with Gemma',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${segments.length} of ${brief.submissionCount} submissions worth '
            'closer review · ${brief.videoDurationSec ?? 0} s briefing',
            style: textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (brief.videoUrl != null) _BriefingPlayer(url: brief.videoUrl!),
          const SizedBox(height: 32),
          Text(
            'Worth closer review',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final segment in segments) ...[
            _SurfacedCard(
              segment: segment,
              submission: _submission(segment.submissionId),
              onTap: () {
                final submission = _submission(segment.submissionId);
                if (submission != null) {
                  _openDetail(submission, segment: segment);
                }
              },
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
          Text(
            'Also analyzed (${others.length})',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Reviewed on the same four areas. Not surfaced this time, and here '
            'is why.',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final submission in others) ...[
            _OtherRow(
              submission: submission,
              analysis: _analyses[submission.id],
              onTap: () => _openDetail(submission),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 24),
          Text(
            'Cached demo: the analyses and this briefing were pre-generated for '
            'the Humor Genome dataset.',
            style: textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}

class _BriefingPlayer extends StatefulWidget {
  const _BriefingPlayer({required this.url});

  final String url;

  @override
  State<_BriefingPlayer> createState() => _BriefingPlayerState();
}

class _BriefingPlayerState extends State<_BriefingPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) => setState(() => _ready = true))
          .catchError((Object e) => setState(() => _error = '$e'));
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      if (_controller.value.position >= _controller.value.duration) {
        _controller.seekTo(Duration.zero);
      }
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playing = _ready && _controller.value.isPlaying;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: const Color(0xFF0F172A),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready) VideoPlayer(_controller),
              if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load the briefing video.\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              if (_ready)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: AnimatedOpacity(
                    opacity: playing ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Center(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.secondary,
                          foregroundColor: scheme.onSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 20,
                          ),
                        ),
                        onPressed: _toggle,
                        icon: const Icon(Icons.play_arrow, size: 32),
                        label: const Text(
                          'Play briefing',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                ),
              if (!_ready && _error == null)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
              if (_ready)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: scheme.secondary,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurfacedCard extends StatelessWidget {
  const _SurfacedCard({
    required this.segment,
    required this.submission,
    required this.onTap,
  });

  final BriefSegment segment;
  final Submission? submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: scheme.secondary,
                foregroundColor: scheme.onSecondary,
                child: Text(
                  '${segment.position}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              if (submission != null) ...[
                CoverImage(asset: submission!.coverAsset),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      segment.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (submission != null)
                      Text(
                        submission!.creator,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Why it surfaced',
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(segment.whySurfaced, style: textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Text(
                      '${segment.evidence.length} evidence items · demo '
                      'excerpt ${segment.clipStartSec ~/ 60}:'
                      '${(segment.clipStartSec % 60).toString().padLeft(2, '0')}'
                      '–${segment.clipEndSec ~/ 60}:'
                      '${(segment.clipEndSec % 60).toString().padLeft(2, '0')}',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtherRow extends StatelessWidget {
  const _OtherRow({
    required this.submission,
    required this.analysis,
    required this.onTap,
  });

  final Submission submission;
  final SubmissionAnalysis? analysis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverImage(asset: submission.coverAsset, width: 88),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      analysis?.summary ?? submission.summary,
                      style: textTheme.bodySmall,
                    ),
                    if (analysis?.whyNotSurfaced != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        analysis!.whyNotSurfaced!,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
