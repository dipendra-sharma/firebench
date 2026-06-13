# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0-alpha.2 - 2026-06-13

### Fixed

- Metrics set on a `startTrace(...)` handle (or written while finalizing a
  screen) before the underlying Firebase trace had started were silently
  dropped. Metrics and attributes are now buffered and flushed after the trace
  starts, so none are lost.

### Added

- Nested-navigator support: each `FirebenchNavigatorObserver` tracks only its
  own navigator, so a separate observer on a nested navigator no longer
  clobbers the root observer's active screen. Concurrent screen traces coexist.
- Custom per-screen metrics and attributes via `FirebenchDisplay.setMetric` /
  `FirebenchDisplay.putAttribute`.

### Changed

- `slow_frames` now explicitly excludes frozen frames (documented).

## 0.1.0-alpha.1 - 2026-06-12

Initial alpha release. Targets the free Firebase Performance backend — no paid
SaaS required.

> Alpha: the public API may change before the 1.0 release.

### Added

- Drop-in `FirebenchNavigatorObserver` that emits one Firebase trace per screen
  visit, named `screen_<RouteName>`.
- Per-screen metrics: `ttid_ms` (time to initial display) and opt-in `ttfd_ms`
  (time to full display).
- Frame metrics per screen: `slow_frames`, `frozen_frames`, `total_frames`,
  `max_frame_ms`, and `frames_delay_ms`.
- Trace attributes: `route`, `previous_route`, `display_complete`.
- Time-to-full-display reporting via `Firebench.instance.currentDisplay()` /
  `reportFullyDisplayed()` and the `FirebenchDisplayWidget` wrapper.
- Manual traces: `Firebench.instance.trace(...)` and
  `Firebench.instance.startTrace(...)` with metric and attribute support.
- `FirebenchConfig` for enabling/disabling tracing, debug-mode tracing, trace
  prefixing, auto-finish timeout, TTFD and frame tracking toggles, slow/frozen
  frame thresholds, route ignoring, and custom route-name extraction.
- GoRouter support via `GoRouter(observers: [FirebenchNavigatorObserver()])`.
- Safe by design: all Firebase failures are caught and logged in debug; the SDK
  never throws into the host app.
