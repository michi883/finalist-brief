import 'package:flutter/material.dart';

import '../links.dart';
import '../representation/project.dart';
import '../visualization/graph_view.dart';

String lensName(SubmissionLens lens) =>
    lens == SubmissionLens.idea ? 'Idea' : 'Integration';

String sourceLabel(Source source, SourceRef ref) {
  if (ref.seconds != null) {
    return '${source.label} · ${formatTimestamp(ref.seconds!)}';
  }
  if (source.kind == SourceKind.repo && ref.at != null) return ref.at!;
  return ref.at == null ? source.label : '${source.label} · ${ref.at}';
}

/// Deep links where the source allows it: repo paths and video timestamps.
String? sourceUrl(Source source, SourceRef ref) {
  final url = source.url;
  if (url == null) return null;
  if (source.kind == SourceKind.repo &&
      ref.at != null &&
      url.contains('github.com')) {
    final revision = source.revision ?? 'HEAD';
    return '$url/${ref.at!.endsWith('/') ? 'tree' : 'blob'}/$revision/${ref.at}';
  }
  if (source.kind == SourceKind.video && ref.seconds != null) {
    return demoUrlAt(url, ref.seconds!);
  }
  return url;
}

extension on SourceKind {
  IconData get icon => switch (this) {
    SourceKind.video => Icons.play_circle_outline,
    SourceKind.repo => Icons.code,
    SourceKind.writeup => Icons.article_outlined,
    SourceKind.notebook => Icons.menu_book_outlined,
    SourceKind.site => Icons.public,
    SourceKind.image => Icons.image_outlined,
  };
}

const _eyebrow = TextStyle(fontSize: 9.5, letterSpacing: 1.1, color: muted);

/// Evidence status, its meaning and the grammar of glyphs, in one line.
class EvidenceLegend extends StatelessWidget {
  const EvidenceLegend({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final status in EvidenceStatus.values) ...[
        Tooltip(
          message: status.meaning,
          child: Row(
            children: [
              EvidenceGlyph(status, size: 10),
              const SizedBox(width: 5),
              Text(
                status.label,
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
      ],
      const Tooltip(
        message: 'A question that follows from a structural or evidence gap.',
        child: Row(
          children: [
            QuestionMark(size: 15),
            SizedBox(width: 5),
            Text(
              'Judge question',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
    ],
  );
}

class QuestionMark extends StatelessWidget {
  const QuestionMark({super.key, this.size = 20, this.filled = false});
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? questionColor : paper,
      border: Border.all(color: questionColor, width: 1.3),
    ),
    child: Text(
      '?',
      style: TextStyle(
        fontSize: size * .6,
        height: 1,
        fontWeight: FontWeight.w700,
        color: filled ? Colors.white : questionColor,
      ),
    ),
  );
}

/// A small marker attached to the node that raises a question.
class QuestionHint extends StatelessWidget {
  const QuestionHint({
    super.key,
    required this.question,
    required this.selected,
    required this.onTap,
  });
  final JudgeQuestion question;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: question.kind.label,
    child: Semantics(
      button: true,
      label: 'Judge question: ${question.question}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: QuestionMark(filled: selected),
        ),
      ),
    ),
  );
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    super.key,
    required this.eyebrow,
    required this.onClose,
    required this.children,
    this.maxHeight = 520,
  });
  final Widget eyebrow;
  final VoidCallback onClose;
  final List<Widget> children;
  final double maxHeight;

  @override
  Widget build(BuildContext context) => GestureDetector(
    // Taps inside the card never fall through to close it.
    onTap: () {},
    child: Container(
      width: 340,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: rule),
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: .1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 0),
            child: Row(
              children: [
                Expanded(child: eyebrow),
                IconButton(
                  key: const ValueKey('close-inspector'),
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: muted),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.status);
  final EvidenceStatus status;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      EvidenceGlyph(status, size: 11),
      const SizedBox(width: 6),
      Text(
        status.label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: status == EvidenceStatus.inferred ? muted : accent,
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          status.meaning,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: muted),
        ),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _eyebrow),
        const SizedBox(height: 6),
        ...children,
      ],
    ),
  );
}

class SourceLine extends StatelessWidget {
  const SourceLine({super.key, required this.project, required this.ref});
  final ProjectRepresentation project;
  final SourceRef ref;

