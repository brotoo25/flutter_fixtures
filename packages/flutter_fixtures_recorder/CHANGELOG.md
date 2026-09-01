# Changelog

## 0.1.0

* Initial release: record real request/response traffic from any data source and replay it later, in order.
* Source-agnostic domain: `RecordedRequest` (source + operation + target) describes requests from any adapter, and one session can hold several sources at once.
* `FixtureRecorder` controller with idle / recording / replaying modes; `decide` returns a sealed `ReplayDecision` (`Replayed` / `ForwardToSource` / `RejectRequest`) so adapters only render decisions, never re-implement replay choreography.
* Replay serves each recording exactly once, in recorded order per request key; an exhausted key is a miss, so the end of a session's scope is explicit (with `forward`, traffic returns to the real source — or to the fixtures picker when composed with `FixturesInterceptor`). `restartReplay` rewinds for another pass.
* `RecordingSessionStore` persistence seam with file and in-memory implementations; `list` returns lightweight `RecordingSessionSummary` values, and `sessionStoreForDirectory` picks files where possible and memory on web, resolving the directory lazily so recorders construct synchronously. Persistent saves reject unencodable responses loudly.
* Replay progress is observable: the recorder notifies on every replayed hit and exposes `replayedCount` / `replayServeOrder` (`SessionReplay.servedCount` / `serveOrder`), so timelines read the engine instead of mirroring it. The stop-recording notification fires once the session is saved.
* Built-in UI tools: `RecorderToolbar`, `stopRecordingWithPrompt` (the toolbar's save-or-discard flow, reusable from custom surfaces), and the recorded-sessions sheet (deleting the session being replayed stops the replay).
* Source adapters ship in the transport packages against core's thin `TrafficRecorder` seam: `RecorderInterceptor` (flutter_fixtures_dio) and `RecorderDatabaseAdapter` (flutter_fixtures_sqflite).
