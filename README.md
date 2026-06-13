# firebench

[![pub package](https://img.shields.io/pub/v/firebench.svg)](https://pub.dev/packages/firebench)

> ⚠️ Alpha: API may change before 1.0.

Sentry-style automatic per-screen performance tracing for Flutter, reported to the **free Firebase Performance backend**.

Firebase Performance cannot trace individual Flutter screens (the whole app is one native view). `firebench` closes that gap with a drop-in `NavigatorObserver` modeled on `SentryNavigatorObserver`, while sending everything to Firebase so there is no paid SaaS.

## What it captures (per screen visit)

One Firebase `Trace` named `screen_<RouteName>` with:

| Metric (int) | Meaning |
|---|---|
| `ttid_ms` | Time to initial display — push to first frame (automatic) |
| `ttfd_ms` | Time to full display — push to `reportFullyDisplayed()` (opt-in) |
| `slow_frames` | Frames slower than `slowFrameThreshold` but faster than `frozenFrameThreshold` (default: auto from display refresh rate, 16ms fallback). Frozen frames are counted separately, not here. |
| `frozen_frames` | Frames slower than `frozenFrameThreshold` (default 700ms) |
| `total_frames` | Frames rendered while the screen was active |
| `max_frame_ms` | Slowest single frame |
| `frames_delay_ms` | Cumulative jank over the slow-frame budget |

Attributes: `route`, `previous_route`, `display_complete`.

App start (`_app_start`) and HTTP/S traces are captured automatically by `firebase_performance` itself — no extra setup.

## Setup

```dart
await Firebase.initializeApp();
await Firebench.init(
  config: const FirebenchConfig(enableTtfd: true),
);

MaterialApp(
  navigatorObservers: [FirebenchNavigatorObserver()],
);
```

GoRouter:

```dart
GoRouter(observers: [FirebenchNavigatorObserver()]);
```

## Time to full display (opt-in)

For screens that load async content, report when fully rendered:

```dart
// Capture in initState before the async work, report after:
final display = Firebench.instance.currentDisplay();
await repo.load();
display?.reportFullyDisplayed();
```

Or wrap the screen and let stateless children auto-report:

```dart
FirebenchDisplayWidget(child: MyScreen());
```

## Custom screen metrics and attributes

Tag the active screen's trace with your own metrics and attributes to segment
performance by cohort (reserved keys `route`, `previous_route`,
`display_complete` always win):

```dart
final display = Firebench.instance.currentDisplay();
display?.setMetric('list_size', items.length);
display?.putAttribute('user_tier', tier);
```

## Manual traces

```dart
final data = await Firebench.instance.trace('load_dashboard', () => repo.fetch());

final t = Firebench.instance.startTrace('checkout_validation');
t.setMetric('items', cart.length);
await t.stop();
```

## Configuration

`FirebenchConfig` — `enabled`, `traceInDebug` (default `false`; frame timings are unreliable in debug), `tracePrefix`, `autoFinishAfter`, `enableTtfd`, `enableFrameTracking`, `slowFrameThreshold`, `frozenFrameThreshold`, `ignoreRoutes`, `routeNameExtractor`, `tagManualTracesWithRoute`.

## Notes

- Run in **profile/release** mode for meaningful frame metrics. Tracing is disabled in debug unless `traceInDebug: true`.
- Firebase metric values are integers, so durations are milliseconds (sub-millisecond timings are floored).
- Each observer tracks only its own navigator. Add a separate `FirebenchNavigatorObserver()` to a nested navigator to trace it independently; concurrent screen traces coexist. Frame metrics follow the most recently pushed screen, so per-screen frame counts can be approximate while a nested screen is open.
- After a pop, tracking resumes on the next push (the revealed screen is not re-traced).
- Unnamed routes (dialogs, bottom sheets) neither start nor end screen traces — their frames count toward the screen beneath them.
- `pushReplacement` finalizes the replaced screen's trace even when the new route is unnamed.
- All Firebase failures are caught and logged in debug; the SDK never throws into the host app.
- Unlike Sentry, a route pushed *from* an ignored route is still traced; `ignoreRoutes` only filters destinations.

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