  @override
  Widget build(BuildContext context) {
    final source = project.sources[ref.source]!;
    final url = sourceUrl(source, ref);
    final label = sourceLabel(source, ref);
    return InkWell(
      onTap: url == null ? null : () => openUrl(url),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(source.kind.icon, size: 13, color: muted),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        color: url == null ? ink : accent,
                        fontFamily: source.kind == SourceKind.repo
                            ? 'monospace'
                            : null,
                        fontSize: source.kind == SourceKind.repo ? 11 : 11.5,
                      ),
                    ),
                    if (ref.detail.isNotEmpty)
                      TextSpan(
                        text: '  ${ref.detail}',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
            if (url != null)
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 1),
                child: Icon(Icons.north_east, size: 11, color: muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame(this.project, this.frame);
  final ProjectRepresentation project;
  final EvidenceFrame frame;

  @override
  Widget build(BuildContext context) {
    final caption = sourceLabel(project.sources[frame.ref.source]!, frame.ref);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: 'Enlarge frame: $caption',
            child: MouseRegion(
              cursor: SystemMouseCursors.zoomIn,
              child: GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  barrierColor: ink.withValues(alpha: .6),
                  builder: (context) => GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(frame.image),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              caption,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.asset(
                      frame.image,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, _, _) => const ColoredBox(color: paper),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(caption, style: const TextStyle(fontSize: 10.5, color: muted)),
        ],
      ),
    );
  }
}

List<Widget> _evidenceBody(
  ProjectRepresentation project,
  Evidence evidence,
) => [
  const SizedBox(height: 10),
  _StatusLine(evidence.status),
  const SizedBox(height: 8),
  Text(
    evidence.note,
    style: const TextStyle(fontSize: 12.5, height: 1.4, color: ink),
  ),
  if (evidence.frame != null) _Frame(project, evidence.frame!),
  if (evidence.refs.isNotEmpty)
    _Section('SOURCES', [
      for (final ref in evidence.refs) SourceLine(project: project, ref: ref),
    ]),
];

