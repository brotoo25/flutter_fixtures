import 'package:flutter_fixtures_core/src/fixture_document.dart';

import 'data_selector_delay.dart';
import 'data_selector_type.dart';
import 'data_selector_view.dart';
import 'fixture_collection.dart';

/// Abstract interface for data queries
///
/// This interface defines the contract for classes that can query data sources
/// for fixture data. Implementations should handle the specifics of how to
/// query different data sources (e.g., HTTP, database, etc.)
abstract class DataQuery<Input, Output> {
  /// Find fixture data for the given input
  ///
  /// This method should search for fixture data that matches the input
  /// and return it in the specified output format.
  Future<Output?> find(Input input);

  /// Parse the raw output into a FixtureCollection
  ///
  /// This method should convert the raw output from the data source
  /// into a structured FixtureCollection that can be used by the library.
  Future<FixtureCollection?> parse(Output source);

  /// Get the actual data for a fixture document
  ///
  /// This method should retrieve the actual data for a fixture document,
  /// either from the document itself or from an external source.
  Future<Output?> data(FixtureDocument document);

  /// Select a fixture document from a collection based on the selector type
  ///
  /// This method uses the provided selector type to choose a fixture document
  /// from the collection, potentially using the view for user selection.
  ///
  /// The optional [delay] parameter allows simulating response delays.
  /// Defaults to [DataSelectorDelay.instant] (no delay).
  Future<FixtureDocument?> select(
    FixtureCollection fixture,
    DataSelectorView? view,
    DataSelectorType selector, {
    DataSelectorDelay delay = DataSelectorDelay.instant,
  });
}
