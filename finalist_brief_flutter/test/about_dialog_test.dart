import 'package:finalist_brief_flutter/views/exploration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(WidgetTester tester, {bool compact = false}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BrandMark(compact: compact),
            ),
          ),
        ),
      );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('about-button')));
    await tester.pumpAndSettle();
    expect(find.text('About Finalist Brief'), findsOneWidget);
    expect(
      find.text(
        'AI assists the review process. Judges make the final decisions.',
      ),
      findsOneWidget,
    );
  }

  final dialog = find.byKey(const ValueKey('about-dialog'));

  testWidgets('the info button sits right after the wordmark', (tester) async {
    await mount(tester);
    final word = tester.getTopRight(find.text('FINALIST BRIEF'));
    final info = tester.getTopLeft(find.byKey(const ValueKey('about-button')));
    expect(info.dx - word.dx, inInclusiveRange(0, 8));
    expect(find.byTooltip('About Finalist Brief'), findsOneWidget);
  });

  testWidgets('closes with X', (tester) async {
    await mount(tester);
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('about-close')));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });

  testWidgets('closes with Escape', (tester) async {
    await mount(tester);
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });

  testWidgets('closes on a click outside', (tester) async {
    await mount(tester);
    await open(tester);
    await tester.tapAt(const Offset(4, 590));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });

  testWidgets('stays reachable in the compact header and on phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await mount(tester, compact: true);
    await open(tester);
    expect(tester.takeException(), isNull);
    final card = find.descendant(of: dialog, matching: find.byType(Material));
    expect(tester.getSize(card.first).width, lessThanOrEqualTo(360 - 32));
  });
}