class _MappingRow extends StatelessWidget {
  const _MappingRow(this.project, this.mapping, this.onTap);
  final ProjectRepresentation project;
  final Correspondence mapping;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: EvidenceGlyph(mapping.evidence.status, size: 9),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mapping.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                Text(
                  mapping.evidence.note,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow(this.question, this.onTap);
  final JudgeQuestion question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const QuestionMark(size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              question.question,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: questionColor,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Why Finalist Brief believes a node exists, and where it leads next.
class NodeInspector extends StatelessWidget {
  const NodeInspector({
    super.key,
    required this.project,
    required this.ref,
    required this.onClose,
    required this.onMapping,
    required this.onQuestion,
    this.maxHeight = 520,
  });
  final ProjectRepresentation project;
  final GraphRef ref;
  final VoidCallback onClose;
  final ValueChanged<Correspondence> onMapping;
  final ValueChanged<JudgeQuestion> onQuestion;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final node = project.graph(ref.lens).node(ref.node!);
    final mappings = project.mappingFor(ref);
    final questions = project.questions
        .where((q) => q.anchors.contains(ref))
        .toList();
    return _CardShell(
      key: ValueKey('inspector-${ref.lens.name}-${node.id}'),
      maxHeight: maxHeight,
      onClose: onClose,
      eyebrow: Row(
        children: [
          Text('${lensName(ref.lens).toUpperCase()}  ·  ', style: _eyebrow),
          Icon(node.kind.icon, size: 11, color: node.kind.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              node.kind.label,
              overflow: TextOverflow.ellipsis,
              style: _eyebrow.copyWith(color: node.kind.color),
            ),
          ),
        ],
      ),
      children: [
        Text(
          node.label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
        if (node.detail.isNotEmpty)
          Text(
            node.detail,
            style: const TextStyle(fontSize: 11.5, color: muted),
          ),
        ..._evidenceBody(project, node.evidence ?? Evidence.unrecorded),
        if (mappings.isNotEmpty ||
            (ref.lens == SubmissionLens.idea && project.mapping.isNotEmpty))
          _Section(
            ref.lens == SubmissionLens.idea
                ? 'HOW IT IS BUILT'
                : 'WHAT IT REALIZES',
            mappings.isEmpty
                ? [
                    const Text(
                      'Not traced to the other structure.',
                      style: TextStyle(fontSize: 11.5, color: muted),
                    ),
                  ]
                : [
                    for (final m in mappings)
                      _MappingRow(project, m, () => onMapping(m)),
                  ],
          ),
        if (questions.isNotEmpty)
          _Section('QUESTION FOR THE TEAM', [
            for (final q in questions) _QuestionRow(q, () => onQuestion(q)),
          ]),
      ],
    );
  }
}

/// An Idea ↔ Integration relationship and its provenance.
class MappingInspector extends StatelessWidget {
  const MappingInspector({
    super.key,
    required this.project,
    required this.mapping,
    required this.onClose,
    required this.onNode,
    required this.onQuestion,
    this.maxHeight = 520,
  });
  final ProjectRepresentation project;
  final Correspondence mapping;
  final VoidCallback onClose;
  final ValueChanged<GraphRef> onNode;
  final ValueChanged<JudgeQuestion> onQuestion;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final questions = project.questions
        .where((q) => q.anchors.any(mapping.refs.contains))
        .toList();
    Widget nodes(SubmissionLens lens, List<String> ids) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (ids.isEmpty)
          const Text(
            'No counterpart found',
            style: TextStyle(fontSize: 11.5, color: muted),
          ),
        for (final id in ids)
          ActionChip(
            visualDensity: VisualDensity.compact,
            labelStyle: const TextStyle(fontSize: 11),
            label: Text(project.graph(lens).node(id).label),
            onPressed: () => onNode(GraphRef.node(lens, id)),
          ),
      ],
    );
    return _CardShell(
      key: ValueKey('mapping-${mapping.label}'),
      maxHeight: maxHeight,
      onClose: onClose,
      eyebrow: const Text('IDEA  →  INTEGRATION', style: _eyebrow),
      children: [
        Text(
          mapping.label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
        ..._evidenceBody(project, mapping.evidence),
        _Section('IDEA', [nodes(SubmissionLens.idea, mapping.idea)]),
        _Section('INTEGRATION', [
          nodes(SubmissionLens.integration, mapping.integration),
        ]),
        if (questions.isNotEmpty)
          _Section('QUESTION FOR THE TEAM', [
            for (final q in questions) _QuestionRow(q, () => onQuestion(q)),
          ]),
      ],
    );
  }
}

/// A concise question for the team, and the gap it comes from.
class QuestionInspector extends StatelessWidget {
  const QuestionInspector({
    super.key,
    required this.project,
    required this.question,
    required this.onClose,
    required this.onNode,
    this.maxHeight = 520,
  });
  final ProjectRepresentation project;
  final JudgeQuestion question;
  final VoidCallback onClose;
  final ValueChanged<GraphRef> onNode;
  final double maxHeight;

  String _anchorLabel(GraphRef ref) {
    final graph = project.graph(ref.lens);
    return ref.isNode
        ? graph.node(ref.node!).label
        : '${graph.node(ref.from!).label} → ${graph.node(ref.to!).label}';
  }

  @override
  Widget build(BuildContext context) => _CardShell(
    key: ValueKey('question-${question.id}'),
    maxHeight: maxHeight,
    onClose: onClose,
    eyebrow: Row(
      children: [
        const QuestionMark(size: 14, filled: true),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            question.kind.label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: _eyebrow.copyWith(color: questionColor),
          ),
        ),
      ],
    ),
    children: [
      const SizedBox(height: 4),
      Text(
        question.question,
        style: const TextStyle(
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
      ),
      _Section('WHY FINALIST BRIEF ASKS', [
        Text(
          question.basis,
          style: const TextStyle(fontSize: 12, height: 1.45, color: muted),
        ),
      ]),
      if (question.refs.isNotEmpty)
        _Section('SOURCES', [
          for (final ref in question.refs)
            SourceLine(project: project, ref: ref),
        ]),
      _Section('ANCHORED TO', [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final ref in question.anchors)
              ActionChip(
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 11),
                label: Text('${lensName(ref.lens)} · ${_anchorLabel(ref)}'),
                onPressed: ref.isNode ? () => onNode(ref) : null,
              ),
          ],
        ),
      ]),
    ],
  );
}
