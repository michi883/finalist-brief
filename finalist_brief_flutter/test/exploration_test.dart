import 'dart:io';

import 'package:finalist_brief_flutter/representation/project.dart';
import 'package:finalist_brief_flutter/views/exploration_screen.dart';
import 'package:finalist_brief_flutter/visualization/graph_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final projects = parseProjects(
    File('assets/representations/humor_genome.json').readAsStringSync(),
  );
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1440, 960),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: ExplorationScreen(projects: projects)),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  testWidgets(
    'Presets animate positions and interrupted switches remain continuous',
    (tester) async {
      await mount(tester);
      final dot = key('dot-crowdwork-copilot');
      final start = tester.getCenter(dot);
      await tester.tap(find.text('Human Loop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final middle = tester.getCenter(dot);
      expect(middle, isNot(start));
      await tester.tap(find.text('System Depth'));
      await tester.pump();
      expect(tester.getCenter(dot), middle);
      await tester.pumpAndSettle();
      expect(tester.getCenter(dot), isNot(middle));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Zoom keeps the anchor, reveals lenses, jumps projects, and returns to exact context',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Audience Reality'));
      await tester.pumpAndSettle();
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
      expect(
        tester.widget<GraphView>(find.byType(GraphView)).graph,
        projects.last.idea,
      );
      await tester.tap(key('lens-integration'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GraphView>(find.byType(GraphView)).graph,
        projects.last.integration,
      );
      await tester.tap(key('jump-killjoy'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GraphView>(find.byType(GraphView)).graph,
        projects[2].integration,
      );
      await tester.tap(key('jump-why-they-laugh'));
      await tester.pumpAndSettle();
      await tester.tap(key('back-to-competition'));
      await tester.pumpAndSettle();
      expect(tester.getCenter(dot), start);
      expect(find.byType(GraphView), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Audience Reality'),
            )
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Custom axes preserve context through zoom and reverse at laptop size',
    (tester) async {
      await mount(tester, size: const Size(1100, 800));
      await tester.tap(find.text('Custom axes'));
      await tester.pumpAndSettle();
      final x = find.byType(DropdownButtonFormField<Dimension>).first;
      await tester.tap(x);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Creative scope').last);
      await tester.pumpAndSettle();
      final dot = key('dot-killjoy');
      final position = tester.getCenter(dot);
      await tester.tap(dot);
      await tester.pumpAndSettle();
      await tester.tap(key('back-to-competition'));
      await tester.pumpAndSettle();
      expect(tester.getCenter(dot), position);
      expect(find.byType(DropdownButtonFormField<Dimension>), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
