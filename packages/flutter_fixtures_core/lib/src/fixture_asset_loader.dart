import 'package:flutter/services.dart' show rootBundle;

/// Seam for reading fixture files.
///
/// [FixtureSource] loads fixture content through this interface, so tests
/// (and non-bundle setups) can substitute an in-memory implementation
/// instead of requiring a Flutter asset bundle.
abstract class FixtureAssetLoader {
  /// Returns the string content of the asset at [path].
  ///
  /// Must throw if the asset does not exist.
  Future<String> load(String path);
}

/// The production adapter: loads fixture files from the root asset bundle.
class BundleAssetLoader implements FixtureAssetLoader {
  const BundleAssetLoader();

  @override
  Future<String> load(String path) => rootBundle.loadString(path);
}
