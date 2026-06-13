import 'package:firebase_performance/firebase_performance.dart';

import 'reporter.dart';

/// A [TraceReporter] that emits traces to Firebase Performance Monitoring.
class FirebaseTraceReporter implements TraceReporter {
  /// Creates a reporter using [performance], or [FirebasePerformance.instance]
  /// when none is supplied.
  FirebaseTraceReporter([FirebasePerformance? performance])
    : _performance = performance ?? FirebasePerformance.instance;

  final FirebasePerformance _performance;

  @override
  TraceHandle newTrace(String name) =>
      _FirebaseTraceHandle(_performance.newTrace(name));
}

class _FirebaseTraceHandle implements TraceHandle {
  _FirebaseTraceHandle(this._trace);

  final Trace _trace;

  @override
  Future<void> start() => _trace.start();

  @override
  Future<void> stop() => _trace.stop();

  @override
  void setMetric(String name, int value) => _trace.setMetric(name, value);

  @override
  void putAttribute(String name, String value) =>
      _trace.putAttribute(name, value);
}
