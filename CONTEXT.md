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

## Fixture Outcome

The result of serving one fixture request through the Selection Flow's
`serve` pipeline (`FixtureOutcome`): not found, empty, cancelled, or
served (the selected Fixture Document plus its payload). Adapters map
outcomes to their own domain and error policy — the choreography itself
lives in one place.

## Sqflite Fixture Source

The seam for providing sqflite fixtures (`SqfliteFixtureSource`): `find`
takes a database query and returns a Fixture Collection, or `null` when
the source has none; `data` materializes a document's payload.
`SqfliteDataQuery` is the built-in file-backed adapter.

## Fixture Source

The core module owning fixture-file IO (`FixtureSource`): tries candidate
file names in order, decodes JSON, loads document payloads. Consumers only
build candidate names for their domain and delegate here — the HTTP File
Source for HTTP requests, the sqflite Data Query for database queries.
A missing candidate is skipped; a matched candidate with malformed JSON
fails loudly.

## HTTP Fixture Source

The seam for providing HTTP fixtures (`HttpFixtureSource`): `resolve` takes
an `HttpFixtureRequest` (method, path, query parameters) and returns a
Fixture Collection, or `null` when the source has none; `data` materializes
a document's payload. Sources build model objects — the wire format belongs
to the Fixture Collection and Fixture Document alone.

Request normalization is owned by `HttpFixtureRequest.fromUri`, the
canonical constructor HTTP adapters use: scheme and host dropped, the URL's
query string merged into the query parameters. Sources assume that shape
and never compensate for raw request fields.

Precedence is owned by the composite `HttpFixtureSources` (itself an HTTP
Fixture Source): sources are consulted in order, the first that resolves
wins, and that source alone provides the selected document's payload.
Built-ins: `HttpFileFixtureSource` (fixture files, owning the HTTP file
naming convention) and `OpenApiFixtureSource`.

## OpenAPI Source

The HTTP Fixture Source for OpenAPI 3.x JSON documents
(`OpenApiFixtureSource`): matches the request's method and path against the
spec's `paths` (templates and server base paths included). The operation's
summary names the collection; each response — status, description, and
payload examples (or a schema-generated sample) — becomes a Fixture
Document.

## Schema Sampler

The internal seam under the OpenAPI Source (`OpenApiSchemaSampler`, not
exported): generates a sample payload from a single schema node — explicit
example-like values first, then composition keywords, then typed
placeholders — resolving document-local `$ref`s against the spec.

## Asset Loader

The IO seam under Fixture Source (`FixtureAssetLoader`): how fixture file
content is read. `BundleAssetLoader` (root asset bundle) in production;
in-memory fakes in tests.

## Selection Flow

The behavior behind `FixtureSelector.select`, owned entirely by core:
strategy dispatch (`DataSelectorType`: pick / defaultValue / random),
auto-selecting single-option collections, Selection Memory (read and
write), single-flight deduplication of concurrent interactive picks, and
response delays (`DataSelectorDelay`). Its state is scoped to the
mixing-in instance and keyed by one collection signature. `serve` runs
the full pipeline — find, select, load payload — and reports a Fixture
Outcome.

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

The runtime-only store of remembered choices, owned by the Selection Flow
and scoped to a selector instance. Written when a Fixture Choice asks to
be remembered; cleared via `clearRememberedSelectionFor` /
`clearRememberedSelections` on the selector.

## Database Adapter

The sqflite-shaped consumer seam (`DatabaseAdapter`), mirroring sqflite's
`Database` API so repositories swap between `RealDatabaseAdapter`
(production) and `FixtureDatabaseAdapter` (fixtures) with no code changes.
