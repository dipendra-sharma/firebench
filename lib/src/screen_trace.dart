import 'dart:async';

import 'clock.dart';
import 'firebench_config.dart';
import 'frame_callback_handler.dart';
import 'frame_tracker.dart';
import 'logging.dart';
import 'reporter.dart';
import 'screen_frames.dart';
import 'trace_naming.dart';

/// Tracks one screen visit: start time, initial/full display timestamps, and
/// frame metrics, writing them to a [TraceHandle] when finalized.
class ScreenTrace {
  /// Creates a screen trace bound to [handle] for [routeName].
  ScreenTrace({
    required TraceHandle handle,
    required FirebenchConfig config,
    required FrameTracker frameTracker,
    required FrameCallbackHandler frameHandler,
    required Clock clock,
    required this.routeName,
    this.previousRouteName,
  }) : _handle = handle,
       _config = config,
       _frameTracker = frameTracker,
       _frameHandler = frameHandler,
       _clock = clock;

  final TraceHandle _handle;
  final FirebenchConfig _config;
  final FrameTracker _frameTracker;
  final FrameCallbackHandler _frameHandler;
  final Clock _clock;

  /// The route name being traced.
  final String routeName;

  /// The route the user navigated from, if any.
  final String? previousRouteName;

  final ScreenFrames _frames = ScreenFrames();
  final Map<String, int> _customMetrics = {};
  final Map<String, String> _customAttributes = {};
  late final DateTime _startedAt;
  DateTime? _initialDisplayAt;
  DateTime? _fullDisplayAt;
  Timer? _autoFinishTimer;
  bool _started = false;
  bool _finalized = false;

  /// Starts the trace, frame tracking, and the auto-finish timer.
  void begin() {
    _startedAt = _clock();
    if (_config.enableFrameTracking) _frameTracker.activate(_frames);
    _frameHandler.addPostFrameCallback(_recordInitialDisplay);
    _autoFinishTimer = Timer(_config.autoFinishAfter, finalize);
    unawaited(_startHandle());
  }

  Future<void> _startHandle() async {
    try {
      await _handle.start();
      _started = true;
      if (_finalized) await _flushAndStop();
    } catch (error) {
      logFirebenchError('failed to start trace $routeName', error);
      _frameTracker.deactivate(_frames);
      _autoFinishTimer?.cancel();
      _finalized = true;
    }
  }

  void _recordInitialDisplay(Duration _) {
    _initialDisplayAt ??= _clock();
  }

  /// Records the first full-display timestamp when TTFD tracking is enabled.
  void reportFullyDisplayed() {
    if (!_config.enableTtfd || _finalized) return;
    _fullDisplayAt ??= _clock();
  }

  /// Records a custom integer metric to write when the trace is finalized.
  void setMetric(String name, int value) {
    if (_finalized) return;
    _customMetrics[name] = value;
  }

  /// Records a custom string attribute to write when the trace is finalized.
  void putAttribute(String name, String value) {
    if (_finalized) return;
    _customAttributes[name] = clampAttribute(value);
  }

  /// Writes all metrics and stops the trace. Idempotent and never throws.
  Future<void> finalize() async {
    if (_finalized) return;
    _finalized = true;
    _autoFinishTimer?.cancel();
    _frameTracker.deactivate(_frames);
    if (_started) await _flushAndStop();
  }

  Future<void> _flushAndStop() async {
    try {
      _writeMetrics();
      await _handle.stop();
    } catch (error) {
      logFirebenchError('failed to finalize trace $routeName', error);
    }
  }

  void _writeMetrics() {
    final initialDisplay = _initialDisplayAt;
    if (initialDisplay != null) {
      _handle.setMetric(
        'ttid_ms',
        initialDisplay.difference(_startedAt).inMilliseconds,
      );
    }
    final fullDisplay = _fullDisplayAt;
    if (fullDisplay != null) {
      _handle.setMetric(
        'ttfd_ms',
        fullDisplay.difference(_startedAt).inMilliseconds,
      );
    }
    if (_config.enableFrameTracking) _frames.applyTo(_handle);
    _customMetrics.forEach(_handle.setMetric);
    _writeAttributes(fullyDisplayed: fullDisplay != null);
  }

  void _writeAttributes({required bool fullyDisplayed}) {
    _customAttributes.forEach(_handle.putAttribute);
    _handle.putAttribute('route', clampAttribute(routeName));
    final previous = previousRouteName;
    if (previous != null) {
      _handle.putAttribute('previous_route', clampAttribute(previous));
    }
    if (_config.enableTtfd) {
      _handle.putAttribute('display_complete', '$fullyDisplayed');
    }
  }
}
