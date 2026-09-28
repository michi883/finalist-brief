import 'dart:io';

import 'package:finalist_brief_flutter/hackathon/hackathon.dart';
import 'package:finalist_brief_flutter/representation/project.dart';
import 'package:finalist_brief_flutter/triage/review_lens.dart';
import 'package:finalist_brief_flutter/triage/triage.dart';
import 'package:finalist_brief_flutter/views/hackathon_shell.dart';
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
    humor = load(hackathonSources[0]);
    serverpod = load(hackathonSources[1]);
  });

  Future<void> mount(
    WidgetTester tester, {
    String? initial,
    Size size = const Size(1440, 960),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HackathonShell(
          initial: initial,
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

  testWidgets('Humor Genome opens first, unchanged, with the switcher', (
    tester,
  ) async {
    await mount(tester);
    expect(key('hackathon-humor-genome'), findsOneWidget);
    expect(
      find.text('Six projects. What they claim, and what stands behind it.'),
      findsOneWidget,
    );
    expect(find.text('Sponsor Tech · Gemma'), findsOneWidget);
    expect(key('dot-killjoy'), findsOneWidget);
    expect(key('row-social-fabric'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Switching hackathons keeps each one’s state', (tester) async {
    await mount(tester);
    await tap(tester, key('mode-sponsorTech'));
    await tap(tester, key('dot-killjoy'));
    expect(
      tester.widget<GraphView>(key('graph-integration')).graph,
      humor.competition.projects
          .singleWhere((p) => p.id == 'killjoy')
          .integration,
    );

    await tap(tester, key('hackathon-serverpod'));
    expect(key('row-butler-xlrjsp'), findsOneWidget);
    expect(key('dot-killjoy'), findsNothing);
    await tap(tester, key('lens-all'));
    await tester.enterText(key('triage-search'), 'butler');
    await tester.pumpAndSettle();
    await tap(tester, key('sort-project'));
    final visible = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('row-'),
    );
    final beforeSwitch = tester.widgetList(visible).map((w) => w.key).toList();

    await tap(tester, key('hackathon-humor-genome'));
    // The open project and the mode survive the round trip.
    expect(find.byType(GraphView), findsNWidgets(2));
    await tap(tester, key('back-to-competition'));
    expect(
      tester.widget<ChoiceChip>(key('mode-sponsorTech')).selected,
      isTrue,
    );

    await tap(tester, key('hackathon-serverpod'));
    expect(find.text('butler'), findsOneWidget);
    expect(beforeSwitch, hasLength(16));
    expect(
      tester.widgetList(visible).map((w) => w.key).toList(),
      beforeSwitch,
    );
    expect(find.text('WHY LOOK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Triage opens simple: lenses, search and three columns', (
    tester,
  ) async {
    await mount(tester, initial: 'serverpod');
    expect(find.text('117 submissions'), findsOneWidget);
    expect(find.text('full field'), findsOneWidget);
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

    // Esc closes the question, then returns to the Serverpod field.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(GraphView), findsNothing);
    expect(find.text('Sponsor Tech · Serverpod'), findsOneWidget);
    await tap(tester, key('mode-sponsorTech'));
    expect(find.text('Serverpod centrality  →'), findsOneWidget);

    // The table is exactly as it was left.
    await tap(tester, key('workspace-triage'));
    expect(key('detail-doby-rna2yf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Selected rows go to the Competition View in one step', (
    tester,
  ) async {
    await mount(tester, initial: 'serverpod');
    expect(find.text('Competition · 24'), findsOneWidget);
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
    expect(find.text('Competition · 2'), findsOneWidget);
    await tap(tester, key('view-in-competition'));
    expect(key('dot-social-fabric'), findsOneWidget);
    expect(key('dot-elderly-j462fy'), findsOneWidget);
    expect(key('dot-doby-rna2yf'), findsNothing);
    expect(
      find.text('Two projects. What they claim, and what stands behind it.'),
      findsOneWidget,
    );
    expect(
      find.text('DEEP REVIEW  /  02 OF 117 SUBMISSIONS'),
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
      await tap(tester, key('dot-${projects.first.id}'));
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
