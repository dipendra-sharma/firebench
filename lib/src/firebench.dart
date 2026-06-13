import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'clock.dart';
import 'firebase_reporter.dart';
import 'firebench_config.dart';
import 'frame_callback_handler.dart';
import 'frame_tracker.dart';
import 'logging.dart';
import 'reporter.dart';
import 'screen_trace.dart';
import 'trace_naming.dart';

/// Entry point for per-screen performance tracing. Call [init] once at startup,
/// then add a [FirebenchNavigatorObserver] to capture screen traces, and use
/// [trace] / [startTrace] for manual measurements.
class Firebench {
  Firebench._({
    required FirebenchConfig config,
    required TraceReporter reporter,
    required FrameCallbackHandler frameHandler,
    required Clock clock,
    required Duration slowFrameThreshold,
  }) : _config = config,
       _reporter = reporter,
       _frameHandler = frameHandler,
       _clock = clock,
       _frameTracker = FrameTracker(
         frameHandler,
         slowFrameThreshold: slowFrameThreshold,
         frozenFrameThreshold: config.frozenFrameThreshold,
       );

  static Firebench? _instance;

  /// The initialized singleton. Throws a [StateError] if [init] was not called.
  static Firebench get instance =>
      _instance ?? (throw StateError('Firebench.init() must be called first'));

  /// Whether [init] has been called.
  static bool get isInitialized => _instance != null;

  final FirebenchConfig _config;
  final TraceReporter _reporter;
  final FrameCallbackHandler _frameHandler;
  final FrameTracker _frameTracker;
  final Clock _clock;

  final List<ScreenTrace> _activeScreens = [];

  /// The active configuration.
  FirebenchConfig get config => _config;

  bool get _enabled => _config.enabled && (!kDebugMode || _config.traceInDebug);

  /// Initializes the singleton. Optionally inject a [reporter], [frameHandler],
  /// or [clock] for testing; production defaults target Firebase.
  static Future<void> init({
    FirebenchConfig config = const FirebenchConfig(),
    TraceReporter? reporter,
    FrameCallbackHandler? frameHandler,
    Clock clock = systemClock,
  }) async {
    _instance?._frameTracker.dispose();
    _instance = Firebench._(
      config: config,
      reporter: reporter ?? FirebaseTraceReporter(),
      frameHandler: frameHandler ?? DefaultFrameCallbackHandler(),
      clock: clock,
      slowFrameThreshold: config.slowFrameThreshold ?? _displayFrameBudget(),
    );
  }

  static Duration _displayFrameBudget() {
    try {
      final refreshRate = WidgetsBinding
          .instance
          .platformDispatcher
          .views
          .first
          .display
          .refreshRate;
      if (refreshRate > 0) {
        return Duration(
          microseconds: (Duration.microsecondsPerSecond / refreshRate).round(),
        );
      }
    } catch (error) {
      logFirebenchError('failed to read display refresh rate', error);
    }
    return const Duration(milliseconds: 16);
  }

  /// Starts a screen trace for [routeName] and returns its handle, or `null`
  /// when tracing is disabled or trace creation fails. Each observer finalizes
  /// its own previous screen via [finalizeScreen]; concurrent traces from
  /// nested navigators coexist on the active stack. Normally driven by
  /// [FirebenchNavigatorObserver].
  ScreenTrace? beginScreen(String routeName, {String? previousRouteName}) {
    if (!_enabled) return null;
    final TraceHandle? handle;
    try {
      handle = _reporter.newTrace(
        sanitizeTraceName(_config.tracePrefix, routeName),
      );
    } catch (error) {
      logFirebenchError('failed to create trace for $routeName', error);
      return null;
    }
    if (handle == null) return null;
    final trace = ScreenTrace(
      handle: handle,
      config: _config,
      frameTracker: _frameTracker,
      frameHandler: _frameHandler,
      clock: _clock,
      routeName: routeName,
      previousRouteName: previousRouteName,
    );
    _activeScreens.add(trace);
    trace.begin();
    return trace;
  }

  /// Finalizes [trace], flushing its metrics and removing it from the active
  /// stack regardless of position. Safe to call with an already-finalized or
  /// unknown trace.
  void finalizeScreen(ScreenTrace trace) {
    if (!_activeScreens.remove(trace)) return;
    unawaited(trace.finalize());
  }

