# Changelog

## 0.1.0

* Initial release: record real request/response traffic from any data source and replay it later, in order.
* Source-agnostic domain: `RecordedRequest` (source + operation + target) describes requests from any adapter, and one session can hold several sources at once.
* `FixtureRecorder` controller with idle / recording / replaying modes; `decide` returns a sealed `ReplayDecision` (`Replayed` / `ForwardToSource` / `RejectRequest`) so adapters only render decisions, never re-implement replay choreography.
* `RecordingSessionStore` persistence seam with file and in-memory implementations; `list` returns lightweight `RecordingSessionSummary` values, and `sessionStoreForDirectory` picks files where possible and memory on web, resolving the directory lazily so recorders construct synchronously. Persistent saves reject unencodable responses loudly.
* Built-in UI tools: `RecorderToolbar` and the recorded-sessions sheet.
* Source adapters ship in the transport packages against core's thin `TrafficRecorder` seam: `RecorderInterceptor` (flutter_fixtures_dio) and `RecordingDatabaseAdapter` (flutter_fixtures_sqflite).
