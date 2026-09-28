import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../hackathon/hackathon.dart';
import '../links.dart';
import '../triage/lanes.dart';
import '../triage/review_lens.dart';
import '../triage/triage.dart';
import '../triage/triage_query.dart';
import '../visualization/graph_view.dart';
import 'exploration_screen.dart' show BrandMark, brandBreakpoint;

extension LaneAppearance on Lane {
  Color get color => switch (this) {
    Lane.substantialBuild => accent,
    Lane.distinctiveIdea => const Color(0xFF916223),
    Lane.underTold => const Color(0xFF2F6F9F),
    Lane.unresolved => muted,
  };
}

extension SourceAppearance on SignalSource {
  IconData get icon => switch (this) {
    SignalSource.links => Icons.link,
    SignalSource.repo => Icons.code,
    SignalSource.jev => Icons.notes,
  };
}

String _k(int n) =>
    n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

const _eyebrow = TextStyle(fontSize: 9.5, letterSpacing: 1.1, color: muted);
const _small = TextStyle(fontSize: 11.5, color: ink, height: 1.3);
const _faint = TextStyle(fontSize: 10.5, color: muted, height: 1.3);
final _compact = ButtonStyle(
  visualDensity: VisualDensity.compact,
  textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12.5)),
);

/// How the writeup describes Serverpod, in Jev's three answers.
const _roleInWriteup = {
  'specific': 'Writeup describes what Serverpod does',
  'named_only': 'Writeup only names Serverpod',
  'not_mentioned': 'Writeup doesn’t mention Serverpod',
};

const _mentionNames = {
  'database': 'Database',
  'realtime': 'Real-time',
  'scheduling': 'Scheduling',
  'auth': 'Sign-in',
  'uploads': 'Uploads',
  'cloudDeploy': 'Serverpod Cloud',
  'tests': 'Tests',
};

String _codeLine(TriageSubmission s) => s.repo != null
    ? 'Repository inspected at the deadline snapshot'
    : switch (s.repoAccess) {
        RepoAccess.public =>
          'Public, but no Serverpod package before the deadline',
        RepoAccess.notFound => 'Repository link returns 404',
        RepoAccess.notLinked => 'No repository linked',
      };

String _demoLine(DemoAccess demo) => switch (demo) {
  DemoAccess.available => 'Demo video plays',
  DemoAccess.private => 'Demo video is private',
  DemoAccess.unavailable => 'Demo video is unavailable',
  DemoAccess.notLinked => 'No demo video linked',
};

String _roleLine(TriageSubmission s, TriageAssessment a) {
  final f = s.repo?.footprint;
  return switch (a.centrality) {
    SponsorCentrality.central || SponsorCentrality.supporting =>
      'The app calls ${_plural(f!.appCalls.length, 'endpoint method')}',
    SponsorCentrality.peripheral =>
      'The app calls none of its ${_plural(f!.endpointMethods, 'endpoint method')}',
    SponsorCentrality.unknown => 'No code to inspect',
  };
}

/// The Serverpod pilot's primary view. A judge chooses a question (a
/// [ReviewLens]); the table then shows only the rows and the few columns that
/// answer it. Each row's detail opens on request, and deeper evidence inside
/// it only when asked for. Signals from separate sources stay apart; nothing
/// is scored.
class TriageView extends StatefulWidget {
  const TriageView({
    super.key,
    required this.hackathon,
    required this.navigation,
    required this.selected,
    required this.reviews,
    required this.onSelect,
    required this.onReview,
    required this.onOpenDeepReview,
    required this.onViewCompetition,
    this.active = true,
  });
  final Hackathon hackathon;
  final Widget navigation;

  /// Submissions chosen for the Competition View.
  final Set<String> selected;
  final Map<String, ReviewStatus> reviews;
  final void Function(String id, bool selected) onSelect;
  final void Function(String id, ReviewStatus status) onReview;
  final ValueChanged<String> onOpenDeepReview;
  final VoidCallback onViewCompetition;
  final bool active;

  @override
  State<TriageView> createState() => _TriageViewState();
}

class _TriageViewState extends State<TriageView> {
  TriageQuery _query = const TriageQuery();
  String? _detail;
  final _search = TextEditingController();
  final _focus = FocusNode(debugLabel: 'triage');
  final _horizontal = ScrollController();
  final _vertical = ScrollController();

  TriageDataset get _triage => widget.hackathon.triage!;
  String get _sponsor => _triage.sponsorTech;

