import 'dart:io';

import 'package:finalist_brief_flutter/representation/project.dart';
import 'package:finalist_brief_flutter/views/exploration_screen.dart';
import 'package:finalist_brief_flutter/visualization/graph_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final competition = parseCompetition(
    File('assets/representations/humor_genome.json').readAsStringSync(),
  );
  final projects = competition.projects;
  ProjectRepresentation project(String id) =>
      projects.singleWhere((p) => p.id == id);

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1440, 960),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: ExplorationScreen(competition: competition)),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> open(WidgetTester tester, String id) async {
    await tester.tap(key('dot-$id'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Modes animate positions and interrupted switches remain continuous',
    (tester) async {
      await mount(tester);
      final dot = key('dot-crowdwork-copilot');
      final start = tester.getCenter(dot);
      await tester.tap(key('mode-sponsorTech'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final middle = tester.getCenter(dot);
      expect(middle, isNot(start));
      await tester.tap(key('mode-ideaIntegration'));
      await tester.pump();
      expect(tester.getCenter(dot), middle);
      await tester.pumpAndSettle();
      expect(tester.getCenter(dot), start);
      expect(find.text('Sponsor Tech · Gemma'), findsOneWidget);
      expect(find.text('↑  Idea distinctiveness'), findsOneWidget);
      expect(find.text('Custom axes'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Zoom keeps the anchor, shows Idea and Integration together, and returns to exact context',
    (tester) async {
      await mount(tester);
      await tester.tap(key('mode-sponsorTech'));
      await tester.pumpAndSettle();
      expect(find.text('Gemma centrality  →'), findsOneWidget);
      final dot = key('dot-why-they-laugh');
      final start = tester.getCenter(dot);
      await tester.tap(dot);
      await tester.pump();
      expect(
        tester.getCenter(dot),
        start,
        reason: 'Controls must not resize the field on entry',
      );
      await tester.pumpAndSettle();
      final why = project('why-they-laugh');
      expect(tester.widget<GraphView>(key('graph-idea')).graph, why.idea);
      expect(
        tester.widget<GraphView>(key('graph-integration')).graph,
        why.integration,
      );
      // Side by side, both halves are readable; each sits in its own half.
      expect(
        tester.getCenter(key('graph-idea')).dx,
        lessThan(tester.getCenter(key('graph-integration')).dx),
      );

      await tester.tap(key('focus-integration'));
      await tester.pumpAndSettle();
      expect(find.byType(GraphView), findsOneWidget);
      expect(
        tester.widget<GraphView>(find.byType(GraphView)).compact,
        isFalse,
      );
      await tester.tap(key('focus-both'));
      await tester.pumpAndSettle();

      await tester.tap(key('jump-killjoy'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GraphView>(key('graph-integration')).graph,
        project('killjoy').integration,
      );
      await tester.tap(key('jump-why-they-laugh'));
      await tester.pumpAndSettle();
      await tester.tap(key('back-to-competition'));
      await tester.pumpAndSettle();
      expect(tester.getCenter(dot), start);
      expect(find.byType(GraphView), findsNothing);
      expect(
        tester.widget<ChoiceChip>(key('mode-sponsorTech')).selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Clicking a node reveals its evidence and cross-highlights its counterparts',
    (tester) async {
      await mount(tester);
      await open(tester, 'room-sense-text');
      await tester.tap(key('node-idea-room2'));
      await tester.pumpAndSettle();
      expect(key('inspector-idea-room2'), findsOneWidget);
      expect(find.text('Described'), findsWidgets);
      expect(find.text('4 audiences → 1 runtime'), findsWidgets);
      final integration = tester.widget<GraphView>(key('graph-integration'));
      expect(integration.emphasis['runtime'], NodeEmphasis.related);
      expect(integration.emphasis['explain'], NodeEmphasis.dimmed);
      expect(
        tester.widget<GraphView>(key('graph-idea')).emphasis['room2'],
        NodeEmphasis.selected,
      );

      // A demonstrated node shows its demo frame and a timestamped source.
      await tester.tap(key('jump-killjoy'));
      await tester.pumpAndSettle();
      await tester.tap(key('node-integration-gemma'));
      await tester.pumpAndSettle();
      expect(find.text('Demonstrated'), findsWidgets);
      expect(find.text('Demo video · 1:16'), findsWidgets);
      expect(
        find.textContaining('backend/humor_engine.py', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);

      await tester.tap(key('close-inspector'));
      await tester.pumpAndSettle();
      expect(key('inspector-integration-gemma'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A question hint opens a concise judge question; Esc closes it, then leaves',
    (tester) async {
      await mount(tester);
      await open(tester, 'room-sense-text');
      await tester.tap(key('hint-four-audiences'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'These four audiences appear to use the same model. What mechanism keeps their behavior meaningfully distinct?',
        ),
        findsOneWidget,
      );
      expect(find.text('IDEA / INTEGRATION MISMATCH'), findsOneWidget);
      expect(find.text('WHY FINALIST BRIEF ASKS'), findsOneWidget);
      final idea = tester.widget<GraphView>(key('graph-idea'));
      for (final room in ['room1', 'room2', 'room3', 'room4']) {
        expect(idea.emphasis[room], NodeEmphasis.related);
      }
      expect(idea.emphasis['compare'], NodeEmphasis.dimmed);

      // Following an anchor moves from the question to that node's evidence.
      await tester.tap(find.text('Idea · Comedy Nerd'));
      await tester.pumpAndSettle();
      expect(key('inspector-idea-room1'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(key('inspector-idea-room1'), findsNothing);
      expect(find.byType(GraphView), findsNWidgets(2));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(GraphView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Mapping chips inspect a relationship and its provenance', (
    tester,
  ) async {
    await mount(tester);
    await open(tester, 'humor-genome-studio');
    await tester.tap(key('mapping-chip-6 tools → 1 pipeline'));
    await tester.pumpAndSettle();
    expect(key('mapping-6 tools → 1 pipeline'), findsOneWidget);
    expect(find.text('Found in code'), findsWidgets);
    final integration = tester.widget<GraphView>(key('graph-integration'));
    expect(integration.emphasis['assemble'], NodeEmphasis.related);
    expect(integration.emphasis['critic'], NodeEmphasis.dimmed);
    // Tapping empty space closes the inspector.
    await tester.tapAt(const Offset(700, 890));
    await tester.pumpAndSettle();
    expect(key('mapping-6 tools → 1 pipeline'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Every project and every question fits a laptop window without overflow',
    (tester) async {
      await mount(tester, size: const Size(1100, 800));
      await open(tester, projects.first.id);
      for (final p in projects) {
        await tester.ensureVisible(key('jump-${p.id}'));
        await tester.pumpAndSettle();
        await tester.tap(key('jump-${p.id}'));
        await tester.pumpAndSettle();
        for (final q in p.questions) {
          await tester.tap(key('hint-${q.id}'));
          await tester.pumpAndSettle();
          expect(key('question-${q.id}'), findsOneWidget, reason: q.id);
          await tester.tap(key('close-inspector'));
          await tester.pumpAndSettle();
        }
        for (final lens in SubmissionLens.values) {
          final id = p.graph(lens).nodes.first.id;
          await tester.tap(key('node-${lens.name}-$id'));
          await tester.pumpAndSettle();
          expect(key('inspector-${lens.name}-$id'), findsOneWidget);
          await tester.tap(key('close-inspector'));
          await tester.pumpAndSettle();
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
}
