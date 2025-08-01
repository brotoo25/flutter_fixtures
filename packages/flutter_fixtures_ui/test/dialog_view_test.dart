import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_ui/flutter_fixtures_ui.dart';

void main() {
  group('FixturesDialogView', () {
    testWidgets('renders dialog with fixture options', (tester) async {
      // Create a fixture collection
      final fixture = FixtureCollection(
        description: 'Test Collection',
        items: [
          FixtureDocument(
              identifier: 'Success',
              description: '200',
              defaultOption: true,
              data: {'result': 'success'}),
          FixtureDocument(
              identifier: 'Error',
              description: '400',
              defaultOption: false,
              data: {'error': 'Bad request'}),
        ],
      );

      // Build the dialog
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => FixturesDialogView(
              context: context,
              fixture: fixture,
            ),
          ),
        ),
      );

      // Verify the dialog is displayed
      expect(find.text('Test Collection'), findsOneWidget);
      expect(find.text('Success - 200'), findsOneWidget);
      expect(find.text('Error - 400'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('returns selected fixture on tap', (tester) async {
      // Create a fixture collection
      final fixture = FixtureCollection(
        description: 'Test Collection',
        items: [
          FixtureDocument(
              identifier: 'Success',
              description: '200',
              defaultOption: true,
              data: {'result': 'success'}),
          FixtureDocument(
              identifier: 'Error',
              description: '400',
              defaultOption: false,
              data: {'error': 'Bad request'}),
        ],
      );

      // Create a key to access the navigator
      final navigatorKey = GlobalKey<NavigatorState>();

      // Build a test app with the dialog
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await FixturesDialogView(
                      context: context,
                    ).pick(fixture);
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap the button to show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify the dialog is displayed
      expect(find.text('Test Collection'), findsOneWidget);

      // Tap the second option
      await tester.tap(find.text('Error - 400'));
      await tester.pumpAndSettle();

      // Tap the select button
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      // Verify the dialog is dismissed
      expect(find.text('Test Collection'), findsNothing);
    });
  });
}
