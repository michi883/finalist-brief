import 'triage.dart';

/// Explainable reasons to spend review time on a submission. Lanes are not
/// ordered by merit and are never combined into a score; a submission can sit
/// in several lanes, or in none.
enum Lane {
  substantialBuild(
    'Substantial build',
    'At least 5,000 repository lines beyond the Serverpod template, at least '
        '10 endpoint methods called from the Flutter app, and at least 4 '
        'database tables.',
  ),
  distinctiveIdea(
    'Distinctive idea',
    'Jev places the project in an area served by at most 5% of the sample '
        '(at least one submission), and its way of helping is not the most '
        'common one. Both answers need Jev confidence of 0.5 or more, and the '
        'writeup must state at least one capability, implementation or outcome; '
        'writeups that state none are left out of the area counts.',
  ),
  underTold(
    'Under-told',
    'At least two things the code shows that the writeup leaves out: a '
        'Serverpod capability in use that Jev finds unmentioned (below 0.3), '
        'or Serverpod’s role left undescribed while the app calls 5 or more '
        'endpoint methods.',
  ),
  unresolved(
    'Unresolved',
    'Something central cannot be checked: no accessible repository (or no '
        'repository, demo or described writeup at all), a '
        'Serverpod setup that cannot be built as submitted, an app that never '
        'calls its server, or a central AI claim with no model call in code.',
  );

  const Lane(this.label, this.rule);
  final String label;
  final String rule;
}

/// What a gap stops a judge from checking.
enum GapKind {
  /// The code, demo or deployment cannot be reached.
  access,

  /// The server cannot be built or used as submitted.
  setup,

  /// The commit history does not show how or when the build happened.
  history,

  /// The writeup describes something the evidence does not show.
  claim,

  /// The writeup itself says the work is unfinished.
  unfinished,
}

/// The specific gap behind an open question or an Unresolved lane, so the
/// table can show a finding next to the question it raises.
enum Gap {
  noRepository(GapKind.access),
  repositoryNotFound(GapKind.access),
  emptyWriteup(GapKind.access),
  noServerpodPackage(GapKind.access),
  demoPrivate(GapKind.access),
  demoUnavailable(GapKind.access),
  appOffline(GapKind.access),
  unpublishedDependency(GapKind.setup),
  oldServerpod(GapKind.setup),
  noGeneratedProtocol(GapKind.setup),
  appNeverCallsServer(GapKind.setup),
  commitsAfterDeadline(GapKind.history),
  commitsBeforeOpen(GapKind.history),
  compressedHistory(GapKind.history),
  realtime(GapKind.claim, 'real-time updates'),
  scheduling(GapKind.claim, 'scheduled work'),
  storage(GapKind.claim, 'stored data'),
  signIn(GapKind.claim, 'sign-in'),
  uploads(GapKind.claim, 'file uploads'),
  tests(GapKind.claim, 'tests'),
  ai(GapKind.claim, 'AI behavior'),
  cloudDeployment(GapKind.claim, 'a Serverpod Cloud deployment'),
  unfinished(GapKind.unfinished);

  const Gap(this.kind, [this.claimed]);
  final GapKind kind;

  /// For claim gaps: what the writeup describes that was not found.
  final String? claimed;
}

/// One lane and the concise, named fact that put the submission there.
class LaneAssignment {
  const LaneAssignment(this.lane, this.reason, this.sources, {this.gap});
  final Lane lane;
  final String reason;
  final Set<SignalSource> sources;

  /// The blocking gap, for the Unresolved lane.
  final Gap? gap;
}

/// A question for the team that follows from one specific gap.
class OpenQuestion {
  const OpenQuestion(this.gap, this.question, this.sources);
  final Gap gap;
  final String question;
  final Set<SignalSource> sources;
}

enum SponsorCentrality {
  central('Central', '5 or more endpoint methods called from the Flutter app.'),
  supporting('Supporting', '1–4 endpoint methods called from the Flutter app.'),
  peripheral(
    'Peripheral',
    'The Flutter app calls none of the server’s endpoint methods.',
  ),
  unknown('Unknown', 'No repository could be inspected.');