  @override
  void didUpdateWidget(TriageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _focus.requestFocus();
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  List<TriageRow> get _allRows => [
    for (final s in _triage.submissions)
      TriageRow(
        submission: s,
        assessment: widget.hackathon.assessments[s.id]!,
        hasRepresentation: widget.hackathon.hasRepresentation(s.id),
        review: widget.reviews[s.id] ?? ReviewStatus.notStarted,
      ),
  ];

  void _setQuery(TriageQuery query) => setState(() => _query = query);

  void _open(String id) => setState(() => _detail = _detail == id ? null : id);

  void _clearSearch() {
    _search.clear();
    _setQuery(_query.copyWith(search: ''));
  }

  @override
  Widget build(BuildContext context) {
    final all = _allRows;
    final rows = _query.apply(all);
    final detail = _detail == null
        ? null
        : all.where((r) => r.id == _detail).firstOrNull;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              if (_detail != null) setState(() => _detail = null);
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focus,
          autofocus: widget.active,
          child: Scaffold(
            backgroundColor: paper,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.max(960.0, constraints.maxWidth);
                  final height = math.max(760.0, constraints.maxHeight);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      child: SingleChildScrollView(
                        child: SizedBox(
                          height: height,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                            child: _content(all, rows, detail, width),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(
    List<TriageRow> all,
    List<TriageRow> rows,
    TriageRow? detail,
    double width,
  ) {
    final comparable = widget.selected
        .where(widget.hackathon.hasRepresentation)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              BrandMark(compact: width < brandBreakpoint),
              const SizedBox(width: 24),
              widget.navigation,
              const SizedBox(width: 20),
              Flexible(
                child: Text(
                  _triage.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 12),
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
              '${all.length} submissions',
              style: const TextStyle(
                fontSize: 26,
                height: 1.15,
                letterSpacing: -.7,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _triage.submissions.length == _triage.fieldSize
                    ? 'full field'
                    : 'pilot sample of ${_triage.fieldSize}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: muted),
              ),
            ),
            TextButton(
              key: const ValueKey('lane-rules'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: muted,
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _RulesDialog(_triage),
              ),
              child: const Text(
                'How this works',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(child: _lensBar(all)),
              const SizedBox(width: 16),
              SizedBox(width: 230, child: _searchField()),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1, color: rule),
        SizedBox(height: 44, child: _lensLine(comparable)),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _table(rows)),
              if (detail != null)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: 440,
                  child: _DetailPanel(
                    key: ValueKey('detail-${detail.id}'),
                    hackathon: widget.hackathon,
                    row: detail,
                    onReview: (status) => widget.onReview(detail.id, status),
                    onClose: () => setState(() => _detail = null),
                    onOpenDeepReview: () => widget.onOpenDeepReview(detail.id),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// One tab per review question, each with the rows it would show now.
  Widget _lensBar(List<TriageRow> all) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final lens in ReviewLens.values)
          _LensTab(
            key: ValueKey('lens-${lens.name}'),
            label: lens.label(_sponsor),
            count: all.where(_query.withLens(lens).matches).length,
            tooltip: lens.explanation(_sponsor),
            selected: _query.lens == lens,
            onTap: () => _setQuery(_query.withLens(lens)),
          ),
      ],
    ),
  );

  Widget _searchField() => TextField(
    key: const ValueKey('triage-search'),
    controller: _search,
    onChanged: (value) => _setQuery(_query.copyWith(search: value)),
    style: const TextStyle(fontSize: 12.5),
    decoration: InputDecoration(
      isDense: true,
      hintText: 'Search',
      hintStyle: const TextStyle(fontSize: 12.5, color: muted),
      prefixIcon: const Icon(Icons.search, size: 16, color: muted),
      prefixIconConstraints: const BoxConstraints(minWidth: 32),
      suffixIcon: _query.isSearching
          ? IconButton(
              key: const ValueKey('clear-search'),
              tooltip: 'Clear search',
              iconSize: 14,
              visualDensity: VisualDensity.compact,
              onPressed: _clearSearch,
              icon: const Icon(Icons.close, color: muted),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: rule),
      ),
    ),
  );

  /// What the chosen question means, in one sentence, and the hand-off to
  /// the Competition View once rows are selected.
  Widget _lensLine(int comparable) => Row(
    children: [
      Expanded(
        child: Text(
          _query.lens.explanation(_sponsor),
          key: const ValueKey('lens-explanation'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, color: muted),
        ),
      ),
      if (comparable > 0) ...[
        const SizedBox(width: 16),
        FilledButton.icon(
          key: const ValueKey('view-in-competition'),
          style: _compact,
          onPressed: widget.onViewCompetition,
          icon: const Icon(Icons.scatter_plot_outlined, size: 16),
          label: Text('View $comparable in Competition'),
        ),
      ],
    ],
  );

  static const _widths = {
    TriageColumn.project: 220.0,
    TriageColumn.why: 300.0,
    TriageColumn.evidence: 150.0,
    TriageColumn.build: 210.0,
    TriageColumn.substance: 210.0,
    TriageColumn.role: 210.0,
    TriageColumn.matters: 280.0,
    TriageColumn.distinctive: 300.0,
    TriageColumn.gap: 260.0,
    TriageColumn.claim: 240.0,
    TriageColumn.found: 240.0,
    TriageColumn.ask: 280.0,
  };

  /// Extra room goes to the text columns, by weight.
  static const _grow = {
    TriageColumn.project: 1.0,
    TriageColumn.why: 1.2,
    TriageColumn.evidence: .3,
    TriageColumn.build: .5,
    TriageColumn.substance: .5,
    TriageColumn.role: .5,
    TriageColumn.matters: 1.2,
    TriageColumn.distinctive: 1.5,
    TriageColumn.gap: 1.2,
    TriageColumn.claim: 1.2,
    TriageColumn.found: 1.0,
    TriageColumn.ask: 1.5,
  };
  static const _select = 38.0;
  static const _chevron = 28.0;
  static const _rowHeight = 46.0;

  Widget _table(List<TriageRow> rows) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: rule),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LayoutBuilder(
        builder: (context, box) {
          final columns = _query.columns;
          final base = columns.fold(
            _select + _chevron,
            (a, c) => a + _widths[c]!,
          );
          final extra = math.max(0.0, box.maxWidth - base);
          final weight = columns.fold(0.0, (a, c) => a + (_grow[c] ?? 0));
          final widths = {
            for (final c in columns)
              c:
                  _widths[c]! +
                  (weight == 0 ? 0 : extra * (_grow[c] ?? 0) / weight),
          };
          return Scrollbar(
            controller: _horizontal,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(base, box.maxWidth),
                height: box.maxHeight,
                child: Column(
                  children: [
                    _header(columns, widths),
                    const Divider(height: 1, color: rule),
                    Expanded(
                      child: rows.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _query.isSearching
                                        ? 'No submission here matches “${_query.search.trim()}”.'
                                        : 'No submission fits this question.',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (_query.isSearching)
                                    TextButton(
                                      onPressed: _clearSearch,
                                      child: const Text('Clear search'),
                                    ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _vertical,
                              itemExtent: _rowHeight,
                              itemCount: rows.length,
                              itemBuilder: (context, i) =>
                                  _row(rows[i], columns, widths),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _header(
    List<TriageColumn> columns,
    Map<TriageColumn, double> widths,
  ) => SizedBox(
    height: 36,
    child: Row(
      children: [
        const SizedBox(width: _select),
        for (final column in columns)
          SizedBox(
            width: widths[column],
            child: Tooltip(
              message: column.meaning,
              waitDuration: const Duration(milliseconds: 400),
              child: InkWell(
                key: ValueKey('sort-${column.name}'),
                onTap: () => _setQuery(_query.sortedBy(column)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          column.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: .9,
                            fontWeight: FontWeight.w600,
                            color: _sorted(column) ? ink : muted,
                          ),
                        ),
                      ),
                      if (_sorted(column))
                        Icon(
                          _query.ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 11,
                          color: ink,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  bool _sorted(TriageColumn column) =>
      sortKeyOf(_query.sort) == sortKeyOf(column);

  Widget _row(
    TriageRow row,
    List<TriageColumn> columns,
    Map<TriageColumn, double> widths,
  ) {
    final open = _detail == row.id;
    final chosen = widget.selected.contains(row.id);
    return Material(
      color: open
          ? const Color(0xFFEAF3EF)
          : chosen
          ? const Color(0xFFF3F7F4)
          : Colors.white,
      child: InkWell(
        key: ValueKey('row-${row.id}'),
        onTap: () => _open(row.id),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE8EDE7))),
          ),
          child: Row(
            children: [
              // Only rows with a deep review can join the Competition View.
              SizedBox(
                width: _select,
                child: row.hasRepresentation
                    ? Tooltip(
                        message:
                            'Has a deep review. Select to view in '
                            'Competition.',
                        child: Checkbox(
                          key: ValueKey('select-${row.id}'),
                          value: chosen,
                          visualDensity: VisualDensity.compact,
                          onChanged: (on) =>
                              widget.onSelect(row.id, on ?? false),
                        ),
                      )
                    : null,
              ),
              for (final column in columns)
                SizedBox(
                  width: widths[column],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _cell(column, row),
                    ),
                  ),
                ),
              SizedBox(
                width: _chevron,
                child: Icon(
                  open ? Icons.chevron_left : Icons.chevron_right,
                  size: 16,
                  color: open ? accent : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(TriageColumn column, TriageRow row) {
    final s = row.submission;
    final a = row.assessment;
    final repo = s.repo;
    final f = repo?.footprint;
    String uses(ServerpodFootprint f) =>
        f.capabilities.isEmpty ? 'Endpoints only' : f.capabilities.join(' · ');
    return switch (column) {
      TriageColumn.project => _ProjectCell(row),
      TriageColumn.why => _WhyCell(a),
      TriageColumn.evidence => Row(
        children: [
          _AccessMark(ok: repo != null, label: 'Code', tooltip: _codeLine(s)),
          const SizedBox(width: 12),
          _AccessMark(
            ok: s.demoAccess.playable,
            label: 'Demo',
            tooltip: _demoLine(s.demoAccess),
          ),
        ],
      ),
      TriageColumn.build || TriageColumn.substance =>
        repo == null
            ? const _Lines.faint('No code to inspect')
            : _Lines(
                '+${_k(repo.scaffold.lines)} repository lines beyond the template',
                '${_plural(f!.appCalls.length, 'endpoint method')} called · '
                    '${_plural(f.tables, 'table')}',
              ),
      TriageColumn.role => Tooltip(
        message: a.centrality.rule,
        child: _Lines(
          a.centrality.label,
          // Where another column already counts the calls, name what else
          // the server uses.
          f != null &&
                  (_query.columns.contains(TriageColumn.build) ||
                      _query.columns.contains(TriageColumn.substance))
              ? uses(f)
              : _roleLine(s, a),
          a.centrality == SponsorCentrality.unknown,
        ),
      ),
      TriageColumn.matters => _Lines(
        sponsorFinding(a) ??
            _roleInWriteup[s.jev.serverpodRole.value] ??
            s.jev.serverpodRole.value,
        f == null ? null : uses(f),
      ),
      TriageColumn.distinctive => _Lines(
        a.lane(Lane.distinctiveIdea)?.reason ??
            '${domainLabels[s.jev.domain.value]} · '
                '${modeLabels[s.jev.butlerMode.value]}',
      ),
      TriageColumn.gap => _Lines(a.lane(Lane.underTold)?.reason ?? '—'),
      TriageColumn.claim => Tooltip(
        message: 'Jev’s first major claim from the writeup',
        waitDuration: const Duration(milliseconds: 400),
        child: _Lines(s.jev.majorClaims.firstOrNull?.text ?? s.tagline),
      ),
      TriageColumn.found => _FoundCell(a),
      TriageColumn.ask => _AskCell(a),
    };
  }
}

/// A review question as an underlined tab, with how many rows it holds.
class _LensTab extends StatelessWidget {
  const _LensTab({
    super.key,
    required this.label,
    required this.count,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? accent : ink,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  color: selected ? accent : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A cell's main line, and an optional quieter second line. Never more than
/// two lines in all, so every row keeps one height.
class _Lines extends StatelessWidget {
  const _Lines(this.first, [this.second, this.faint = false]);
  const _Lines.faint(this.first) : second = null, faint = true;
  final String first;
  final String? second;
  final bool faint;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        first,
        maxLines: second == null || second!.isEmpty ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: faint ? _faint : _small,
      ),
      if (second != null && second!.isNotEmpty)
        Text(
          second!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _faint,
        ),
    ],
  );
}

class _ProjectCell extends StatelessWidget {
  const _ProjectCell(this.row);
  final TriageRow row;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(
            child: Text(
              row.submission.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          if (row.review != ReviewStatus.notStarted) ...[
            const SizedBox(width: 8),
            Text(
              row.review.label,
              key: ValueKey('status-${row.id}'),
              style: const TextStyle(fontSize: 10.5, color: accent),
            ),
          ],
        ],
      ),
      Text(
        row.submission.tagline,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _faint,
      ),
    ],
  );
}

/// The lanes a row sits in, and the fact behind the first, on one line.
class _WhyCell extends StatelessWidget {
  const _WhyCell(this.assessment);
  final TriageAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final lanes = assessment.lanes;
    if (lanes.isEmpty) return const Text('No lane rule matched', style: _faint);
    return Tooltip(
      message: [
        for (final l in lanes) '${l.lane.label}: ${l.reason}',
      ].join('\n'),
      waitDuration: const Duration(milliseconds: 500),
      child: Row(
        children: [
          for (final l in lanes)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: LanePill(l.lane),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              lanes.first.reason,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _small,
            ),
          ),
        ],
      ),
    );
  }
}

/// The gap that blocks checking, then claims the evidence does not show.
class _FoundCell extends StatelessWidget {
  const _FoundCell(this.assessment);
  final TriageAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final blocking = assessment.lane(Lane.unresolved);
    final described = [
      for (final gap in assessment.unsupportedClaims)
        if (gap != blocking?.gap) gap.claimed!,
    ].join(', ');
    if (blocking == null) {
      return described.isEmpty
          ? const _Lines.faint('Nothing blocking found')
          : _Lines('Described but not found: $described');
    }
    return _Lines(
      blocking.reason,
      described.isEmpty ? null : 'Also described but not found: $described',
    );
  }
}

/// The question to ask first. The rest open with the row.
class _AskCell extends StatelessWidget {
  const _AskCell(this.assessment);
  final TriageAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final lead = assessment.leadQuestion;
    if (lead == null) return const Text('No open questions', style: _faint);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(top: 1), child: _QuestionDot()),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            lead.question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _small.copyWith(color: questionColor),
          ),
        ),
      ],
    );
  }
}

class LanePill extends StatelessWidget {
  const LanePill(this.lane, {super.key});
  final Lane lane;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: lane.rule,
    waitDuration: const Duration(milliseconds: 400),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: lane.color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: lane.color.withValues(alpha: .45)),
      ),
      child: Text(
        lane.label,
        style: TextStyle(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: lane.color,
        ),
      ),
    ),
  );
}

