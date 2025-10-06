import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

void main() {
  group('DataSelectorDelay', () {
    group('predefined delays', () {
      test('instant has 0ms delay', () {
        expect(DataSelectorDelay.instant.milliseconds, equals(0));
        expect(DataSelectorDelay.instant.duration, equals(Duration.zero));
      });

      test('fast has 100ms delay', () {
        expect(DataSelectorDelay.fast.milliseconds, equals(100));
        expect(
          DataSelectorDelay.fast.duration,
          equals(const Duration(milliseconds: 100)),
        );
      });

      test('moderate has 500ms delay', () {
        expect(DataSelectorDelay.moderate.milliseconds, equals(500));
        expect(
          DataSelectorDelay.moderate.duration,
          equals(const Duration(milliseconds: 500)),
        );
      });

      test('slow has 2000ms delay', () {
        expect(DataSelectorDelay.slow.milliseconds, equals(2000));
        expect(
          DataSelectorDelay.slow.duration,
          equals(const Duration(milliseconds: 2000)),
        );
      });
    });

    group('custom delay', () {
      test('creates delay with specified milliseconds', () {
        final delay = DataSelectorDelay.custom(250);
        expect(delay.milliseconds, equals(250));
        expect(delay.duration, equals(const Duration(milliseconds: 250)));
      });

      test('throws ArgumentError for negative milliseconds', () {
        expect(
          () => DataSelectorDelay.custom(-1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('allows zero milliseconds', () {
        final delay = DataSelectorDelay.custom(0);
        expect(delay.milliseconds, equals(0));
      });
    });

    group('apply', () {
      test('instant delay completes immediately', () async {
        final stopwatch = Stopwatch()..start();
        await DataSelectorDelay.instant.apply();
        stopwatch.stop();

        // Should complete in less than 10ms
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });

      test('fast delay takes approximately 100ms', () async {
        final stopwatch = Stopwatch()..start();
        await DataSelectorDelay.fast.apply();
        stopwatch.stop();

        // Should be at least 100ms but less than 150ms (with some tolerance)
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(100));
        expect(stopwatch.elapsedMilliseconds, lessThan(150));
      });

      test('custom delay works correctly', () async {
        final delay = DataSelectorDelay.custom(50);
        final stopwatch = Stopwatch()..start();
        await delay.apply();
        stopwatch.stop();

        // Should be at least 50ms but less than 100ms (with some tolerance)
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(50));
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('equality', () {
      test('same delays are equal', () {
        expect(DataSelectorDelay.instant, equals(DataSelectorDelay.instant));
        expect(DataSelectorDelay.fast, equals(DataSelectorDelay.fast));
      });

      test('custom delays with same milliseconds are equal', () {
        final delay1 = DataSelectorDelay.custom(100);
        final delay2 = DataSelectorDelay.custom(100);
        expect(delay1, equals(delay2));
      });

      test('different delays are not equal', () {
        expect(
            DataSelectorDelay.instant, isNot(equals(DataSelectorDelay.fast)));

        final delay1 = DataSelectorDelay.custom(100);
        final delay2 = DataSelectorDelay.custom(200);
        expect(delay1, isNot(equals(delay2)));
      });
    });

    group('hashCode', () {
      test('same delays have same hashCode', () {
        expect(
          DataSelectorDelay.instant.hashCode,
          equals(DataSelectorDelay.instant.hashCode),
        );

        final delay1 = DataSelectorDelay.custom(100);
        final delay2 = DataSelectorDelay.custom(100);
        expect(delay1.hashCode, equals(delay2.hashCode));
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        expect(
          DataSelectorDelay.instant.toString(),
          equals('DataSelectorDelay(0ms)'),
        );
        expect(
          DataSelectorDelay.fast.toString(),
          equals('DataSelectorDelay(100ms)'),
        );
        expect(
          DataSelectorDelay.custom(250).toString(),
          equals('DataSelectorDelay(250ms)'),
        );
      });
    });
  });
}
