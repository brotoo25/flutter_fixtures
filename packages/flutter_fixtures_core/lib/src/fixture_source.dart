import 'dart:convert';

import 'fixture_asset_loader.dart';
import 'fixture_document.dart';

/// Loads fixture content from a mock folder.
///
/// This is the single home of fixture-file IO: trying candidate file names
/// in order, decoding JSON, and resolving a document's payload (inline data
/// or an external file). DataQuery adapters only build candidate names for
/// their domain (HTTP requests, database queries) and delegate here.
///
/// A candidate that does not exist is skipped; a candidate that exists but
/// contains malformed JSON throws a [FormatException] so a broken fixture
/// reports as broken instead of as "no fixture found".
class FixtureSource {
  /// The folder fixture files live in. Candidate names and document
  /// dataPaths are resolved relative to it.
  final String mockFolder;

  /// The seam used to read fixture files.
  final FixtureAssetLoader assetLoader;

  const FixtureSource({
    required this.mockFolder,
    this.assetLoader = const BundleAssetLoader(),
  });

  /// Returns the decoded content of the first candidate that exists.
  ///
  /// [candidateNames] are file names relative to [mockFolder], tried in
  /// order. Returns `null` when none exist.
  Future<Map<String, dynamic>?> resolve(List<String> candidateNames) async {
    for (final name in candidateNames) {
      final String content;
      try {
        content = await assetLoader.load('$mockFolder/$name');
      } catch (_) {
        // Asset not present — try the next candidate.
        continue;
      }
      return (jsonDecode(content) as Map).cast<String, dynamic>();
    }
    return null;
  }

  /// Returns a document's payload: inline [FixtureDocument.data] as-is, or
  /// the decoded content of [FixtureDocument.dataPath]. Returns `null` when
  /// the document carries neither.
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
