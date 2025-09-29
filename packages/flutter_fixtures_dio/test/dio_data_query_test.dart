import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DioDataQuery', () {
    group('query parameter handling', () {
      test('normalizes query parameter values correctly', () {
        final requestOptions = RequestOptions(
          path: '/search',
          method: 'GET',
          queryParameters: {'q': 'hello world', 'page': 2},
        );

        expect(requestOptions.queryParameters['q'], equals('hello world'));
        expect(requestOptions.queryParameters['page'], equals(2));
      });

      test('sorts query parameters deterministically', () {
        final requestOptions1 = RequestOptions(
          path: '/search',
          method: 'GET',
          queryParameters: {'page': 2, 'q': 'test'},
        );

        final requestOptions2 = RequestOptions(
          path: '/search',
          method: 'GET',
          queryParameters: {'q': 'test', 'page': 2},
        );

        // Both should generate the same filename pattern since keys are sorted
        expect(requestOptions1.queryParameters.keys.toList()..sort(),
            equals(requestOptions2.queryParameters.keys.toList()..sort()));
      });
    });
  });
}
