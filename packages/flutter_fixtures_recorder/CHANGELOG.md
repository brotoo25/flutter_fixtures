# Changelog

## 0.1.0

* Initial release: record real request/response traffic from any data source and replay it later, in order.
* Source-agnostic domain: `RecordedRequest` (source + operation + target) describes requests from any adapter, and one session can hold several sources at once.
* `FixtureRecorder` controller with idle / recording / replaying modes; `decide` returns a sealed `ReplayDecision` (`Replayed` / `ForwardToSource` / `RejectRequest`) so adapters only render decisions, never re-implement replay choreography.
* `RecordingSessionStore` persistence seam with file and in-memory implementations.
* Built-in UI tools: `RecorderToolbar` and the recorded-sessions sheet.
* Source adapters ship separately: `flutter_fixtures_recorder_dio` (HTTP) and `flutter_fixtures_recorder_sqflite` (database).
