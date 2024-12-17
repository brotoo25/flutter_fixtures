sealed class DataSelectorType {
  const DataSelectorType();

  factory DataSelectorType.pick() = Pick;
  factory DataSelectorType.defaultValue() = Default;
  factory DataSelectorType.random() = Random;
}

class Pick extends DataSelectorType {}

class Default extends DataSelectorType {}

class Random extends DataSelectorType {}