  /// Finalizes the most recently started active screen, if any.
  void finalizeActiveScreen() {
    if (_activeScreens.isEmpty) return;
    finalizeScreen(_activeScreens.last);
  }

  /// Finalizes the topmost active screen only if its route matches [routeName].
  void finalizeScreenNamed(String routeName) {
    final top = _activeScreens.isEmpty ? null : _activeScreens.last;
    if (top == null || top.routeName != routeName) return;
    finalizeScreen(top);
  }

  /// A handle to the topmost active screen's display reporting, or `null`.
  /// Capture this at screen init so the report binds to that screen even if
  /// the user navigates away before its data arrives.
  FirebenchDisplay? currentDisplay() {
    if (_activeScreens.isEmpty) return null;
    return FirebenchDisplay(_activeScreens.last);
  }

  /// Times [action] inside a manual trace named [name], returning its result.
  /// The trace is stopped even if [action] throws.
  Future<T> trace<T>(String name, FutureOr<T> Function() action) async {
    TraceHandle? handle;
    if (_enabled) {
      try {
        handle = _reporter.newTrace(name);
        if (handle != null) {
          _maybeTagRoute(handle);
          await handle.start();
        }
      } catch (error) {
        logFirebenchError('failed to start manual trace $name', error);
        handle = null;
      }
    }
    try {
      return await action();
    } finally {
      try {
        await handle?.stop();
      } catch (error) {
        logFirebenchError('failed to stop manual trace $name', error);
      }
    }
  }

  /// Starts a manual trace named [name] that the caller stops explicitly via
  /// [FirebenchTrace.stop]. Use [trace] when the work is a single async call.
  FirebenchTrace startTrace(String name) {
    TraceHandle? handle;
    if (_enabled) {
      try {
        handle = _reporter.newTrace(name);
        if (handle != null) _maybeTagRoute(handle);
      } catch (error) {
        logFirebenchError('failed to create manual trace $name', error);
      }
    }
    return FirebenchTrace._(handle);
  }

  void _maybeTagRoute(TraceHandle handle) {
    final active = _activeScreens.isEmpty ? null : _activeScreens.last;
    if (_config.tagManualTracesWithRoute && active != null) {
      handle.putAttribute('route', clampAttribute(active.routeName));
    }
  }

  /// Disposes the singleton so a fresh [init] can run. For tests only.
  @visibleForTesting
  static void reset() {
    _instance?._frameTracker.dispose();
    _instance = null;
  }
}

/// A handle to a screen's display reporting, obtained from
/// [Firebench.currentDisplay] or [FirebenchDisplayWidget.of].
class FirebenchDisplay {
  /// Wraps the given screen trace.
  FirebenchDisplay(this._trace);

  final ScreenTrace _trace;

  /// Records the screen as fully displayed (time-to-full-display).
  void reportFullyDisplayed() => _trace.reportFullyDisplayed();

  /// Attaches a custom integer metric to this screen's trace.
  void setMetric(String name, int value) => _trace.setMetric(name, value);

  /// Attaches a custom string attribute to this screen's trace.
  void putAttribute(String name, String value) =>
      _trace.putAttribute(name, value);
}

/// A manually started trace returned by [Firebench.startTrace]. Annotate it
/// with [setMetric] / [putAttribute] and finish it with [stop].
class FirebenchTrace {
  FirebenchTrace._(this._handle) {
    _starting = _handle?.start().catchError((Object error) {
      logFirebenchError('failed to start manual trace', error);
    });
  }

  final TraceHandle? _handle;
  Future<void>? _starting;
  final Map<String, int> _metrics = {};
  final Map<String, String> _attributes = {};

  /// Records integer metric [name] with [value], written when the trace stops.
  void setMetric(String name, int value) => _metrics[name] = value;

  /// Attaches string attribute [name] with [value], clamped to backend limits.
  void putAttribute(String name, String value) =>
      _attributes[name] = clampAttribute(value);

  /// Stops and flushes the trace. Metrics and attributes are written after the
  /// underlying trace has started, so none are dropped. Never throws into the
  /// host app.
  Future<void> stop() async {
    final handle = _handle;
    if (handle == null) return;
    try {
      await _starting;
      _metrics.forEach(handle.setMetric);
      _attributes.forEach(handle.putAttribute);
      await handle.stop();
    } catch (error) {
      logFirebenchError('failed to stop manual trace', error);
    }
  }
}