class _AccessMark extends StatelessWidget {
  const _AccessMark({
    required this.ok,
    required this.label,
    required this.tooltip,
  });
  final bool ok;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.remove_circle_outline,
          size: 12,
          color: ok ? accent : muted,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: ok ? ink : muted),
          ),
        ),
      ],
    ),
  );
}

class _QuestionDot extends StatelessWidget {
  const _QuestionDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 13,
    height: 13,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: questionColor, width: 1.1),
    ),
    child: const Text(
      '?',
      style: TextStyle(
        fontSize: 8,
        height: 1,
        fontWeight: FontWeight.w700,
        color: questionColor,
      ),
    ),
  );
}

class _SourceTag extends StatelessWidget {
  const _SourceTag(this.sources);
  final Set<SignalSource> sources;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final source in sources)
        Tooltip(
          message: source.meaning,
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(source.icon, size: 10, color: muted),
                const SizedBox(width: 2),
                Text(
                  source.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8.5,
                    letterSpacing: .8,
                    color: muted,
                  ),
                ),
              ],
            ),
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
    padding: const EdgeInsets.only(top: 16),
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

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.faint = false});
  final String label;
  final String value;
  final bool faint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: faint ? muted : ink,
            ),
          ),
        ),
      ],
    ),
  );
}

