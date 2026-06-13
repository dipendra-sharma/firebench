import 'reporter.dart';

/// Accumulates frame timing counters for a single screen visit.
class ScreenFrames {
  int _total = 0;
  int _slow = 0;
  int _frozen = 0;
  int _maxFrameMicros = 0;
  int _delayMicros = 0;

  /// Records a frame of [spanMicros], classifying it against the slow and
  /// frozen thresholds and updating the running totals.
  void record(int spanMicros, int slowMicros, int frozenMicros) {
    _total++;
    if (spanMicros > _maxFrameMicros) _maxFrameMicros = spanMicros;
    if (spanMicros >= frozenMicros) {
      _frozen++;
    } else if (spanMicros > slowMicros) {
      _slow++;
    }
    final overrun = spanMicros - slowMicros;
    if (overrun > 0) _delayMicros += overrun;
  }

  /// Writes the accumulated frame metrics onto [handle].
  void applyTo(TraceHandle handle) {
    handle.setMetric('total_frames', _total);
    handle.setMetric('slow_frames', _slow);
    handle.setMetric('frozen_frames', _frozen);
    handle.setMetric(
      'max_frame_ms',
      _maxFrameMicros ~/ Duration.microsecondsPerMillisecond,
    );
    handle.setMetric(
      'frames_delay_ms',
      _delayMicros ~/ Duration.microsecondsPerMillisecond,
    );
  }
}