  const SponsorCentrality(this.label, this.rule);
  final String label;
  final String rule;
}

enum EvidenceCoverage {
  codeAndDemo('Code + demo'),
  codeOnly('Code only'),
  demoOnly('Demo only'),
  writeupOnly('Writeup only'),
  none('Nothing to inspect');

  const EvidenceCoverage(this.label);
  final String label;
}

class TriageAssessment {
  const TriageAssessment({
    required this.lanes,
    required this.questions,
    required this.centrality,
    required this.coverage,
  });
  final List<LaneAssignment> lanes;
  final List<OpenQuestion> questions;
  final SponsorCentrality centrality;
  final EvidenceCoverage coverage;

  bool inLane(Lane lane) => lanes.any((a) => a.lane == lane);

  LaneAssignment? lane(Lane lane) =>
      lanes.where((a) => a.lane == lane).firstOrNull;

  /// The first lane's reason; lanes are listed in [Lane] order.
  String get surfacingReason =>
      lanes.isEmpty ? 'No lane rule matched' : lanes.first.reason;

  bool hasGap(GapKind kind) => questions.any((q) => q.gap.kind == kind);

  /// Claims in the writeup that the code or links do not show.
  List<Gap> get unsupportedClaims => [
    for (final q in questions)
      if (q.gap.kind == GapKind.claim) q.gap,
  ];

  /// The one question to ask first: the one behind the Unresolved lane,
  /// then an unsupported claim, then whatever comes first.
  OpenQuestion? get leadQuestion {
    final blocking = lane(Lane.unresolved)?.gap;
    return questions.where((q) => q.gap == blocking).firstOrNull ??
        questions.where((q) => q.gap.kind == GapKind.claim).firstOrNull ??
        questions.firstOrNull;
  }
}

const _substantialLines = 5000;
const _substantialCalls = 10;
const _substantialTables = 4;
const _distinctiveShare = .05;
const _jevConfident = .5;
const _untold = .3;
const _claimed = .7;
const _undescribedRoleCalls = 5;

const domainLabels = {
  'productivity': 'productivity',
  'health': 'health',
  'finance': 'finance',
  'learning': 'learning',
  'knowledge': 'knowledge-management',
  'community': 'community',
  'developer': 'developer-tools',
  'privacy': 'privacy',
  'automation': 'automation',
  'other': 'uncategorized',
};

const modeLabels = {
  'conversational': 'answers in chat',
  'proactive': 'acts proactively',
  'analysis': 'analyzes what the user provides',
  'organizer': 'organizes records',
  'platform': 'builds other agents or apps',
};

String _thousands(int n) =>
    n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

/// Applies every rule to every submission. Distinctiveness is relative to the
/// field, so the whole dataset is assessed at once.
Map<String, TriageAssessment> assessField(TriageDataset dataset) {
  final all = dataset.submissions;
  final domains = <String, int>{};
  final modes = <String, int>{};
  // A writeup that states nothing gives Jev no idea to place; its profile
  // answers come from the title and built-with tags alone.
  for (final s in all.where((s) => s.jev.describesWork)) {
    domains.update(s.jev.domain.value, (n) => n + 1, ifAbsent: () => 1);
    modes.update(s.jev.butlerMode.value, (n) => n + 1, ifAbsent: () => 1);
  }
  final commonest = modes.entries.reduce((a, b) => b.value > a.value ? b : a);
  final rareLimit = (all.length * _distinctiveShare).floor().clamp(
    1,
    all.length,
  );
  return {
    for (final s in all)
      s.id: _assess(s, dataset, domains, commonest.key, rareLimit),
  };
}

