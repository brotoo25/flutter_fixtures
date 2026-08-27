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

/// Pumps a host app and returns a function that opens the dialog via pick.
Future<Future<FixtureChoice?> Function()> _pumpHost(
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
  final view = FixturesDialogView(
    contextProvider: () => navigatorKey.currentContext!,
  );
  return () => view.pick(fixture);
}

void main() {
  group('FixturesDialogView', () {
    testWidgets('renders dialog with fixture options', (tester) async {
      final open = await _pumpHost(tester, _fixture());

      open();
      await tester.pumpAndSettle();

      expect(find.text('Test Collection'), findsOneWidget);
      expect(find.text('Success - 200'), findsOneWidget);
      expect(find.text('Error - 400'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('returns the selected fixture as a FixtureChoice',
        (tester) async {
      final open = await _pumpHost(tester, _fixture());

      final pending = open();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Error - 400'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('Test Collection'), findsNothing);
      final result = await pending;
      expect(result, isNotNull);
      expect(result!.document.identifier, equals('Error'));
      expect(result.remember, isFalse);
    });

    testWidgets('reports the Remember checkbox in the choice', (tester) async {
      final open = await _pumpHost(tester, _fixture());

      final pending = open();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      final result = await pending;
      expect(result, isNotNull);
      expect(result!.document.identifier, equals('Success'));
      expect(result.remember, isTrue);
    });

    testWidgets('returns null when the user cancels', (tester) async {
      final open = await _pumpHost(tester, _fixture());

      final pending = open();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await pending, isNull);
    });

    testWidgets('FixturesDialogView.of binds to a fixed context',
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
                    result = await FixturesDialogView.of(context).pick(fixture);
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

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.document.identifier, equals('Success'));
    });
  });
}
