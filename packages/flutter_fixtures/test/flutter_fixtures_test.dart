import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_dio/flutter_fixtures_dio.dart';
import 'package:flutter_fixtures_ui/flutter_fixtures_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flutter Fixtures Meta-Package', () {
    test('exports all necessary components', () {
      // Core components
      expect(DataSelectorType.random(), isA<Random>());
      expect(DataSelectorType.defaultValue(), isA<Default>());
      expect(DataSelectorType.pick(), isA<Pick>());
      
      // Verify that the Fixture mixin is available
      expect(FixtureSelector, isNotNull);
      
      // Verify that the FixtureCollection classes are available
      expect(FixtureCollection, isNotNull);
      expect(FixtureDocument, isNotNull);
      
      // Verify that the Dio implementation is exported
      expect(DioDataQuery, isNotNull);
      expect(FixturesInterceptor, isNotNull);
      
      // Verify that the UI components are exported
      expect(FixturesDialogView, isNotNull);
    });
  });
}
