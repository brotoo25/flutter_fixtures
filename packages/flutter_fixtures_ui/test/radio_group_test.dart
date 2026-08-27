import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_ui/flutter_fixtures_ui.dart';

Future<void> _openDialog(
  WidgetTester tester,
  FixtureCollection fixture,
) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
  FixturesDialogView(contextProvider: () => navigatorKey.currentContext!)
      .pick(fixture);
  await tester.pumpAndSettle();
}

void main() {
  group('FixturesDialogView RadioGroup', () {
    testWidgets('uses RadioGroup instead of deprecated groupValue/onChanged',
        (WidgetTester tester) async {
      final fixture = FixtureCollection(
        description: 'Test Fixture',
        items: [
          FixtureDocument(
              identifier: 'Option 1',
              description: '200',
              defaultOption: true,
              data: {'test': 1}),
          FixtureDocument(
              identifier: 'Option 2',
              description: '404',
              defaultOption: false,
              data: {'test': 2}),
        ],
      );

      await _openDialog(tester, fixture);

      // Verify RadioGroup is present
      expect(find.byType(RadioGroup<int>), findsOneWidget);

      // Verify Radio widgets don't have deprecated properties
      final radioWidgets =
          tester.widgetList<Radio<int>>(find.byType(Radio<int>));
      for (final radio in radioWidgets) {
        // In the new API, Radio widgets should not have groupValue or onChanged
        // These are managed by the RadioGroup ancestor
        expect(radio.value, isNotNull);
      }

      // Verify we can interact with radio buttons
      await tester.tap(find.byType(Radio<int>).last);
      await tester.pump();

      // The dialog should still be functional
      expect(find.text('Test Fixture'), findsOneWidget);
      expect(find.text('Option 1 - 200'), findsOneWidget);
      expect(find.text('Option 2 - 404'), findsOneWidget);
    });

    testWidgets('radio selection works with RadioGroup',
        (WidgetTester tester) async {
      final fixture = FixtureCollection(
        description: 'Test Selection',
        items: [
          FixtureDocument(
              identifier: 'First',
              description: '200',
              defaultOption: true,
              data: {'id': 1}),
          FixtureDocument(
              identifier: 'Second',
              description: '201',
              defaultOption: false,
              data: {'id': 2}),
        ],
      );

      await _openDialog(tester, fixture);

      // Verify initial state - first radio should be selected (index 0)
      final radioGroup =
          tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>));
      expect(radioGroup.groupValue, equals(0));

      // Tap on the second option to select the second radio button (avoid the Remember checkbox tile)
      await tester.tap(find.text('Second - 201'));
      await tester.pump();

      // Verify the selection changed
      final updatedRadioGroup =
          tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>));
      expect(updatedRadioGroup.groupValue, equals(1));

      // Verify the dialog content is still visible
      expect(find.text('Test Selection'), findsOneWidget);
      expect(find.text('First - 200'), findsOneWidget);
      expect(find.text('Second - 201'), findsOneWidget);
    });
  });
}