/// One line of "what can be checked": a mark, a label and the fact.
class _Check extends StatelessWidget {
  const _Check(this.ok, this.label, this.value);
  final bool ok;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            ok ? Icons.check_circle_outline : Icons.remove_circle_outline,
            size: 13,
            color: ok ? accent : muted,
          ),
        ),
        const SizedBox(width: 7),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: ok ? ink : muted,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A collapsed section of the detail panel, opened only when asked for.
class _More extends StatelessWidget {
  const _More({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.note,
  });
  final String title;
  final IconData icon;
  final String? note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 26, bottom: 10),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, size: 16, color: accent),
      iconColor: muted,
      collapsedIconColor: muted,
      title: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              color: ink,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: muted),
              ),
            ),
          ],
        ],
      ),
      children: children,
    ),
  );
}

/// One submission, revealed in steps: why it is here, what was verified,
/// the question to ask first and the way into its deep review. Everything
/// else waits behind one quiet toggle.
class _DetailPanel extends StatefulWidget {
  const _DetailPanel({
    super.key,
    required this.hackathon,
    required this.row,
    required this.onReview,
    required this.onClose,
    required this.onOpenDeepReview,
  });
  final Hackathon hackathon;
  final TriageRow row;
  final ValueChanged<ReviewStatus> onReview;
  final VoidCallback onClose;
  final VoidCallback onOpenDeepReview;

