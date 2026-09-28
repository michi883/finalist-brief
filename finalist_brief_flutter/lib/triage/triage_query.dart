import 'lanes.dart';
import 'review_lens.dart';
import 'triage.dart';

/// A judge's own progress on a submission. Set by hand, never inferred.
enum ReviewStatus {
  notStarted('Not started'),
  inReview('In review'),
  askTeam('Ask the team'),
  reviewed('Reviewed');

  const ReviewStatus(this.label);
  final String label;
}

/// One table row: the submission, what the rules derived, and judge state.
class TriageRow {
  const TriageRow({
    required this.submission,
    required this.assessment,
    required this.hasRepresentation,
    this.review = ReviewStatus.notStarted,
  });
  final TriageSubmission submission;
  final TriageAssessment assessment;
  final bool hasRepresentation;
  final ReviewStatus review;

  String get id => submission.id;
}

enum TriageColumn {
  project('Project', 'Title and tagline from Devpost.'),
  why(
    'Why look',
    'The named reason this project surfaced. Several can apply; none is a rank.',
  ),
  evidence(
    'Evidence',
    'What could be inspected: the code, the demo video, or only the writeup.',
  ),
  build(
    'Build evidence',
    'Code beyond the Serverpod template, endpoint methods the app calls, and database tables.',
  ),
  substance(
    'Code substance',
    'Code beyond the Serverpod template, endpoint methods the app calls, and database tables.',
  ),
  role(
    'Serverpod role',
    'How much of the app runs through its Serverpod endpoints (repository).',
  ),
  matters(
    'Why it matters',
    'What stops the server being checked, Serverpod features described but '
        'not found in code, or what the code shows that the writeup leaves '
        'out. Below it, the Serverpod capabilities in use.',
  ),
  distinctive(
    'What’s distinctive',
    'The project’s area and way of helping, and how rare the area is in the sample (Jev).',
  ),
  gap('Submission gap', 'What the code shows that the writeup leaves out.'),
  claim('Claim', 'The writeup’s first major claim, as Jev extracted it.'),
  found(
    'What we found',
    'The gap that blocks checking, and what the writeup describes that was not found.',
  ),
  ask(
    'Judge question',
    'The question to ask the team first; open the row for the rest.',
  );

  const TriageColumn(this.label, this.meaning);
  final String label;
  final String meaning;
}

/// The chosen lens, search and sort. Immutable, so each hackathon workspace
/// can keep its own and restore it exactly.
class TriageQuery {
  const TriageQuery({
    this.lens = ReviewLens.all,
    this.search = '',
    this.sort = TriageColumn.project,
    this.ascending = true,
  });

  /// The query a lens starts from: its rows, columns and order.
  factory TriageQuery.forLens(ReviewLens lens) =>
      TriageQuery(lens: lens, sort: lens.sort, ascending: lens.ascending);

  final ReviewLens lens;
  final String search;
  final TriageColumn sort;
  final bool ascending;

  List<TriageColumn> get columns => lens.columns;

  bool get isSearching => search.trim().isNotEmpty;

  /// Switches lens: its order replaces the old one, while search carries
  /// over.
  TriageQuery withLens(ReviewLens lens) =>
      copyWith(lens: lens, sort: lens.sort, ascending: lens.ascending);

  TriageQuery copyWith({
    ReviewLens? lens,
    String? search,
    TriageColumn? sort,
    bool? ascending,
  }) => TriageQuery(
    lens: lens ?? this.lens,
    search: search ?? this.search,
    sort: sort ?? this.sort,
    ascending: ascending ?? this.ascending,
  );

  /// Sorting by a column again reverses it; a new column starts ascending,
  /// except counts, which start with the largest.
  TriageQuery sortedBy(TriageColumn column) =>
      sortKeyOf(column) == sortKeyOf(sort)
      ? copyWith(ascending: !ascending)
      : copyWith(sort: column, ascending: !_countColumns.contains(column));

