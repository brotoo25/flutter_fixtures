import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_dio/src/dio_interceptor.dart';
import 'package:flutter_fixtures_dio/src/dio_data_query.dart';

import 'fixtures_interceptor_test.mocks.dart';

// Generate mocks for the required classes
@GenerateMocks([
  DataQuery,
  DataSelectorView,
  RequestInterceptorHandler,
])
void main() {
  group('FixturesInterceptor', () {
    late MockDataQuery<RequestOptions, Map<String, dynamic>> mockDataQuery;
    late MockDataSelectorView mockDataSelectorView;
    late MockRequestInterceptorHandler mockHandler;
    late RequestOptions requestOptions;
    late FixturesInterceptor interceptor;

    setUp(() {
      mockDataQuery = MockDataQuery<RequestOptions, Map<String, dynamic>>();
      mockDataSelectorView = MockDataSelectorView();
      mockHandler = MockRequestInterceptorHandler();
      requestOptions = RequestOptions(path: '/users');
    });

    group('constructor', () {
      test('creates interceptor with required parameters', () {
        final interceptor = FixturesInterceptor(
          dataQuery: mockDataQuery,
          dataSelector: DataSelectorType.random(),
        );

        expect(interceptor.dataQuery, equals(mockDataQuery));
        expect(interceptor.dataSelectorView, isNull);
        expect(interceptor.dataSelector, isA<Random>());
      });

      test('creates interceptor with all parameters', () {
        final interceptor = FixturesInterceptor(
          dataQuery: mockDataQuery,
          dataSelectorView: mockDataSelectorView,
          dataSelector: DataSelectorType.pick(),
        );

        expect(interceptor.dataQuery, equals(mockDataQuery));
        expect(interceptor.dataSelectorView, equals(mockDataSelectorView));
        expect(interceptor.dataSelector, isA<Pick>());
      });
    });

    group('onRequest', () {
      setUp(() {
        interceptor = FixturesInterceptor(
          dataQuery: mockDataQuery,
          dataSelectorView: mockDataSelectorView,
          dataSelector: DataSelectorType.defaultValue(),
        );
      });

      group('successful flow', () {
        test('processes request successfully with inline data', () async {
          // Arrange
          final fixtureData = {'description': 'Test', 'values': []};
          final fixtureCollection = FixtureCollection(
            description: 'Test Collection',
            items: [
              FixtureDocument(
                identifier: 'success',
                description: '200 OK',
                defaultOption: true,
                data: {'result': 'success'},
              ),
            ],
          );
          final responseData = {'result': 'success'};

          when(mockDataQuery.find(requestOptions)).thenAnswer((_) async => fixtureData);
          when(mockDataQuery.parse(fixtureData)).thenAnswer((_) async => fixtureCollection);
          when(mockDataQuery.select(
            fixtureCollection,
            mockDataSelectorView,
            any,
          )).thenAnswer((_) async => fixtureCollection.items.first);
          when(mockDataQuery.data(fixtureCollection.items.first))
              .thenAnswer((_) async => responseData);

          // Act
          interceptor.onRequest(requestOptions, mockHandler);

          // Wait for async operations to complete
          await Future.delayed(Duration.zero);

          // Assert
          verify(mockDataQuery.find(requestOptions)).called(1);
          verify(mockDataQuery.parse(fixtureData)).called(1);
          verify(mockDataQuery.select(
            fixtureCollection,
            mockDataSelectorView,
            any,
          )).called(1);
          verify(mockDataQuery.data(fixtureCollection.items.first)).called(1);

          final capturedResponse =
              verify(mockHandler.resolve(captureAny)).captured.single as Response;
          expect(capturedResponse.data, equals(responseData));
          expect(capturedResponse.statusCode, equals(200));
          expect(capturedResponse.requestOptions, equals(requestOptions));
        });

        test('processes request successfully with file path header', () async {
          // Arrange
          final fixtureData = {'description': 'Test', 'values': []};
          final fixtureCollection = FixtureCollection(
            description: 'Test Collection',
            items: [
              FixtureDocument(
                identifier: 'success',
                description: '201 Created',
                defaultOption: true,
                dataPath: 'success_response.json',
              ),
            ],
          );
          final responseData = {'id': 123, 'name': 'Alice'};

          when(mockDataQuery.find(requestOptions)).thenAnswer((_) async => fixtureData);
          when(mockDataQuery.parse(fixtureData)).thenAnswer((_) async => fixtureCollection);
          when(mockDataQuery.select(any, any, any))
              .thenAnswer((_) async => fixtureCollection.items.first);
          when(mockDataQuery.data(fixtureCollection.items.first))
              .thenAnswer((_) async => responseData);

          // Act
          interceptor.onRequest(requestOptions, mockHandler);

          // Wait for async operations to complete
          await Future.delayed(Duration.zero);

          // Assert
          final capturedResponse =
              verify(mockHandler.resolve(captureAny)).captured.single as Response;
          expect(capturedResponse.data, equals(responseData));
          expect(capturedResponse.statusCode, equals(201));
          expect(
            capturedResponse.headers.value('x-fixture-file-path'),
            equals('success_response.json'),
          );
        });
      });

      group('error handling', () {
        test('rejects when no fixture found', () async {
          // Arrange
          when(mockDataQuery.find(requestOptions)).thenAnswer((_) async => null);

          // Act
          interceptor.onRequest(requestOptions, mockHandler);

          // Wait for async operations to complete
          await Future.delayed(Duration.zero);

          // Assert
          final capturedError =
              verify(mockHandler.reject(captureAny)).captured.single as DioException;
          expect(capturedError.error, equals('No fixture found for request.'));
          expect(capturedError.requestOptions, equals(requestOptions));
        });

        test('rejects when fixture collection is null', () async {
          // Arrange
          final fixtureData = {'description': 'Test', 'values': []};
          when(mockDataQuery.find(requestOptions)).thenAnswer((_) async => fixtureData);
          when(mockDataQuery.parse(fixtureData)).thenAnswer((_) async => null);

          // Act
          interceptor.onRequest(requestOptions, mockHandler);

          // Wait for async operations to complete
          await Future.delayed(Duration.zero);

          // Assert
          final capturedError =
              verify(mockHandler.reject(captureAny)).captured.single as DioException;
          expect(capturedError.error, equals('No fixture options found for request.'));
        });

        test('rejects when fixture collection is empty', () async {
          // Arrange
          final fixtureData = {'description': 'Test', 'values': []};
          final emptyCollection = FixtureCollection(
            description: 'Empty Collection',
            items: [],
          );
          when(mockDataQuery.find(requestOptions)).thenAnswer((_) async => fixtureData);
          when(mockDataQuery.parse(fixtureData)).thenAnswer((_) async => emptyCollection);

          // Act
          interceptor.onRequest(requestOptions, mockHandler);

          // Wait for async operations to complete
          await Future.delayed(Duration.zero);

          // Assert
          final capturedError =
              verify(mockHandler.reject(captureAny)).captured.single as DioException;
          expect(capturedError.error, equals('No fixture options found for request.'));
        });

        test('rejects when no document selected', () async {
          // Arrange
          final fixtureData = {'description': 'Test', 'values': []};
          final fixtureCollection = FixtureCollection(
            description: 'Test Collection',
            items: [
              FixtureDocument(
                identifier: 'success',
                description: '200 OK',
                defaultOption: true,
                data: {'result': 'success'},
              ),
            ],
          );

          when(mockDataQuery.find(requestOptions)).thenAnswer((_) async => fixtureData);
          when(mockDataQuery.parse(fixtureData)).thenAnswer((_) async => fixtureCollection);
          when(mockDataQuery.select(any, any, any)).thenAnswer((_) async => null);

          // Act
          interceptor.onRequest(requestOptions, mockHandler);

          // Wait for async operations to complete
          await Future.delayed(Duration.zero);

          // Assert
          final capturedError =
              verify(mockHandler.reject(captureAny)).captured.single as DioException;
          expect(capturedError.error, equals('No fixture selected for request.'));
        });

        test('rejects when exception occurs during processing', () async {
          // Arrange
          when(mockDataQuery.find(requestOptions)).thenThrow(Exception('Test exception'));

          // Act
          interceptor.onRequest(requestOptions, mockHandler);

          // Wait for async operations to complete
          await Future.delayed(Duration.zero);

          // Assert
          final capturedError =
              verify(mockHandler.reject(captureAny)).captured.single as DioException;
          expect(capturedError.error, contains('Error processing fixture:'));
          expect(capturedError.error, contains('Test exception'));
        });
      });

      group('edge cases', () {
        test('handles empty file path correctly', () async {
          // Arrange
          final fixtureData = {'description': 'Test', 'values': []};
          final fixtureCollection = FixtureCollection(
            description: 'Test Collection',
            items: [
              FixtureDocument(
                identifier: 'success',
                description: '200 OK',
                defaultOption: true,
                data: {'result': 'success'},
                dataPath: '', // Empty path
              ),
            ],
          );
          final responseData = {'result': 'success'};

          when(mockDataQuery.find(requestOptions)).thenAnswer((_) async => fixtureData);
          when(mockDataQuery.parse(fixtureData)).thenAnswer((_) async => fixtureCollection);
          when(mockDataQuery.select(any, any, any))
              .thenAnswer((_) async => fixtureCollection.items.first);
          when(mockDataQuery.data(fixtureCollection.items.first))
              .thenAnswer((_) async => responseData);

          // Act
          interceptor.onRequest(requestOptions, mockHandler);

          // Wait for async operations to complete
          await Future.delayed(Duration.zero);

          // Assert
          final capturedResponse =
              verify(mockHandler.resolve(captureAny)).captured.single as Response;
          expect(
            capturedResponse.headers.value('x-fixture-file-path'),
            isNull,
          );
        });

        test('handles status code parsing from description', () async {
          // Arrange
          final fixtureData = {'description': 'Test', 'values': []};
          final fixtureCollection = FixtureCollection(
            description: 'Test Collection',
            items: [
              FixtureDocument(
                identifier: 'not_found',
                description: '404 Not Found',
                defaultOption: true,
                data: {'error': 'Not found'},
              ),
            ],
          );
          final responseData = {'error': 'Not found'};

          when(mockDataQuery.find(requestOptions)).thenAnswer((_) async => fixtureData);
          when(mockDataQuery.parse(fixtureData)).thenAnswer((_) async => fixtureCollection);
          when(mockDataQuery.select(any, any, any))
              .thenAnswer((_) async => fixtureCollection.items.first);
          when(mockDataQuery.data(fixtureCollection.items.first))
              .thenAnswer((_) async => responseData);

          // Act
          interceptor.onRequest(requestOptions, mockHandler);

          // Wait for async operations to complete
          await Future.delayed(Duration.zero);

          // Assert
          final capturedResponse =
              verify(mockHandler.resolve(captureAny)).captured.single as Response;
          expect(capturedResponse.statusCode, equals(404));
        });
      });
    });

    group('integration', () {
      test('can be instantiated with DioDataQuery', () {
        // This test verifies that the interceptor can be created with real implementations
        // without mocking, ensuring the interfaces are compatible
        final interceptor = FixturesInterceptor(
          dataQuery: DioDataQuery(),
          dataSelector: DataSelectorType.random(),
        );

        expect(interceptor, isNotNull);
        expect(interceptor.dataQuery, isA<DioDataQuery>());
        expect(interceptor.dataSelector, isA<Random>());
        expect(interceptor.dataSelectorView, isNull);
      });
    });
  });
}