  @override
  State<_DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<_DetailPanel> {
  /// Evidence and technical detail stay closed until the judge asks.
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final s = row.submission;
    final a = row.assessment;
    final triage = widget.hackathon.triage!;
    final lead = a.leadQuestion;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: rule),
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: .12),
            blurRadius: 28,
            offset: const Offset(-6, 8),
          ),
        ],
      ),
      // A Material under the decoration keeps list-tile ink visible.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 0),
              child: Row(
                children: [
                  const Expanded(child: Text('SUBMISSION', style: _eyebrow)),
                  _ReviewMenu(status: row.review, onSelected: widget.onReview),
                  IconButton(
                    key: const ValueKey('close-detail'),
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: muted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      s.tagline,
                      style: const TextStyle(
                        fontSize: 12,
                        color: muted,
                        height: 1.35,
                      ),
                    ),
                    _Section('WHY IT’S HERE', [
                      if (a.lanes.isEmpty)
                        const Text(
                          'No lane rule matched this submission.',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      for (final lane in a.lanes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LanePill(lane.lane),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lane.reason,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: ink,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ]),
                    _Section('WHAT FINALIST BRIEF VERIFIED', [
                      _Check(s.repo != null, 'Code', _codeLine(s)),
                      _Check(
                        s.demoAccess.playable,
                        'Demo',
                        _demoLine(s.demoAccess),
                      ),
                      _Check(
                        a.centrality == SponsorCentrality.central ||
                            a.centrality == SponsorCentrality.supporting,
                        triage.sponsorTech,
                        '${a.centrality.label}: ${_roleLine(s, a).toLowerCase()}',
                      ),
                    ]),
                    _Section('JUDGE QUESTION', [
                      if (lead == null)
                        const Text(
                          'No gap produced a question.',
                          style: TextStyle(fontSize: 12, color: muted),
                        )
                      else
                        _QuestionLine(lead, prominent: true),
                    ]),
                    if (row.hasRepresentation) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: const ValueKey('open-deep-review'),
                        style: _compact,
                        onPressed: widget.onOpenDeepReview,
                        icon: const Icon(Icons.account_tree_outlined, size: 16),
                        label: const Text('Open deep review'),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Divider(height: 1, color: rule),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      key: const ValueKey('more-details'),
                      style: TextButton.styleFrom(
                        foregroundColor: muted,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => setState(() => _more = !_more),
                      icon: Icon(
                        _more ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                      ),
                      label: const Text(
                        'More evidence and technical details',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    if (_more) ..._details(s, a, lead),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _details(
    TriageSubmission s,
    TriageAssessment a,
    OpenQuestion? lead,
  ) {
    final triage = widget.hackathon.triage!;
    final others = [
      for (final q in a.questions)
        if (q != lead) q,
    ];
    return [
      if (others.isNotEmpty)
        _Section('OTHER QUESTIONS', [for (final q in others) _QuestionLine(q)]),
      const SizedBox(height: 8),
      _More(
        key: const ValueKey('more-evidence'),
        title: 'Links and access',
        icon: Icons.link,
        note: 'checked ${s.checked ?? triage.checked}',
        children: _evidence(s),
      ),
      _More(
        key: const ValueKey('more-repository'),
        title: 'Repository details',
        icon: Icons.code,
        note: 'computed from code',
        children: _repository(s),
      ),
      _More(
        key: const ValueKey('more-jev'),
        title: 'Jev extraction',
        icon: Icons.notes,
        note: '${s.jev.model} · describes, never judges',
        children: _jev(s),
      ),
      _More(
        key: const ValueKey('more-claims'),
        title: 'All claims',
        icon: Icons.format_list_bulleted,
        note: _plural(s.jev.claims, 'claim'),
        children: _claims(s),
      ),
      _More(
        key: const ValueKey('more-technical'),
        title: 'Technical details',
        icon: Icons.tune,
        note: 'rules, snapshot, history',
        children: _technical(s, a),
      ),
    ];
  }

  List<Widget> _evidence(TriageSubmission s) => [
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _LinkChip('Devpost', s.devpostUrl, Icons.article_outlined),
        if (s.repoUrl != null) _LinkChip('Repository', s.repoUrl!, Icons.code),
        if (s.videoUrl != null)
          _LinkChip('Demo video', s.videoUrl!, Icons.play_circle_outline),
        for (final live in s.live)
          _LinkChip(Uri.parse(live.url).host, live.url, Icons.public),
      ],
    ),
    const SizedBox(height: 8),
    _Fact('Team', s.team.isEmpty ? 'In private mode' : s.team.join(', ')),
    _Fact('Repository', s.repoAccess.label),
    _Fact('Demo video', s.demoAccess.label),
    for (final live in s.live)
      _Fact(
        Uri.parse(live.url).host,
        live.reachable ? 'Responds' : 'No response (${live.http})',
      ),
  ];

  List<Widget> _repository(TriageSubmission s) {
    final repo = s.repo;
    if (repo == null) {
      return [
        Text(
          s.repoAccess == RepoAccess.public
              ? 'No Serverpod package was found before the deadline.'
              : 'Not inspected: ${s.repoAccess.label.toLowerCase()}.',
          style: const TextStyle(fontSize: 12, color: muted),
        ),
      ];
    }
    final f = repo.footprint;
    final sc = repo.scaffold;
    String area(String name, String label) =>
        sc.area(name) > 0 ? '$label ${_k(sc.area(name))}' : '';
    return [
      _Fact(
        'Scaffold delta',
        '+${_k(sc.lines)} repository lines beyond the ${sc.templateVersion} template  ·  '
            '${[area('server', 'server'), area('flutter', 'app'), area('other', 'other')].where((t) => t.isNotEmpty).join(' · ')}',
      ),
      _Fact(
        'Languages',
        sc.byLanguage.entries.map((e) => '${e.key} ${_k(e.value)}').join(', '),
      ),
      _Fact(
        'Endpoints',
        '${f.endpoints.length} classes, ${f.endpointMethods} methods; '
            'the app calls ${f.appCalls.length}',
      ),
      if (f.appCalls.isNotEmpty)
        _Fact(
          'Called from app',
          f.appCalls.take(8).join(', ') + (f.appCalls.length > 8 ? ', …' : ''),
          faint: true,
        ),
      _Fact(
        'Models',
        '${f.models} models, ${f.tables} tables, ${f.migrations} migrations',
      ),
      _Fact(
        'Capabilities',
        f.capabilities.isEmpty
            ? 'None beyond endpoints'
            : f.capabilities.join(', '),
      ),
      _Fact(
        'Tests',
        repo.testFiles == 0
            ? 'No test files'
            : '${repo.testFiles} files, ${repo.testCases} cases',
      ),
      _Fact(
        'AI in code',
        repo.aiInCode.isEmpty
            ? 'No model call found'
            : repo.aiInCode.join(', '),
      ),
      if (repo.otherBackends.isNotEmpty)
        _Fact('Other backends', repo.otherBackends.join(', ')),
    ];
  }

  List<Widget> _jev(TriageSubmission s) {
    final jev = s.jev;
    String pct(double p) => p.toStringAsFixed(2);
    final mentioned = jev.mentions.entries.where((e) => e.value >= .5).toList();
    return [
      _Fact(
        'Area',
        '${domainLabels[jev.domain.value]}  (confidence ${pct(jev.domain.confidence)})',
      ),
      _Fact(
        'The butler',
        '${modeLabels[jev.butlerMode.value]}  (${pct(jev.butlerMode.confidence)})',
      ),
      _Fact(
        'AI',
        '${jev.aiRole.value} · ${jev.aiProvider.value.replaceAll('_', ' ')}',
      ),
      _Fact('Serverpod', jev.serverpodRole.value.replaceAll('_', ' ')),
      _Fact(
        'Mentions',
        mentioned.isEmpty
            ? 'None of the tracked capabilities'
            : mentioned
                  .map((e) => '${_mentionNames[e.key]} ${pct(e.value)}')
                  .join(', '),
      ),
    ];
  }

  List<Widget> _claims(TriageSubmission s) {
    final jev = s.jev;
    return [
      if (jev.majorClaims.isNotEmpty) ...[
        const Text('MAJOR CLAIMS', style: _eyebrow),
        const SizedBox(height: 4),
        for (final claim in jev.majorClaims)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${claim.id}  ',
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: muted,
                      fontFamily: 'monospace',
                    ),
                  ),
                  TextSpan(
                    text: claim.text,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ink,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const ValueKey('writeup-lines'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            'All writeup lines, as Jev classified them  (${jev.claims} claims)',
            style: const TextStyle(fontSize: 11.5, color: accent),
          ),
          children: [
            FutureBuilder<List<WriteupLine>>(
              future: widget.hackathon.writeup(s.id),
              initialData: widget.hackathon.loadedWriteup(s.id),
              builder: (context, snapshot) {
                final lines = snapshot.data;
                if (lines == null) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final line in lines) _WriteupLineView(line)],
                );
              },
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _technical(TriageSubmission s, TriageAssessment a) {
    final repo = s.repo;
    final c = repo?.commits;
    final sc = repo?.scaffold;
    return [
      if (repo != null) ...[
        _Fact('Serverpod', repo.serverpodConstraint),
        _Fact(
          'Snapshot',
          '${repo.snapshotSha.substring(0, 7)}'
              '${repo.snapshotIsHead ? ', the latest commit' : ', before later commits'}',
        ),
        _Fact(
          'History',
          '${c!.inWindow} commits during the hackathon over ${c.activeDays} '
              'day${c.activeDays == 1 ? '' : 's'}'
              '${c.afterDeadline > 0 ? ' · ${c.afterDeadline} after the deadline' : ''}'
              '${c.beforeOpen > 0 ? ' · ${c.beforeOpen} before it opened' : ''}',
        ),
        if (sc!.untouchedTemplateFiles.isNotEmpty)
          Tooltip(
            message: sc.untouchedTemplateFiles.join('\n'),
            child: _Fact(
              'Untouched',
              '${sc.untouchedTemplateFiles.length} template files left as generated',
              faint: true,
            ),
          ),
      ],
      _Fact('Evidence', a.coverage.label),
      const SizedBox(height: 8),
      const Text('LANE RULES APPLIED', style: _eyebrow),
      const SizedBox(height: 4),
      if (a.lanes.isEmpty)
        const Text(
          'No lane rule matched.',
          style: TextStyle(fontSize: 11.5, color: muted),
        ),
      for (final lane in a.lanes)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LanePill(lane.lane),
                  const SizedBox(width: 8),
                  _SourceTag(lane.sources),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                lane.lane.rule,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

/// The judge's own progress on a submission, as a quiet menu.
class _ReviewMenu extends StatelessWidget {
  const _ReviewMenu({required this.status, required this.onSelected});
  final ReviewStatus status;
  final ValueChanged<ReviewStatus> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<ReviewStatus>(
    key: const ValueKey('review-status'),
    tooltip: 'Your review status',
    initialValue: status,
    onSelected: onSelected,
    itemBuilder: (_) => [
      for (final s in ReviewStatus.values)
        PopupMenuItem(
          value: s,
          child: Text(s.label, style: const TextStyle(fontSize: 12.5)),
        ),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11.5,
              color: status == ReviewStatus.notStarted ? muted : accent,
            ),
          ),
          const Icon(Icons.expand_more, size: 14, color: muted),
        ],
      ),
    ),
  );
}

class _QuestionLine extends StatelessWidget {
  const _QuestionLine(this.question, {this.prominent = false});
  final OpenQuestion question;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(top: 2), child: _QuestionDot()),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.question,
                style: TextStyle(
                  fontSize: prominent ? 12.5 : 12,
                  height: 1.35,
                  color: questionColor,
                ),
              ),
              const SizedBox(height: 2),
              _SourceTag(question.sources),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WriteupLineView extends StatelessWidget {
  const _WriteupLineView(this.line);
  final WriteupLine line;

  @override
  Widget build(BuildContext context) {
    if (line.heading) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Text(
          line.text.toUpperCase(),
          style: const TextStyle(
            fontSize: 9.5,
            letterSpacing: .9,
            color: muted,
          ),
        ),
      );
    }
    final claim = const {
      'capability',
      'implementation',
      'outcome',
    }.contains(line.kind);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              line.kind ?? '',
              style: TextStyle(
                fontSize: 9.5,
                color: claim ? accent : muted,
                fontWeight: claim ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              line.text,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: claim ? ink : muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip(this.label, this.url, this.icon);
  final String label;
  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ActionChip(
    visualDensity: VisualDensity.compact,
    avatar: Icon(icon, size: 14, color: accent),
    label: Text(label, style: const TextStyle(fontSize: 11.5)),
    onPressed: () => openUrl(url),
  );
}

/// The first and last day links were checked; rows added to the sample later
/// carry their own date.
String _checkedRange(TriageDataset triage) {
  final days = {
    triage.checked,
    for (final s in triage.submissions) ?s.checked,
  }.toList()..sort();
  return days.length == 1 ? days.first : '${days.first} to ${days.last}';
}

/// The rules, in one place, so every question, lane and column can be
/// checked.
class _RulesDialog extends StatelessWidget {
  const _RulesDialog(this.triage);
  final TriageDataset triage;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('How the triage table is derived'),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Fact('Sample', triage.sample),
            _Fact(
              'Checked',
              'Links and repositories, ${_checkedRange(triage)}',
            ),
            const SizedBox(height: 12),
            const Text(
              'Each question is a view over the lanes and open questions below. '
              'It chooses rows, columns and a stated order; it adds no signal '
              'and no score.',
              style: TextStyle(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 8),
            for (final lens in ReviewLens.values)
              _Fact(
                lens.label(triage.sponsorTech),
                '${lens.explanation(triage.sponsorTech)} Sorted ${lens.order}.',
              ),
            const SizedBox(height: 16),
            const Text('LANES', style: _eyebrow),
            const SizedBox(height: 4),
            const Text(
              'Lanes are named reasons to spend review time. They are not ranked, '
              'never combined into a score, and a submission can sit in several.',
              style: TextStyle(fontSize: 12.5, height: 1.4),
            ),
            for (final lane in Lane.values) ...[
              const SizedBox(height: 12),
              LanePill(lane),
              const SizedBox(height: 4),
              Text(
                lane.rule,
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
            const SizedBox(height: 16),
            const Text('SERVERPOD CENTRALITY', style: _eyebrow),
            for (final c in SponsorCentrality.values) _Fact(c.label, c.rule),
            const SizedBox(height: 16),
            const Text('SOURCES', style: _eyebrow),
            for (final source in SignalSource.values)
              _Fact(source.label, source.meaning),
            const SizedBox(height: 8),
            _Fact('Repository', triage.deterministicMethod),
            _Fact('Jev', '${triage.jevModel}. ${triage.jevScope}'),
            const _Fact(
              'Never used',
              'README length, writing quality, stars, forks, likes, prizes or gallery order.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  );
}
