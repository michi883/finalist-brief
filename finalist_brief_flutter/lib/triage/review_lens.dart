import 'lanes.dart';
import 'triage_query.dart';

/// A question a judge brings to the field. Each lens chooses the rows that
/// answer it, the few columns worth reading, and an order. Lenses are views
/// over the lane rules and open questions: they add no signal and no score,
/// and their order is a stated sort, never a rank.
enum ReviewLens {
  all(
    'All',
    'Every submission, and the reason it may deserve a look.',
    'A–Z',
    [TriageColumn.project, TriageColumn.why, TriageColumn.evidence],
    sort: TriageColumn.project,
  ),
  substantial(
    'Substantial builds',
    'Code, app usage and stored data all go well beyond the {sponsor} template.',
    'most code beyond the template first',
    [
      TriageColumn.project,
      TriageColumn.build,
      TriageColumn.role,
      TriageColumn.evidence,
    ],
    sort: TriageColumn.build,
    ascending: false,
  ),
  distinctive(
    'Distinctive ideas',
    'An area few other submissions share, and a less common way of helping.',
    'most inspectable first',
    [TriageColumn.project, TriageColumn.distinctive, TriageColumn.evidence],
    sort: TriageColumn.evidence,
  ),
  underTold(
    'Under-told',
    'The code shows more than the writeup says.',
    'most code first',
    [
      TriageColumn.project,
      TriageColumn.substance,
      TriageColumn.gap,
      TriageColumn.evidence,
    ],
    sort: TriageColumn.substance,
    ascending: false,
  ),
  verify(
    'Needs verification',
    'Something central can’t be checked, or the writeup describes what the code doesn’t show.',
    'most fundamental gap first',
    [
      TriageColumn.project,
      TriageColumn.claim,
      TriageColumn.found,
      TriageColumn.ask,
    ],
    sort: TriageColumn.found,
  ),
  sponsor(
    'Sponsor tech',
    'How much of each app runs through {sponsor}, and whether the code shows it.',
    'central use first',
    [
      TriageColumn.project,
      TriageColumn.role,
      TriageColumn.matters,
      TriageColumn.evidence,
    ],
    sort: TriageColumn.role,
  );

  const ReviewLens(
    this._label,
    this._explanation,
    this.order,
    this.columns, {
    required this.sort,
    this.ascending = true,
  });
  final String _label;
  final String _explanation;

  /// The default order, in words, e.g. "most code first".
  final String order;
  final List<TriageColumn> columns;
  final TriageColumn sort;
  final bool ascending;

  String label(String sponsor) => _label.replaceAll('{sponsor}', sponsor);
  String explanation(String sponsor) =>
      _explanation.replaceAll('{sponsor}', sponsor);

  bool includes(TriageRow row) {
    final a = row.assessment;
    return switch (this) {
      all || sponsor => true,
      substantial => a.inLane(Lane.substantialBuild),
      distinctive => a.inLane(Lane.distinctiveIdea),
      underTold => a.inLane(Lane.underTold),
      verify => a.inLane(Lane.unresolved) || a.hasGap(GapKind.claim),
    };
  }
}
