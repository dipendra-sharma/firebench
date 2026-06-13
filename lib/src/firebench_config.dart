import 'package:flutter/widgets.dart';

/// Resolves a stable trace name from a route's [RouteSettings]; return `null`
/// to skip tracing that route.
typedef RouteNameExtractor = String? Function(RouteSettings settings);

/// Immutable configuration for [Firebench] tracing behavior.
class FirebenchConfig {
  /// Creates a configuration; every field has a sensible default.
  const FirebenchConfig({
    this.enabled = true,
    this.traceInDebug = false,
    this.tracePrefix = 'screen_',
    this.autoFinishAfter = const Duration(seconds: 30),
    this.enableTtfd = false,
    this.enableFrameTracking = true,
    this.slowFrameThreshold,
    this.frozenFrameThreshold = const Duration(milliseconds: 700),
    this.ignoreRoutes = const <String>{},
    this.routeNameExtractor,
    this.tagManualTracesWithRoute = false,
  });

  /// Whether tracing is active at all.
  final bool enabled;

  /// Whether to trace in debug builds, where frame timings are unreliable.
  final bool traceInDebug;

  /// Prefix prepended to each screen trace name (e.g. `screen_`).
  final String tracePrefix;

  /// Maximum lifetime of a screen trace before it is finalized automatically.
  final Duration autoFinishAfter;

  /// Whether to measure time-to-full-display in addition to initial display.
  final bool enableTtfd;

  /// Whether to collect per-screen frame metrics.
  final bool enableFrameTracking;

  /// Frames slower than this count as slow. Null means auto-detect from the
  /// display refresh rate, with a 16ms fallback when no display is available.
  final Duration? slowFrameThreshold;

  /// Frames slower than this count as frozen.
  final Duration frozenFrameThreshold;

  /// Route names that should never start a screen trace.
  final Set<String> ignoreRoutes;

  /// Optional custom resolver for route trace names.
  final RouteNameExtractor? routeNameExtractor;

  /// Whether manual traces are tagged with the active route name.
  final bool tagManualTracesWithRoute;
}
