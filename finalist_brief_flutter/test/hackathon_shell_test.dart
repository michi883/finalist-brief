import 'dart:io';

import 'package:finalist_brief_flutter/hackathon/hackathon.dart';
import 'package:finalist_brief_flutter/representation/project.dart';
import 'package:finalist_brief_flutter/triage/review_lens.dart';
import 'package:finalist_brief_flutter/triage/triage.dart';
import 'package:finalist_brief_flutter/views/exploration_screen.dart';
import 'package:finalist_brief_flutter/views/hackathon_shell.dart';
import 'package:finalist_brief_flutter/views/hackathon_workspace.dart';
import 'package:finalist_brief_flutter/views/workspace_frame.dart';
import 'package:finalist_brief_flutter/visualization/graph_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads assets straight from disk, so lazily loaded files resolve inside
/// the test's own zone instead of a decoding isolate.
class _FileBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async => parser(await loadString(key));
}

void main() {
  Hackathon load(HackathonSource source) => Hackathon(
    source: source,
    bundle: _FileBundle(),
    competition: parseCompetition(
      File(source.representations).readAsStringSync(),
    ),
    triage: source.triage == null
        ? null
        : parseTriage(File(source.triage!).readAsStringSync()),
  );
  // Fresh per test: lazily loaded assets must not outlive a test's zone.
  late Hackathon humor;
  late Hackathon serverpod;
  setUp(() {
    humor = load(hackathonSources.singleWhere((s) => s.id == 'humor-genome'));
    serverpod = load(hackathonSources.singleWhere((s) => s.id == 'serverpod'));
  });

  Future<void> mount(
    WidgetTester tester, {
    String? initial,
    WorkspaceTab tab = WorkspaceTab.submissions,
    String? project,
    Size size = const Size(1440, 960),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HackathonShell(
          initial: initial == null
              ? null
              : WorkspaceLocation(initial, tab, project),
          preloaded: {humor.id: humor, serverpod.id: serverpod},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  List<String> rowIds(WidgetTester tester) => [
    for (final w in tester.widgetList(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('row-'),
      ),
    ))
      (w.key! as ValueKey<String>).value.substring(4),
  ];

  testWidgets('Hackathons list is the entry, with status for each', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Hackathons'), findsOneWidget);
    expect(
      find.text('Build your Flutter Butler with Serverpod'),
      findsOneWidget,
    );
    expect(find.text('Humor Genome'), findsOneWidget);
    expect(
      find.descendant(
        of: key('hackathon-serverpod'),
        matching: find.text('117 submissions'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: key('hackathon-serverpod'),
        matching: find.text('31 deep reviews'),
      ),
      findsOneWidget,
    );
    expect(find.text('Acquired and indexed'), findsOneWidget);
    // No dataset switcher anywhere, and no workspace built yet.
    expect(key('back-to-hackathons'), findsNothing);
    expect(key('row-butler-xlrjsp'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  Finder tab(String name) => key('workspace-$name');

  /// The tab that is drawn as active carries the accent fill.
  bool isActive(WidgetTester tester, String name) {
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: tab(name),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return (box.decoration! as BoxDecoration).color == accent;
  }

  /// The breadcrumb, as the words a judge would read.
  String crumbs(WidgetTester tester) => [
    for (final id in [
      'crumb-home',
      'crumb-hackathon',
      'crumb-workspace',
      'crumb-project',
    ])
      if (key(id).evaluate().isNotEmpty)
        (tester.widget(key(id)) is Text
                ? tester.widget<Text>(key(id))
                : tester.widget<Text>(
                    find.descendant(of: key(id), matching: find.byType(Text)),
                  ))
            .data!,
  ].join(' / ');

  testWidgets('A hackathon opens on its Overview inside a persistent header', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, key('hackathon-serverpod'));
    expect(
      find.text('Build your Flutter Butler with Serverpod'),
      findsOneWidget,
    );
    expect(crumbs(tester), 'Hackathons / Serverpod / Overview');
    expect(isActive(tester, 'overview'), isTrue);
    expect(isActive(tester, 'submissions'), isFalse);
    expect(
      find.descendant(of: tab('submissions'), matching: find.text('117')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tab('competition'), matching: find.text('31')),
      findsOneWidget,
    );
    // What was acquired, counted from the data.
    for (final (label, value) in [
      ('submissions', '117'),
      ('writeups', '117'),
      ('repositories', '45'),
      ('demo-videos', '104'),
      ('deep-reviews', '31'),
    ]) {
      expect(
        find.descendant(of: key('overview-$label'), matching: find.text(value)),
        findsOneWidget,
        reason: label,
      );
    }
    // The table is not built until Submissions is opened.
    expect(key('row-butler-xlrjsp'), findsNothing);
    // No dataset switcher anywhere inside the workspace.
    expect(find.text('Humor Genome'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Humor Genome shares the same shell and hierarchy', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, key('hackathon-humor-genome'));
    expect(crumbs(tester), 'Hackathons / Humor Genome / Overview');
    expect(find.text('Humor Genome'), findsWidgets);
    for (final name in ['overview', 'submissions', 'competition']) {
      expect(tab(name), findsOneWidget, reason: name);
    }
    expect(
      find.descendant(of: tab('submissions'), matching: find.text('6')),
      findsOneWidget,
    );
    expect(key('overview-browse'), findsOneWidget);
    expect(key('dot-killjoy'), findsNothing);

    // A plain Submissions table: no lanes, no filters, just the six.
    await tap(tester, key('overview-browse'));
    expect(crumbs(tester), 'Hackathons / Humor Genome / Submissions');
    expect(isActive(tester, 'submissions'), isTrue);
    for (final id in humor.competition.projects.map((p) => p.id)) {
      expect(key('row-$id'), findsOneWidget, reason: id);
    }
    expect(find.text('Written by hand'), findsNWidgets(6));
    expect(key('lens-all'), findsNothing);
    expect(key('view-in-competition'), findsNothing);
    await tap(tester, key('select-killjoy'));
    await tap(tester, key('select-laughlensai'));
    await tap(tester, key('view-in-competition'));
    expect(crumbs(tester), 'Hackathons / Humor Genome / Competition');
    expect(
      find.text('Two projects. What they claim, and what stands behind it.'),
      findsOneWidget,
    );
    expect(key('dot-killjoy'), findsOneWidget);
    expect(key('dot-why-they-laugh'), findsNothing);

    // A project is the one level below, and back returns to the field.
    await tap(tester, key('dot-killjoy'));
    expect(find.text('IDEA'), findsOneWidget);
    await tap(tester, key('open-project'));
    expect(
      crumbs(tester),
      'Hackathons / Humor Genome / Competition / Killjoy',
    );
    expect(isActive(tester, 'competition'), isTrue);
    expect(find.text('Back to Competition'), findsOneWidget);
    await tap(tester, key('back-to-competition'));
    expect(crumbs(tester), 'Hackathons / Humor Genome / Competition');
    expect(key('back-to-competition'), findsNothing);
    expect(key('dot-killjoy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A card always opens the Overview, whatever was visited', (
    tester,
  ) async {
    await mount(tester, initial: 'serverpod');
    await tap(tester, key('lens-all'));
    await tester.enterText(key('triage-search'), 'butler');
    await tester.pumpAndSettle();
    await tap(tester, key('crumb-home'));
    expect(find.text('Choose a hackathon to review.'), findsOneWidget);

    // Same click, same result: the Overview, with the table kept underneath.
    for (var visit = 0; visit < 2; visit++) {
      await tap(tester, key('hackathon-serverpod'));
      expect(isActive(tester, 'overview'), isTrue, reason: 'visit $visit');
      expect(key('overview-browse'), findsOneWidget);
      await tap(tester, key('workspace-submissions'));
      expect(find.text('butler'), findsOneWidget);
      await tap(tester, key('crumb-home'));
    }

    // Leaving from the Competition and coming back lands on the Overview.
    await tap(tester, key('hackathon-serverpod'));
    await tap(tester, tab('competition'));
    await tap(tester, key('crumb-home'));
    await tap(tester, key('hackathon-serverpod'));
    expect(isActive(tester, 'overview'), isTrue);
    await tap(tester, tab('submissions'));
    expect(find.text('WHY LOOK'), findsOneWidget);

    // Humor Genome likewise, with its own selection preserved.
    await tap(tester, key('crumb-home'));
    await tap(tester, key('hackathon-humor-genome'));
    await tap(tester, tab('submissions'));
    await tap(tester, key('select-killjoy'));
    await tap(tester, key('view-in-competition'));
    await tap(tester, key('crumb-home'));
    await tap(tester, key('hackathon-humor-genome'));
    expect(isActive(tester, 'overview'), isTrue);
    await tap(tester, tab('submissions'));
    expect(find.text('View 1 in Competition'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The fresh-state walk keeps every level legible', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, key('hackathon-serverpod'));
    await tap(tester, key('overview-browse'));
    expect(crumbs(tester), 'Hackathons / Serverpod / Submissions');

    // A filter is view state: the breadcrumb and the tab do not move.
    await tap(tester, key('lens-verify'));
    expect(crumbs(tester), 'Hackathons / Serverpod / Submissions');
    expect(isActive(tester, 'submissions'), isTrue);

    Future<void> select(String id, String search) async {
      await tester.enterText(key('triage-search'), search);
      await tester.pumpAndSettle();
      await tap(tester, key('select-$id'));
    }

    // Neither project is in this filter; widen it, pick, and narrow again.
    await tap(tester, key('lens-all'));
    await select('naggy', 'Naggy');
    await select('symptomscribe', 'SymptomScribe');
    await tap(tester, key('lens-verify'));
    await tester.enterText(key('triage-search'), '');
    await tester.pumpAndSettle();
    await tap(tester, key('view-in-competition'));
    expect(crumbs(tester), 'Hackathons / Serverpod / Competition');
    expect(
      find.descendant(of: tab('competition'), matching: find.text('2')),
      findsOneWidget,
    );

    // A mode is view state too, and survives the drill-down.
    await tap(tester, key('mode-sponsorTech'));
    expect(find.text('Serverpod centrality  →'), findsOneWidget);
    await tap(tester, key('mode-ideaIntegration'));
    await tap(tester, key('mode-sponsorTech'));
    await tap(tester, key('dot-naggy'));
    await tap(tester, key('open-project'));
    expect(crumbs(tester), 'Hackathons / Serverpod / Competition / Naggy');
    await tap(tester, key('back-to-competition'));
    expect(crumbs(tester), 'Hackathons / Serverpod / Competition');
    expect(find.text('Serverpod centrality  →'), findsOneWidget);

    // Back to Submissions: the same filter, search and selection.
    await tap(tester, tab('submissions'));
    expect(find.text('CLAIM'), findsOneWidget);
    expect(find.text('View 2 in Competition'), findsOneWidget);
    await tap(tester, key('lens-underTold'));
    await tester.enterText(key('triage-search'), 'Naggy');
    await tester.pumpAndSettle();
    await tap(tester, key('row-naggy'));
    await tap(tester, key('open-deep-review'));
    expect(crumbs(tester), 'Hackathons / Serverpod / Submissions / Naggy');
    expect(isActive(tester, 'submissions'), isTrue);
    expect(find.text('Back to Submissions'), findsOneWidget);
    await tap(tester, key('back-to-submissions'));
    expect(crumbs(tester), 'Hackathons / Serverpod / Submissions');
    expect(find.text('CODE SUBSTANCE'), findsOneWidget);
    expect(key('detail-naggy'), findsOneWidget);
    expect(
      tester.widget<TextField>(key('triage-search')).controller!.text,
      'Naggy',
    );
    // The Competition view was left at the field, in the mode it was in.
    await tap(tester, tab('competition'));
    expect(find.text('Serverpod centrality  →'), findsOneWidget);
    expect(key('back-to-submissions'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Locations round-trip through paths', (tester) async {
    for (final path in [
      '/hackathons/serverpod',
      '/hackathons/serverpod/submissions',
      '/hackathons/serverpod/competition',
      '/hackathons/serverpod/competition/naggy',
      '/hackathons/serverpod/submissions/naggy',
    ]) {
      expect(WorkspaceLocation.parse(path)!.path, path);
    }
    expect(WorkspaceLocation.parse('/'), isNull);
    expect(WorkspaceLocation.parse('/hackathons'), isNull);
    // A project opened from a path lands on that origin.
    await mount(
      tester,
      initial: 'serverpod',
      tab: WorkspaceTab.submissions,
      project: 'naggy',
    );
    expect(crumbs(tester), 'Hackathons / Serverpod / Submissions / Naggy');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Triage opens simple: lenses, search and three columns', (
    tester,
  ) async {
    await mount(tester, initial: 'serverpod');
    expect(
      find.text('Every submission, and the reason it may deserve a look.'),
      findsOneWidget,
    );
    for (final header in ['PROJECT', 'WHY LOOK', 'EVIDENCE']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    // Implementation detail stays underneath until asked for.
    for (final hidden in [
      'REVIEW',
      'SCAFFOLD DELTA',
      'SERVERPOD FOOTPRINT',
      'CLAIMS',
      'SERVERPOD CENTRALITY',
      'LANE',
    ]) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }
    // Nothing to configure: the lens is the only control besides search.
    for (final gone in [
      'open-advanced',
      'refine-codeInspected',
      'compare-selected',
      'view-in-competition',
      'result-count',
    ]) {
      expect(key(gone), findsNothing, reason: gone);
    }
    expect(
      find.descendant(of: key('lens-all'), matching: find.text('117')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Each lens brings its own rows, columns and order', (
    tester,
  ) async {
    await mount(tester, initial: 'serverpod');
    await tap(tester, key('lens-underTold'));
    expect(rowIds(tester), [
      'naggy',
      'filo-ai',
      'pos-sip-sync',
      'butler-lee',
      'my-coach-ai',
      'lifesync-ai-zm1hp4',
      'legal-lens-foazyi',
      'pocket-butler-anti-theft-security-app',
      'lifebutler',
      'root-radar',
      'social-fabric',
    ]);
    for (final header in ['CODE SUBSTANCE', 'SUBMISSION GAP', 'EVIDENCE']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('WHY LOOK'), findsNothing);
    expect(
      find.text('The code shows more than the writeup says.'),
      findsOneWidget,
    );

    await tap(tester, key('lens-verify'));
    for (final header in ['CLAIM', 'WHAT WE FOUND', 'JUDGE QUESTION']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('EVIDENCE'), findsNothing);
    // More rows than fit are built lazily; the lens shows the full count.
    expect(
      find.descendant(of: key('lens-verify'), matching: find.text('95')),
      findsOneWidget,
    );
    await tester.enterText(key('triage-search'), 'Social Fabric');
    await tester.pumpAndSettle();
    expect(
      find.text('App never calls its 39 endpoint methods'),
      findsOneWidget,
    );
    await tester.enterText(key('triage-search'), '');
    await tester.pumpAndSettle();

    await tap(tester, key('lens-substantial'));
    for (final header in ['BUILD EVIDENCE', 'SERVERPOD ROLE', 'EVIDENCE']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    // 18 rows; the table builds only those in view.
    expect(
      find.descendant(of: key('lens-substantial'), matching: find.text('18')),
      findsOneWidget,
    );
    expect(rowIds(tester).first, 'crewboard');

    await tap(tester, key('lens-sponsor'));
    for (final header in ['SERVERPOD ROLE', 'WHY IT MATTERS', 'EVIDENCE']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('Described but not found: sign-in'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search narrows every lens and clears in one step', (
    tester,
  ) async {
    await mount(tester, initial: 'serverpod');
    await tester.enterText(key('triage-search'), 'dermatologist');
    await tester.pumpAndSettle();
    expect(rowIds(tester), ['skinaware']);
    // Lens counts follow the search.
    expect(
      find.descendant(of: key('lens-substantial'), matching: find.text('1')),
      findsOneWidget,
    );
    await tap(tester, key('lens-underTold'));
    expect(
      find.text('No submission here matches “dermatologist”.'),
      findsOneWidget,
    );
    await tap(tester, key('clear-search'));
    expect(rowIds(tester), [
      'naggy',
      'filo-ai',
      'pos-sip-sync',
      'butler-lee',
      'my-coach-ai',
      'lifesync-ai-zm1hp4',
      'legal-lens-foazyi',
      'pocket-butler-anti-theft-security-app',
      'lifebutler',
      'root-radar',
      'social-fabric',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'An open row shows four things; the rest waits behind one toggle',
    (
      tester,
    ) async {
      await mount(tester, initial: 'serverpod');
      await tap(tester, key('lens-underTold'));
      await tap(tester, key('row-social-fabric'));
      expect(key('detail-social-fabric'), findsOneWidget);
      expect(find.text('WHY IT’S HERE'), findsOneWidget);
      expect(find.text('WHAT FINALIST BRIEF VERIFIED'), findsOneWidget);
      expect(find.text('JUDGE QUESTION'), findsOneWidget);
      expect(key('open-deep-review'), findsOneWidget);
      expect(
        find.text('Writeup omits: 24 tables, Serverpod auth'),
        findsWidgets,
      );
      // One question, the one behind the Unresolved lane.
      expect(
        find.textContaining('never calls the server’s 39 endpoint methods'),
        findsOneWidget,
      );
      // Deeper layers stay closed until asked for.
      for (final layer in [
        'more-evidence',
        'more-repository',
        'more-jev',
        'more-claims',
        'more-technical',
      ]) {
        expect(key(layer), findsNothing, reason: layer);
      }
      expect(find.text('OTHER QUESTIONS'), findsNothing);
      expect(find.textContaining('12 commits came after'), findsNothing);
      expect(find.text('Scaffold delta'), findsNothing);

      await tap(tester, key('more-details'));
      expect(find.text('OTHER QUESTIONS'), findsOneWidget);
      expect(find.textContaining('12 commits came after'), findsOneWidget);
      await tap(tester, key('more-repository'));
      expect(find.text('Scaffold delta'), findsOneWidget);
      await tap(tester, key('more-jev'));
      expect(find.text('The butler'), findsOneWidget);

      // The judge's own status shows on the row only once set.
      expect(key('status-social-fabric'), findsNothing);
      await tap(tester, key('review-status'));
      await tap(tester, find.text('In review').last);
      expect(key('status-social-fabric'), findsOneWidget);

      // Esc closes the panel without leaving the table.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(key('detail-social-fabric'), findsNothing);
      expect(key('row-social-fabric'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A triage row opens its deep review in the Submission View', (
    tester,
  ) async {
    await mount(tester, initial: 'serverpod');
    // At 117 rows Doby is past the lazily built part of the table.
    await tester.enterText(key('triage-search'), 'Doby');
    await tester.pumpAndSettle();
    await tap(tester, key('row-doby-rna2yf'));
    await tap(tester, key('open-deep-review'));
    final doby = serverpod.competition.projects.singleWhere(
      (p) => p.id == 'doby-rna2yf',
    );
    expect(tester.widget<GraphView>(key('graph-idea')).graph, doby.idea);
    expect(
      tester.widget<GraphView>(key('graph-integration')).graph,
      doby.integration,
    );
    await tap(tester, key('hint-no-model'));
    expect(key('question-no-model'), findsOneWidget);
    expect(find.text('IDEA / INTEGRATION MISMATCH'), findsOneWidget);

    // Esc closes the question, then returns to where the review was opened.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(crumbs(tester), 'Hackathons / Serverpod / Submissions');
    expect(find.text('Back to Submissions'), findsNothing);
    await tap(tester, tab('competition'));
    expect(find.byType(GraphView), findsNothing);
    expect(find.text('Sponsor Tech · Serverpod'), findsOneWidget);
    await tap(tester, key('mode-sponsorTech'));
    expect(find.text('Serverpod centrality  →'), findsOneWidget);

    // The table is exactly as it was left.
    await tap(tester, tab('submissions'));
    expect(key('detail-doby-rna2yf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Selected rows go to the Competition View in one step', (
    tester,
  ) async {
    await mount(tester, initial: 'serverpod');
    expect(
      find.descendant(of: tab('competition'), matching: find.text('31')),
      findsOneWidget,
    );
    // The hand-off appears only once something is selected.
    expect(key('view-in-competition'), findsNothing);
    expect(find.textContaining('Compare'), findsNothing);
    // Rows without a deep review cannot be selected.
    expect(key('select-course-craft-ai'), findsNothing);

    // With more rows than fit, find each row by search first.
    Future<void> select(String id, String search) async {
      await tester.enterText(key('triage-search'), search);
      await tester.pumpAndSettle();
      await tap(tester, key('select-$id'));
    }

    await select('social-fabric', 'Social Fabric');
    expect(find.text('View 1 in Competition'), findsOneWidget);
    await select('elderly-j462fy', 'Elderly');
    expect(find.text('View 2 in Competition'), findsOneWidget);
    expect(
      find.descendant(of: tab('competition'), matching: find.text('2')),
      findsOneWidget,
    );
    await tap(tester, key('view-in-competition'));
    expect(key('dot-social-fabric'), findsOneWidget);
    expect(key('dot-elderly-j462fy'), findsOneWidget);
    expect(key('dot-doby-rna2yf'), findsNothing);
    expect(
      find.text('Two projects. What they claim, and what stands behind it.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('02 OF 117 SUBMISSIONS'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'The triage table and every deep review fit a laptop window',
    (tester) async {
      final submissions = serverpod.triage!.submissions;
      final writeups = parseWriteups(
        File(serverpod.source.writeups!).readAsStringSync(),
      );
      await mount(tester, initial: 'serverpod', size: const Size(1100, 800));
      for (final lens in ReviewLens.values) {
        await tap(tester, key('lens-${lens.name}'));
        // Every lens's columns fit a laptop window without side-scrolling.
        expect(
          tester.getRect(key('sort-${lens.columns.last.name}')).right,
          lessThanOrEqualTo(1100 - 24),
          reason: lens.name,
        );
      }
      await tap(tester, key('lens-all'));
      await tap(tester, key('lane-rules'));
      expect(find.text('How the triage table is derived'), findsOneWidget);
      await tap(tester, find.text('Close'));
      // Rows are built lazily, so each one is reached through search.
      for (final s in submissions) {
        await tester.enterText(key('triage-search'), s.title);
        await tester.pumpAndSettle();
        await tap(tester, key('row-${s.id}'));
        expect(key('detail-${s.id}'), findsOneWidget);
        await tap(tester, key('more-details'));
        for (final layer in [
          'more-evidence',
          'more-repository',
          'more-jev',
          'more-technical',
          'more-claims',
        ]) {
          await tap(tester, key(layer));
        }
        await tap(tester, key('writeup-lines'));
        // An empty template writeup has headings only.
        final first = writeups[s.id]!.firstWhere(
          (l) => !l.heading,
          orElse: () => writeups[s.id]!.first,
        );
        expect(
          find.text(first.heading ? first.text.toUpperCase() : first.text),
          findsWidgets,
        );
        await tap(tester, key('close-detail'));
      }

      await tap(tester, key('workspace-competition'));
      final projects = serverpod.competition.projects;
      // Dots overlap in a dense field, so open the first review directly.
      tester
          .state<ExplorationScreenState>(find.byType(ExplorationScreen))
          .openProject(projects.first.id);
      await tester.pumpAndSettle();
      for (final p in projects) {
        await tap(tester, key('jump-${p.id}'));
        // A generated review never passes for one a person wrote.
        expect(
          find.text('Generated automatically'),
          p.generated ? findsOneWidget : findsNothing,
          reason: p.id,
        );
        for (final q in p.questions) {
          await tap(tester, key('hint-${q.id}'));
          expect(key('question-${q.id}'), findsOneWidget, reason: q.id);
          await tap(tester, key('close-inspector'));
        }
        for (final lens in SubmissionLens.values) {
          for (final n in p.graph(lens).nodes) {
            await tester.tap(key('node-${lens.name}-${n.id}'));
            await tester.pumpAndSettle();
            expect(key('inspector-${lens.name}-${n.id}'), findsOneWidget);
            await tester.tap(key('close-inspector'));
            await tester.pumpAndSettle();
          }
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
}
