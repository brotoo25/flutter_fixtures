# Domain Glossary

The vocabulary of the `flutter_fixtures` workspace. Code, docs, and reviews
should use these terms exactly.

## Fixture Collection

The set of possible responses for one request, parsed from a fixture file.
Carries a description and a list of **Fixture Documents**. Wire format:
`{"description": ..., "values": [...]}` — note the JSON key is `values`,
the Dart field is `items`.

## Fixture Document

One possible response inside a collection: an identifier, a human-readable
description, an optional default marker, and a payload. The payload is
either inline (`data`) or an external file reference (`dataPath`) — never
both; the constructor enforces this. For HTTP fixtures the description
conventionally starts with a 3-digit status code, exposed as the typed
`statusCode` field.

## Data Query

The seam a data source plugs in through (`DataQuery<Input, Output>`):
`find` maps a domain request to fixture content, `parse` produces a
Fixture Collection, `select` chooses a document, `data` yields its payload.
Adapters: `DioDataQuery` (HTTP via Dio), `SqfliteDataQuery` (sqflite).

## Fixture Source

The core module owning fixture-file IO (`FixtureSource`): tries candidate
file names in order, decodes JSON, loads document payloads. Data Query
adapters only build candidate names for their domain and delegate here.
A missing candidate is skipped; a matched candidate with malformed JSON
fails loudly.

## Asset Loader

The IO seam under Fixture Source (`FixtureAssetLoader`): how fixture file
content is read. `BundleAssetLoader` (root asset bundle) in production;
in-memory fakes in tests.

## Selection Flow

The behavior behind `FixtureSelector.select`, owned entirely by core:
strategy dispatch (`DataSelectorType`: pick / defaultValue / random),
auto-selecting single-option collections, remembered choices (read and
write), single-flight deduplication of concurrent interactive picks, and
response delays (`DataSelectorDelay`).

## Selector View

The UI seam (`DataSelectorView.pick`). A view only presents a collection's
options and reports the user's answer as a **Fixture Choice** — it does not
remember, deduplicate, or delay. `FixturesDialogView` (flutter_fixtures_ui)
is the built-in adapter; the dialog widget behind it is private.

## Fixture Choice

The outcome of a user-driven selection (`FixtureChoice`): the chosen
document plus whether to remember it. `null` from a view means the user
cancelled, and cancel propagates out of the selection flow as `null` —
it is never silently converted into a selection.

## Selection Memory

The runtime-only store of remembered choices (`FixtureSelectionMemory`),
keyed by collection description. Written by the selection flow when a
Fixture Choice asks to be remembered; cleared via `clearFor`/`clearAll`.

## Database Adapter

The sqflite-shaped consumer seam (`DatabaseAdapter`), mirroring sqflite's
`Database` API so repositories swap between `RealDatabaseAdapter`
(production) and `FixtureDatabaseAdapter` (fixtures) with no code changes.