  static const _countColumns = {
    TriageColumn.build,
    TriageColumn.substance,
    TriageColumn.ask,
  };

  bool _searched(TriageRow row) {
    final needle = search.trim().toLowerCase();
    if (needle.isEmpty) return true;
    final s = row.submission;
    return [
      s.title,
      s.tagline,
      ...s.team,
      ...s.builtWith,
      domainLabels[s.jev.domain.value] ?? '',
      for (final l in row.assessment.lanes) ...[l.lane.label, l.reason],
    ].any((field) => field.toLowerCase().contains(needle));
  }

  bool matches(TriageRow row) => lens.includes(row) && _searched(row);

  /// Filters then sorts. Ties fall back to title so order is deterministic.
  List<TriageRow> apply(Iterable<TriageRow> rows) {
    final kept = rows.where(matches).toList();
    int byTitle(TriageRow a, TriageRow b) => a.submission.title
        .toLowerCase()
        .compareTo(b.submission.title.toLowerCase());
    kept.sort((a, b) {
      final order = _compare(sort, a, b);
      final directed = ascending ? order : -order;
      return directed != 0 ? directed : byTitle(a, b);
    });
    return kept;
  }
}

/// Columns that sort by the same key share one canonical column, so both
/// headers show the order.
TriageColumn sortKeyOf(TriageColumn column) => switch (column) {
  TriageColumn.substance => TriageColumn.build,
  _ => column,
};

/// The gap that most limits checking a row: the Unresolved lane's, then the
/// first claim the evidence does not show. Gaps sort most fundamental first.
Gap? primaryGap(TriageAssessment a) =>
    a.lane(Lane.unresolved)?.gap ?? a.unsupportedClaims.firstOrNull;

/// Writeup claims about Serverpod itself, as opposed to AI or tests.
const _serverpodClaims = {
  Gap.realtime,
  Gap.scheduling,
  Gap.storage,
  Gap.signIn,
  Gap.uploads,
  Gap.cloudDeployment,
};

/// The Serverpod fact to know first, picked from what the lanes and
/// questions already say: what blocks checking the server, then Serverpod
/// features the writeup describes but the code lacks, then what the code
/// shows that the writeup leaves out. Null when none applies.
String? sponsorFinding(TriageAssessment a) {
  final blocking = a.lane(Lane.unresolved);
  if (blocking != null && blocking.gap != Gap.ai) return blocking.reason;
  final missing = [
    for (final gap in a.unsupportedClaims)
      if (_serverpodClaims.contains(gap)) gap.claimed!,
  ];
  if (missing.isNotEmpty) {
    return 'Described but not found: ${missing.join(', ')}';
  }
  return a.lane(Lane.underTold)?.reason;
}

int _compare(TriageColumn column, TriageRow a, TriageRow b) {
  Comparable key(TriageRow r) {
    final s = r.submission;
    final x = r.assessment;
    return switch (column) {
      TriageColumn.project => s.title.toLowerCase(),
      // Rows without a lane sort after every lane.
      TriageColumn.why =>
        x.lanes.isEmpty ? Lane.values.length : x.lanes.first.lane.index,
      TriageColumn.evidence => x.coverage.index,
      TriageColumn.build ||
      TriageColumn.substance => s.repo?.scaffold.lines ?? -1,
      TriageColumn.role => x.centrality.index,
      TriageColumn.matters => (sponsorFinding(x) ?? '~').toLowerCase(),
      TriageColumn.distinctive =>
        domainLabels[s.jev.domain.value] ?? s.jev.domain.value,
      TriageColumn.gap => (x.lane(Lane.underTold)?.reason ?? '').toLowerCase(),
      TriageColumn.claim =>
        (s.jev.majorClaims.firstOrNull?.text ?? s.tagline).toLowerCase(),
      TriageColumn.found => primaryGap(x)?.index ?? Gap.values.length,
      TriageColumn.ask => x.questions.length,
    };
  }

  return key(a).compareTo(key(b));
}