TriageAssessment _assess(
  TriageSubmission s,
  TriageDataset dataset,
  Map<String, int> domains,
  String commonestMode,
  int rareLimit,
) {
  final repo = s.repo;
  final footprint = repo?.footprint;
  final jev = s.jev;
  final lanes = <LaneAssignment>[];
  const repoSource = {SignalSource.repo};

  // Substantial build: code volume, app usage and persistence together.
  if (repo != null &&
      repo.scaffold.lines >= _substantialLines &&
      footprint!.appCalls.length >= _substantialCalls &&
      footprint.tables >= _substantialTables) {
    lanes.add(
      LaneAssignment(
        Lane.substantialBuild,
        '${footprint.appCalls.length} endpoint methods used by the app · '
        '${footprint.tables} tables · +${_thousands(repo.scaffold.lines)} lines',
        repoSource,
      ),
    );
  }

  // Distinctive idea: rare area within this field, less common mode.
  final domainCount = domains[jev.domain.value] ?? 0;
  if (jev.describesWork &&
      jev.domain.value != 'other' &&
      jev.domain.confidence >= _jevConfident &&
      jev.butlerMode.confidence >= _jevConfident &&
      domainCount <= rareLimit &&
      jev.butlerMode.value != commonestMode) {
    final area = domainLabels[jev.domain.value]!;
    lanes.add(
      LaneAssignment(
        Lane.distinctiveIdea,
        '${domainCount == 1 ? 'Only $area project' : '$domainCount $area projects'} '
        'in the sample · ${modeLabels[jev.butlerMode.value]}',
        const {SignalSource.jev},
      ),
    );
  }

  // Under-told: what the code shows and the writeup leaves out.
  if (repo != null) {
    final f = footprint!;
    final omitted = [
      if (f.tables >= 3 && jev.mention('database') < _untold)
        _plural(f.tables, 'table'),
      if (f.streamMethods > 0 && jev.mention('realtime') < _untold) 'streaming',
      if (f.futureCalls && jev.mention('scheduling') < _untold) 'future calls',
      if (f.authInCustomCode && jev.mention('auth') < _untold) 'Serverpod auth',
      if (f.fileUploads && jev.mention('uploads') < _untold) 'file uploads',
      if (repo.testFiles > 0 && jev.mention('tests') < _untold)
        _plural(repo.testFiles, 'test file'),
      if (f.appCalls.length >= _undescribedRoleCalls &&
          const {
            'not_mentioned',
            'named_only',
          }.contains(jev.serverpodRole.value))
        'Serverpod’s role',
    ];
    if (omitted.length >= 2) {
      lanes.add(
        LaneAssignment(
          Lane.underTold,
          'Writeup omits: ${omitted.join(', ')}',
          const {SignalSource.repo, SignalSource.jev},
        ),
      );
    }
  }

  // Unresolved: the most fundamental blocking gap names the lane.
  final blocking = <(String, Set<SignalSource>, Gap)>[
    if (s.repoAccess == RepoAccess.notLinked &&
        !s.demoAccess.playable &&
        !jev.describesWork)
      (
        'No repository, demo or described writeup',
        {SignalSource.links, SignalSource.jev},
        Gap.noRepository,
      )
    else if (s.repoAccess == RepoAccess.notLinked && !s.demoAccess.playable)
      (
        'Only the writeup can be inspected',
        {SignalSource.links},
        Gap.noRepository,
      )
    else if (s.repoAccess == RepoAccess.notLinked)
      ('No repository linked', {SignalSource.links}, Gap.noRepository),
    if (s.repoAccess == RepoAccess.notFound)
      (
        'Repository link returns 404',
        {SignalSource.links},
        Gap.repositoryNotFound,
      ),
    if (s.repoAccess == RepoAccess.public && repo == null)
      (
        'No Serverpod package before the deadline',
        repoSource,
        Gap.noServerpodPackage,
      ),
    if (repo != null && repo.unresolvedDeps.isNotEmpty)
      (
        'Depends on ${repo.unresolvedDeps.first}, not on pub.dev',
        repoSource,
        Gap.unpublishedDependency,
      ),
    if (repo != null && (repo.serverpodMajor ?? 3) < 3)
      (
        'Pins Serverpod ${repo.serverpodConstraint}',
        repoSource,
        Gap.oldServerpod,
      ),
    if (repo != null && !footprint!.generatedProtocol)
      (
        'No generated Serverpod protocol',
        repoSource,
        Gap.noGeneratedProtocol,
      ),
    if (repo != null &&
        footprint!.endpoints.isNotEmpty &&
        footprint.appCalls.isEmpty)
      (
        'App never calls its ${footprint.endpointMethods} endpoint methods',
        repoSource,
        Gap.appNeverCallsServer,
      ),
    if (repo != null &&
        jev.aiRole.value == 'core' &&
        jev.aiRole.confidence >= _jevConfident &&
        repo.aiInCode.isEmpty)
      (
        'Central AI claim; no model call in code',
        {SignalSource.jev, SignalSource.repo},
        Gap.ai,
      ),
  ];
  if (blocking.isNotEmpty) {
    final (reason, sources, gap) = blocking.first;
    lanes.add(LaneAssignment(Lane.unresolved, reason, sources, gap: gap));
  }

  return TriageAssessment(
    lanes: lanes,
    questions: _questions(s, dataset),
    centrality: repo == null
        ? SponsorCentrality.unknown
        : footprint!.appCalls.length >= 5
        ? SponsorCentrality.central
        : footprint.appCalls.isNotEmpty
        ? SponsorCentrality.supporting
        : SponsorCentrality.peripheral,
    coverage: repo != null
        ? (s.demoAccess.playable
              ? EvidenceCoverage.codeAndDemo
              : EvidenceCoverage.codeOnly)
        : (s.demoAccess.playable
              ? EvidenceCoverage.demoOnly
              : jev.describesWork
              ? EvidenceCoverage.writeupOnly
              : EvidenceCoverage.none),
  );
}

