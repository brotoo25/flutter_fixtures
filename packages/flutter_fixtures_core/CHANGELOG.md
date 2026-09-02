# Changelog

## 0.3.0

* New thin record-and-replay seam: `TrafficRecorder` (`decide` + `record`)
  with its contract types — `RecordedRequest`, `RecordedInteraction`,
  sealed `ReplayDecision` (`Replayed` / `ForwardToSource` /
  `RejectRequest`), and `ReplayMissBehavior`. Transport packages implement
  capture/replay against this seam; the engine ships separately in
  `flutter_fixtures_recorder`. Both calls take builder functions invoked
  only when the recorder's mode needs them, so idle traffic costs nothing.
* `HttpFixtureRequest.canonicalTarget`: the escaped, sorted rendering of a
  request's identity, used as the record & replay match key — identical
  whichever HTTP client built the request.

* `HttpFixtureRequest.fromUri` is the canonical constructor: it owns HTTP
  request normalization (scheme and host dropped, the URL's query string
  merged into `queryParameters`), so sources see one shape and never
  compensate. Fixes fixture-file candidates for absolute request URLs,
  which previously came out as `GET_https:__host_path.json`.
* New `HttpFixtureSources`, an ordered composite that is itself an
  `HttpFixtureSource`: first source to resolve wins and alone provides the
  selected document's payload. Source precedence now lives (and is tested)
  in core instead of each HTTP adapter.
* `OpenApiFixtureSource` no longer strips schemes or query strings from
  request paths — that compensation moved behind `fromUri`; it keeps only
  the OpenAPI-specific `servers` base-path handling.

* New `FixtureSelector.serve` runs the whole fixture pipeline — find a
  collection, select a document, load its payload — and reports a
  `FixtureOutcome` (`FixtureNotFound` / `FixtureEmpty` / `FixtureCancelled`
  / `FixtureServed`). Adapters map outcomes to their own domain and error
  policy instead of each re-implementing the choreography.
* **BREAKING**: the `DataQuery` interface was removed. HTTP providers
  implement `HttpFixtureSource`; sqflite providers implement
  `SqfliteFixtureSource` (in `flutter_fixtures_sqflite`); custom domains
  define their own source seam and drive it with `FixtureSelector.serve`.

* **BREAKING**: `FixtureSelectionMemory` was removed; remembered choices
  live inside `FixtureSelector`, scoped to the mixing-in instance and keyed
  by the same collection signature as pick deduplication. Clear them with
  `clearRememberedSelectionFor` / `clearRememberedSelections` on the
  selector. The `@visibleForTesting FixtureSelector.clearPendingPicks` is
  gone with the static state that required it.

* New `HttpFixtureSource` seam: resolves an `HttpFixtureRequest` (method,
  path, query parameters) to a `FixtureCollection`. HTTP adapters consult an
  ordered list of sources; the first that resolves wins. Sources build model
  objects directly, so the fixture wire format lives only in
  `FixtureCollection.fromJson` / `FixtureDocument.fromJson` and document
  invariants are enforced at construction.
* New `HttpFileFixtureSource` implements the seam over fixture files,
  owning the HTTP file naming convention (moved from `DioDataQuery`).
* New `OpenApiFixtureSource` implements the seam over an OpenAPI 3.x JSON
  document: operation docs name the collection, and each response's status,
  description, and payload examples (or a schema-generated sample) become
  selectable documents.

## 0.2.0

* **BREAKING**: `DataSelectorView.pick` now returns `FixtureChoice?` (the chosen document plus a remember flag); `null` means the user cancelled.
* **BREAKING**: `DataSelectorType` is now a plain enum (`pick`, `defaultValue`, `random`) instead of a sealed class hierarchy.
* **BREAKING**: `FixtureDocument` rejects documents declaring both `data` and `dataPath`; invalid fixtures now fail at parse time.
* `FixtureSelector` owns the full selection flow: it writes selection memory, deduplicates concurrent picks for the same collection, and propagates cancel as `null`.
* New `FixtureSource` concentrates fixture-file IO (candidate resolution, JSON decoding, payload loading) behind the new `FixtureAssetLoader` seam.
* New `FixtureDocument.statusCode` exposes the leading 3-digit code of the description as a typed field.
* New `FixtureCollection.fromJson` / `FixtureDocument.fromJson` own the fixture wire format.

## 0.1.3

* Support JSON arrays as response data in `DataQuery`.

## 0.1.2 Response Delay

  * Add `DataSelectorDelay` class to simulate response delays.
  * Add delay to `FixtureSelector.select` method.

## 0.1.1 Selection Memory

* Add in-memory selection memory to remember user choices for fixture collections.
* Add `FixtureSelectionMemory` class to manage remembered selections.
* Auto-select single option when using Pick selector.

## 0.1.0 - First Minor Release

* Updated all packages to version 0.1.0
* Renamed `Fixture` mixin to `FixtureSelector` for better clarity
* Improved documentation across all packages
* Added comprehensive CONTRIBUTING.md guide
* Added MIT License
* Updated GitHub repository references to brotoo25/flutter_fixtures

## 0.0.1 - Initial Release

* Initial release of Flutter Fixtures
* Restructured as a workspace with multiple packages:
  * flutter_fixtures_core: Core interfaces and domain models
  * flutter_fixtures_dio: Dio implementation
  * flutter_fixtures_ui: UI components
  * flutter_fixtures: Meta-package that depends on all the above
* Support for Dio HTTP client
* Three fixture selection modes: Random, Default, and Pick
* Dialog-based UI for user selection
* Example app demonstrating basic and advanced usage
