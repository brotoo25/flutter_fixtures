import 'fixture_document.dart';

/// The outcome of a user-driven fixture selection.
///
/// Returned by [DataSelectorView.pick] implementations. A `null` result from
/// `pick` means the user cancelled; a [FixtureChoice] carries the chosen
/// document plus whether the choice should be remembered for subsequent
/// selections of the same collection.
class FixtureChoice {
  /// The document the user chose.
  final FixtureDocument document;

  /// Whether this choice should be remembered for future selections.
  final bool remember;

  const FixtureChoice({required this.document, this.remember = false});
}
