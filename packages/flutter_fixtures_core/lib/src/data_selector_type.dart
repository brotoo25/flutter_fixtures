/// Defines the strategy for selecting a fixture from a collection
enum DataSelectorType {
  /// Let the user pick the fixture through a UI
  pick,

  /// Use the fixture marked as default
  defaultValue,

  /// Select a random fixture
  random,
}
