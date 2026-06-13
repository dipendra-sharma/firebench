import 'dart:ui' show FramePhase, FrameTiming;

import 'frame_callback_handler.dart';
import 'screen_frames.dart';

/// Routes Flutter frame timings into the currently active [ScreenFrames],
/// subscribing to timing callbacks only while a screen is being tracked.
class FrameTracker {
  /// Creates a tracker with the slow and frozen frame thresholds.
  FrameTracker(
    this._handler, {
    required Duration slowFrameThreshold,
    required Duration frozenFrameThreshold,
  }) : _slowMicros = slowFrameThreshold.inMicroseconds,
       _frozenMicros = frozenFrameThreshold.inMicroseconds;

  final FrameCallbackHandler _handler;
  final int _slowMicros;
  final int _frozenMicros;

  ScreenFrames? _active;
  bool _listening = false;

  /// Directs subsequent frame timings into [frames].
  void activate(ScreenFrames frames) {
    _active = frames;
    if (_listening) return;
    _handler.addTimingsCallback(_onTimings);
    _listening = true;
  }

  /// Stops recording into [frames] if it is the active target.
  void deactivate(ScreenFrames frames) {
    if (!identical(_active, frames)) return;
    _active = null;
    _stopListening();
  }

  void _onTimings(List<FrameTiming> timings) {
    final active = _active;
    if (active == null) return;
    for (final timing in timings) {
      final spanMicros =
          timing.timestampInMicroseconds(FramePhase.rasterFinish) -
          timing.timestampInMicroseconds(FramePhase.vsyncStart);
      active.record(spanMicros, _slowMicros, _frozenMicros);
    }
  }

  void _stopListening() {
    if (!_listening) return;
    _handler.removeTimingsCallback(_onTimings);
    _listening = false;
  }

  /// Detaches the timing callback and clears state.
  void dispose() {
    _active = null;
    _stopListening();
  }
}
