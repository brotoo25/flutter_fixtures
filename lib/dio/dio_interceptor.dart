import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_fixtures/dio/dio_fixture.dart';
import 'package:flutter_fixtures/data_selector_type.dart';

class FixturesInterceptor extends Interceptor {
  final DioFixture fixture;

  FixturesInterceptor(this.fixture);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final fixtureModel = await fixture.find(options);
    if (fixtureModel == null) {
      return handler.reject(
        DioException(
          requestOptions: options,
          error: 'No fixture found for request.',
        ),
      );
    }

    final parsed = await fixture.parse(fixtureModel);
    final description = parsed.description;
    final values = parsed.items;
    // final fixture = await dataQuery.map(options);

    if (values.isNotEmpty) {
      final selectedOption = switch (dataSelector) {
        Pick() => await dataSelectorView.pick(fixture),
        Default() =>
          fixture.items.firstWhere((option) => option.defaultOption ?? false),
        Random() => fixture.items[math.Random().nextInt(fixture.items.length)],
      };

      if (selectedOption != null) {
        final response = Response(
          requestOptions: options,
          data: selectedOption.data,
          statusCode: int.parse(selectedOption.description.substring(0, 3)),
        );
        return handler.resolve(response);
      }
    }

    return handler.reject(
      DioException(
        requestOptions: options,
        error: 'No fixture found for request.',
      ),
    );
  }
}
