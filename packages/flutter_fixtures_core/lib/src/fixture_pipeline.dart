import 'fixture_document.dart';

/// The outcome of serving one fixture request through
/// `FixtureSelector.serve`.
///
/// Adapters map outcomes to their own domain and error policy: the Dio
/// interceptor rejects each miss with a distinct message, the sqflite
/// adapter substitutes its operation's default result.
sealed class FixtureOutcome {
  const FixtureOutcome();
}

/// No fixture collection resolved for the request.
class FixtureNotFound extends FixtureOutcome {
  const FixtureNotFound();
}

/// A collection resolved but offers no documents.
class FixtureEmpty extends FixtureOutcome {
  const FixtureEmpty();
}

/// The user cancelled an interactive pick.
class FixtureCancelled extends FixtureOutcome {
  const FixtureCancelled();
}

/// A document was selected and its payload loaded.
class FixtureServed extends FixtureOutcome {
  const FixtureServed({required this.document, required this.payload});

  /// The selected document.
  final FixtureDocument document;

  /// The document's materialized payload.
  final Object? payload;
}