/// Questions for the team, each tied to one named gap. Cross-checks compare
/// what Jev found in the writeup with what code found in the repository.
List<OpenQuestion> _questions(TriageSubmission s, TriageDataset dataset) {
  const links = {SignalSource.links};
  const repoOnly = {SignalSource.repo};
  const both = {SignalSource.jev, SignalSource.repo};
  final repo = s.repo;
  final f = repo?.footprint;
  final jev = s.jev;
  bool claims(String capability) => jev.mention(capability) >= _claimed;
  final reachable = s.live.where((l) => l.reachable);
  return [
    if (s.repoAccess == RepoAccess.notLinked)
      const OpenQuestion(
        Gap.noRepository,
        'No repository is linked. Can the team share the code, as the rules require?',
        links,
      ),
    if (s.repoAccess == RepoAccess.notFound)
      const OpenQuestion(
        Gap.repositoryNotFound,
        'The repository link returns 404. Was read access granted to the Serverpod judges?',
        links,
      ),
    if (!jev.describesWork)
      const OpenQuestion(
        Gap.emptyWriteup,
        'The writeup states no feature, build step or result. What does the project do?',
        {SignalSource.jev},
      ),
    if (s.demoAccess == DemoAccess.private)
      const OpenQuestion(
        Gap.demoPrivate,
        'The demo video is private. Can the team share a viewable recording?',
        links,
      ),
    if (s.demoAccess == DemoAccess.unavailable)
      const OpenQuestion(
        Gap.demoUnavailable,
        'The demo video is unavailable. Is there another recording of the app working?',
        links,
      ),
    if (s.live.isNotEmpty && reachable.isEmpty)
      OpenQuestion(
        Gap.appOffline,
        'The linked app at ${Uri.parse(s.live.first.url).host} does not respond '
        '(checked ${s.checked ?? dataset.checked}). Is it still deployed?',
        links,
      ),
    if (repo != null && f != null) ...[
      for (final dep in repo.unresolvedDeps)
        OpenQuestion(
          Gap.unpublishedDependency,
          'The server depends on $dep, which is not on pub.dev. How was the submitted server built?',
          repoOnly,
        ),
      if ((repo.serverpodMajor ?? 3) < 3)
        OpenQuestion(
          Gap.oldServerpod,
          'The server pins Serverpod ${repo.serverpodConstraint}, while the hackathon targets Serverpod 3. Which version does the demo run?',
          repoOnly,
        ),
      if (!f.generatedProtocol)
        const OpenQuestion(
          Gap.noGeneratedProtocol,
          'No generated Serverpod protocol is committed. Has `serverpod generate` been run on this code?',
          repoOnly,
        ),
      if (f.endpoints.isNotEmpty && f.appCalls.isEmpty)
        OpenQuestion(
          Gap.appNeverCallsServer,
          'The Flutter app in the repository never calls the server’s '
          // Method signatures can be unreadable (e.g. HTML-escaped source);
          // the endpoint classes are still counted.
          '${f.endpointMethods > 0 ? '${f.endpointMethods} endpoint methods' : '${f.endpoints.length} endpoint classes'}. '
          'Where is the client that does?',
          repoOnly,
        ),
      if (repo.commits.afterDeadline > 0)
        OpenQuestion(
          Gap.commitsAfterDeadline,
          '${_plural(repo.commits.afterDeadline, 'commit')} came after the deadline. '
          'Signals use snapshot ${repo.snapshotSha.substring(0, 7)}; is that the build the demo shows?',
          repoOnly,
        ),
      if (repo.commits.beforeOpen > 0)
        OpenQuestion(
          Gap.commitsBeforeOpen,
          '${_plural(repo.commits.beforeOpen, 'commit')} predate the hackathon. Which parts were built during it?',
          repoOnly,
        ),
      if (repo.commits.inWindow <= 5 && repo.commits.windowSpanMinutes <= 60)
        OpenQuestion(
          Gap.compressedHistory,
          'The history is ${_plural(repo.commits.inWindow, 'commit')} within '
          '${_plural(repo.commits.windowSpanMinutes, 'minute')}, so it does not '
          'show how the build evolved. Is there an earlier history?',
          repoOnly,
        ),
      if (claims('realtime') && f.streamMethods == 0)
        const OpenQuestion(
          Gap.realtime,
          'The writeup describes real-time updates, but no streaming endpoint was found. How do updates reach the app?',
          both,
        ),
      if (claims('scheduling') && !f.futureCalls)
        const OpenQuestion(
          Gap.scheduling,
          'The writeup describes scheduled work, but no Serverpod future calls were found. What runs the schedule?',
          both,
        ),
      if (claims('database') && f.tables == 0)
        const OpenQuestion(
          Gap.storage,
          'The writeup describes stored data, but no Serverpod table is defined. Where is data persisted?',
          both,
        ),
      if (claims('auth') && !f.authInCustomCode)
        const OpenQuestion(
          Gap.signIn,
          'The writeup describes sign-in, but no endpoint uses Serverpod authentication. How are requests tied to a signed-in user?',
          both,
        ),
      if (claims('uploads') && !f.fileUploads)
        const OpenQuestion(
          Gap.uploads,
          'The writeup describes uploading files or photos, but the server has no Serverpod file-upload handling. Are uploads stored, and where?',
          both,
        ),
      if (claims('tests') && repo.testFiles == 0)
        const OpenQuestion(
          Gap.tests,
          'The writeup mentions automated tests, but no test files were found. Where are they?',
          both,
        ),
      if (jev.aiRole.value == 'core' &&
          jev.aiRole.confidence >= _jevConfident &&
          repo.aiInCode.isEmpty)
        const OpenQuestion(
          Gap.ai,
          'AI is central in the writeup, but no model call was found in the code. Which component produces the AI behavior?',
          both,
        ),
    ],
    if (claims('cloudDeploy') &&
        !reachable.any((l) => l.url.contains('serverpod.space')))
      const OpenQuestion(
        Gap.cloudDeployment,
        'The writeup says the backend runs on Serverpod Cloud, but no reachable deployment is linked. Is it still live?',
        {SignalSource.jev, SignalSource.links},
      ),
    if (jev.admitsUnfinished >= .4 &&
        jev.unfinishedLineProbability >= .5 &&
        jev.unfinishedLine != null)
      OpenQuestion(
        Gap.unfinished,
        'The writeup notes unfinished work: “${_clip(jev.unfinishedLine!.text)}”. '
        'Which described features work today?',
        const {SignalSource.jev},
      ),
  ];
}

String _clip(String text) {
  final clean = text.replaceFirst(RegExp(r'^[-•*\s]+'), '');
  return clean.length <= 90 ? clean : '${clean.substring(0, 88).trimRight()}…';
}
