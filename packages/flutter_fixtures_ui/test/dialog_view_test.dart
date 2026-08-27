import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_ui/flutter_fixtures_ui.dart';

FixtureCollection _fixture() => FixtureCollection(
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

void main() {
  group('FixturesDialogView', () {
    testWidgets('renders dialog with fixture options', (tester) async {
      final fixture = _fixture();

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

    testWidgets('returns the selected fixture as a FixtureChoice',
        (tester) async {
      final fixture = _fixture();
      FixtureChoice? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await FixturesDialogView(
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

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Test Collection'), findsOneWidget);

      await tester.tap(find.text('Error - 400'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('Test Collection'), findsNothing);
      expect(result, isNotNull);
      expect(result!.document.identifier, equals('Error'));
      expect(result!.remember, isFalse);
    });

    testWidgets('reports the Remember checkbox in the choice', (tester) async {
      final fixture = _fixture();
      FixtureChoice? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await FixturesDialogView(
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

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.document.identifier, equals('Success'));
      expect(result!.remember, isTrue);
    });

    testWidgets('returns null when the user cancels', (tester) async {
      final fixture = _fixture();
      var picked = false;
      FixtureChoice? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await FixturesDialogView(
                      context: context,
                    ).pick(fixture);
                    picked = true;
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(picked, isTrue);
      expect(result, isNull);
    });
  });
}
