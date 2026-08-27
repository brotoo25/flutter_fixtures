# Changelog

## 0.1.0

* Initial release: record real request/response traffic and replay it later, in order.
* `FixtureRecorder` controller with idle / recording / replaying modes.
* `RecorderInterceptor` Dio adapter with configurable replay-miss behavior.
* `RecordingSessionStore` persistence seam with file and in-memory implementations.
* Built-in UI tools: `RecorderToolbar` and the recorded-sessions sheet.
