import 'dart:convert';

import 'fixture_asset_loader.dart';
import 'fixture_collection.dart';
import 'fixture_document.dart';

/// The seam for providing fixtures for one kind of request.
///
/// A source turns a domain request into a [FixtureCollection] — or `null`
/// when it has none for that request — and materializes a document's
/// payload. `TRequest` is the domain's request model: an
/// `HttpFixtureRequest` for HTTP, a `SqfliteQuery` for sqflite, anything
/// else for a custom domain. Sources build model objects; the wire format
/// belongs to [FixtureCollection] and [FixtureDocument] alone.
///
/// Built-in adapters: [FixtureFileSource] (fixture files, parameterized by
/// the domain's naming convention), `OpenApiFixtureSource` (HTTP fixtures
/// derived from an OpenAPI document), and the composite `FixtureSources`
/// (ordered precedence over several sources).
abstract class FixtureSource<TRequest> {
  /// Returns the collection this source has for [request], or `null` if
  /// it has none — the pipeline then consults the next source, if any.
  Future<FixtureCollection?> resolve(TRequest request);

  /// Materializes a document's payload: inline data, or a loaded and
  /// decoded external file.
  ///
  /// Only documents returned by this source's [resolve] are valid here.
  Future<Object?> data(FixtureDocument document);
}

/// Names the fixture-file candidates for one request, most specific
/// first. The file source tries them in order and serves the first that
/// exists.
typedef FixtureCandidates<TRequest> = List<String> Function(TRequest request);

/// The file-backed [FixtureSource]: fixture files under [mockFolder], read
/// through a [FixtureAssetLoader].
///
/// This module owns fixture-file IO — candidate lookup, JSON decoding, and
/// document payload loading — for every domain. A domain contributes only
/// its naming convention through [candidates] (`HttpFileFixtureSource`
/// and `SqfliteFileFixtureSource` are exactly that), so the rules below
/// hold everywhere at once:
///
/// - a missing candidate is skipped and the next one tried;
/// - a matched candidate with malformed JSON fails loudly (a
///   [FormatException]) rather than silently falling through;
/// - external payloads (`dataPath`) resolve relative to [mockFolder].
class FixtureFileSource<TRequest> implements FixtureSource<TRequest> {
  /// The folder fixture files live in, relative to the asset root.
  final String mockFolder;

  /// How fixture file content is read.
  final FixtureAssetLoader assetLoader;

  /// The domain's naming convention.
  final FixtureCandidates<TRequest> candidates;

  const FixtureFileSource({
    required this.mockFolder,
    required this.candidates,
    this.assetLoader = const BundleAssetLoader(),
  });

  @override
  Future<FixtureCollection?> resolve(TRequest request) async {
    for (final name in candidates(request)) {
      final String content;
      try {
        content = await assetLoader.load('$mockFolder/$name');
      } catch (_) {
        // Asset not present — try the next candidate.
        continue;
      }
      return FixtureCollection.fromJson(
        (jsonDecode(content) as Map).cast<String, dynamic>(),
      );
    }
    return null;
  }

  @override
  Future<Object?> data(FixtureDocument document) async {
    if (document.data != null) {
      return document.data;
    }
    final path = document.dataPath;
    if (path == null) {
      return null;
    }
    final content = await assetLoader.load('$mockFolder/$path');
    return jsonDecode(content);
  }
}
