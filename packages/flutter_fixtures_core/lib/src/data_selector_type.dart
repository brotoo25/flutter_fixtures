/// Defines the strategy for selecting a fixture from a collection
/// 
/// This sealed class provides different strategies for selecting a fixture:
/// - Pick: Let the user pick the fixture through a UI
/// - Default: Use the fixture marked as default
/// - Random: Select a random fixture
sealed class DataSelectorType {
  const DataSelectorType();

  /// Create a selector that lets the user pick the fixture
  factory DataSelectorType.pick() = Pick;
  
  /// Create a selector that uses the default fixture
  factory DataSelectorType.defaultValue() = Default;
  
  /// Create a selector that picks a random fixture
  factory DataSelectorType.random() = Random;
}

/// Selector that lets the user pick the fixture through a UI
class Pick extends DataSelectorType {}

/// Selector that uses the fixture marked as default
class Default extends DataSelectorType {}

/// Selector that picks a random fixture
class Random extends DataSelectorType {}
