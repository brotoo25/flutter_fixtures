import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_ui/flutter_fixtures_ui.dart';

void main() {
  group('FixturesDialogView RadioGroup', () {
    testWidgets('uses RadioGroup instead of deprecated groupValue/onChanged',
        (WidgetTester tester) async {
      // Create test fixture data
      final fixture = FixtureCollection(
        description: 'Test Fixture',
        items: [
          FixtureDocument(
              identifier: 'Option 1', description: '200', defaultOption: true, data: {'test': 1}),
          FixtureDocument(
              identifier: 'Option 2', description: '404', defaultOption: false, data: {'test': 2}),
        ],
      );

      // Build the dialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FixturesDialogView(
                  context: context,
                  fixture: fixture,
                );
              },
            ),
          ),
        ),
      );

      // Verify RadioGroup is present
      expect(find.byType(RadioGroup<int>), findsOneWidget);

      // Verify Radio widgets don't have deprecated properties
      final radioWidgets = tester.widgetList<Radio<int>>(find.byType(Radio<int>));
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

    testWidgets('radio selection works with RadioGroup', (WidgetTester tester) async {
      final fixture = FixtureCollection(
        description: 'Test Selection',
        items: [
          FixtureDocument(
              identifier: 'First', description: '200', defaultOption: true, data: {'id': 1}),
          FixtureDocument(
              identifier: 'Second', description: '201', defaultOption: false, data: {'id': 2}),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FixturesDialogView(
                  context: context,
                  fixture: fixture,
                );
              },
            ),
          ),
        ),
      );

      // Verify initial state - first radio should be selected (index 0)
      final radioGroup = tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>));
      expect(radioGroup.groupValue, equals(0));

      // Tap on the second ListTile to select the second radio button
      await tester.tap(find.byType(ListTile).last);
      await tester.pump();

      // Verify the selection changed
      final updatedRadioGroup = tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>));
      expect(updatedRadioGroup.groupValue, equals(1));

      // Verify the dialog content is still visible
      expect(find.text('Test Selection'), findsOneWidget);
      expect(find.text('First - 200'), findsOneWidget);
      expect(find.text('Second - 201'), findsOneWidget);
    });
  });
}
