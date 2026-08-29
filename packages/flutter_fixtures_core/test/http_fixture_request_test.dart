import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HttpFixtureRequest.fromUri', () {
    test('drops scheme and host from an absolute URL', () {
      final request = HttpFixtureRequest.fromUri(
          'GET', Uri.parse('https://api.test/users'));
      expect(request.path, '/users');
      expect(request.queryParameters, isEmpty);
    });

    test('moves the URL query string into queryParameters', () {
      final request = HttpFixtureRequest.fromUri(
          'GET', Uri.parse('https://api.test/search?q=test&page=2'));
      expect(request.path, '/search');
      expect(request.queryParameters, {'q': 'test', 'page': '2'});
    });

    test('keeps repeated keys as a list', () {
      final request =
          HttpFixtureRequest.fromUri('GET', Uri.parse('/tags?t=a&t=b'));
      expect(request.queryParameters, {
        't': ['a', 'b']
      });
    });

    test('uppercases the method and defaults an empty path to /', () {
      final request =
          HttpFixtureRequest.fromUri('get', Uri.parse('https://api.test'));
      expect(request.method, 'GET');
      expect(request.path, '/');
    });

    test('a relative path stays as-is', () {
      final request = HttpFixtureRequest.fromUri('GET', Uri.parse('/users'));
      expect(request.path, '/users');
    });
  });

  group('canonicalTarget', () {
    test('renders path plus sorted, escaped query pairs', () {
      final request = HttpFixtureRequest.fromUri(
          'GET', Uri.parse('/search?q=hello world&page=2'));
      expect(request.canonicalTarget, '/search?page=2&q=hello+world');
    });

    test('is independent of query parameter order', () {
      final ab = HttpFixtureRequest.fromUri('GET', Uri.parse('/u?a=1&b=2'));
      final ba = HttpFixtureRequest.fromUri('GET', Uri.parse('/u?b=2&a=1'));
      expect(ab.canonicalTarget, ba.canonicalTarget);
    });

    test('keeps distinct requests distinct through escaping', () {
      final repeated =
          HttpFixtureRequest.fromUri('GET', Uri.parse('/u?a=1&a=2'));
      final literal =
          HttpFixtureRequest.fromUri('GET', Uri.parse('/u?a=1%2C2'));
      expect(repeated.canonicalTarget, isNot(literal.canonicalTarget));
    });

    test('a query-less request is just the path', () {
      final request = HttpFixtureRequest.fromUri(
          'GET', Uri.parse('https://api.test/users'));
      expect(request.canonicalTarget, '/users');
    });
  });

  group('fromUri feeding HttpFileFixtureSource', () {
    test('an absolute URL produces the plain candidate file name', () async {
      final loader = _RecordingLoader();
      final source = HttpFileFixtureSource(assetLoader: loader);

      await source.resolve(HttpFixtureRequest.fromUri(
          'GET', Uri.parse('https://api.test/users?a=1')));

      // Before fromUri owned normalization, this candidate came out as
      // "GET_https:__api.test_users?a=1.json".
      expect(loader.requestedPaths.first, 'assets/fixtures/GET_users.json');
      expect(
          loader.requestedPaths, contains('assets/fixtures/GET_users_1.json'));
    });
  });
}

class _RecordingLoader implements FixtureAssetLoader {
  final List<String> requestedPaths = [];

  @override
  Future<String> load(String path) async {
    requestedPaths.add(path);
    throw StateError('Asset not found: $path');
  }
}
