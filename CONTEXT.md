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

Statement identity is one model: `SqfliteQuery` carries every field a
`DatabaseAdapter` operation takes, with two projections —
`fixtureCandidates` (deliberately lossy fixture-file names, so one
fixture serves a family of statements) and `recordingTarget` (total
canonical JSON for record & replay, so differing arguments never match).

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
and never compensate for raw request fields. `canonicalTarget` renders the
normalized request as one escaped, sorted string — the HTTP identity used
by record & replay, identical whichever HTTP client built the request.

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

## Traffic Recorder

The thin record-and-replay seam in core (`TrafficRecorder`): two calls —
`decide` (how should this request be handled?) and `record` (capture this
interaction). Both take builder functions the recorder invokes only when
its mode requires them, so idle traffic builds nothing and encodes
nothing. Transport packages implement capture and replay against this
contract only (`RecorderInterceptor` in flutter_fixtures_dio,
`RecorderDatabaseAdapter` in flutter_fixtures_sqflite), so they never
depend on the recorder engine. All heavy lifting sits behind the seam in
the **Fixture Recorder**.

## Fixture Recorder

The record-and-replay engine (`FixtureRecorder`,
flutter_fixtures_recorder) — the one production adapter of core's
**Traffic Recorder** seam. A strict mode machine — idle / recording /
replaying — that source adapters feed captured traffic into (`record`)
and ask how to handle each request (`decide`, which answers with a
**Replay Decision**). Source-agnostic: one recorder serves HTTP,
database, and custom sources at once, and a session can hold them side by
side. Persistence is owned outright — the Session Store is private,
reached only through `sessions`/`deleteSession` and the save on stop.
Idle traffic passes through untouched; apps that never record simply
don't depend on this package.

## Replay Decision

The recorder's sealed answer for one request (`ReplayDecision`, core):
serve this recorded interaction (`Replayed`), let the request continue to
the real source (`ForwardToSource`), or fail it (`RejectRequest`, message
phrased by the recorder). Returned by `TrafficRecorder.decide`, which
owns the whole choreography — mode check, ordered lookup, miss policy —
so an adapter only renders the decision in its native types and never
inspects the recorder's mode.

## Recording Session

A named, ordered capture of request/response traffic
(`RecordingSession`): id, name, recorded-at, and the list of **Recorded
Interactions** in capture order. The artifact that is saved, listed,
selected, and replayed.

## Recorded Request

The source-agnostic description of one request (`RecordedRequest`):
a **source** name (`http`, `sqlite`, custom), an **operation** (HTTP
method, `query`, `insert`, ...), and a normalized **target** (path with
sorted query, SQL with arguments), plus an informational payload that never
participates in matching. The same logical request must always produce the
same target; the built-in renderings own that knowledge —
`HttpFixtureRequest.canonicalTarget` for HTTP,
`SqfliteQuery.recordingTarget` for sqflite — and custom sources own it for
their domain.

## Recorded Interaction

One captured request/response pair (`RecordedInteraction`): a Recorded
Request plus the response and capture time. The response is opaque to the
recorder — it is whatever the capturing adapter needs to reconstruct its
native response later, and the adapter that wrote it is the one that reads
it back. The round-trip contract: when sessions are persisted, a response
must survive a JSON encode/decode cycle; a persistent Session Store
refuses anything else loudly at save time.

## Session Store

The recorder's persistence seam (`RecordingSessionStore`): save, load,
delete sessions, and list lightweight summaries
(`RecordingSessionSummary` — id, name, recorded-at, interaction count),
so browsing never loads recorded payloads. Built-ins:
`FileRecordingSessionStore` (JSON files on disk, lazily resolved
directory, not on web) and `MemoryRecordingSessionStore` (runtime-only);
`sessionStoreForDirectory` picks files where possible and memory on web.

## Session Replay

The playback engine (`SessionReplay`): interactions grouped by request key
(`source operation target` by default, customizable via a
`RequestKeyBuilder`), one cursor per key, responses served in recorded
order, each recording exactly once — an exhausted key is a miss, making
the end of the session's scope explicit rather than silently repeating
stale responses. A miss returns `null` — the miss policy
(`ReplayMissBehavior`: forward / reject) is chosen by the source adapter
but interpreted by the Fixture Recorder's `decide`, which turns it into a
Replay Decision. Progress is the engine's knowledge, not a UI's:
`servedCount` and per-interaction `serveOrder` (surfaced on the Fixture
Recorder as `replayedCount` / `replayServeOrder`, which notifies on every
hit) — nothing outside the engine re-derives keys or cursors.

## Recorder Toolbar

The built-in recorder UI (`RecorderToolbar`, the sessions sheet, and the
stop-recording prompt `stopRecordingWithPrompt`). Plain listeners on
`FixtureRecorder` with no private hooks — a custom control surface uses
the same public API and can reuse the prompt and the sheet as-is.

## Database Adapter

The sqflite-shaped consumer seam (`DatabaseAdapter`), mirroring sqflite's
`Database` API so repositories swap between `RealDatabaseAdapter`
(production) and `FixtureDatabaseAdapter` (fixtures) with no code changes.
