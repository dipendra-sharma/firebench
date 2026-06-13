/// Creates backend trace handles. Implemented by [FirebaseTraceReporter] and
/// swappable in tests via [Firebench.init].
abstract interface class TraceReporter {
  /// Creates a new trace named [name], or `null` if one cannot be created.
  TraceHandle? newTrace(String name);
}

/// A single backend trace that can be started, annotated, and stopped.
abstract interface class TraceHandle {
  /// Starts the trace timer.
  Future<void> start();

  /// Stops the trace and flushes it to the backend.
  Future<void> stop();

  /// Records integer metric [name] with [value] on the trace.
  void setMetric(String name, int value);

  /// Attaches string attribute [name] with [value] to the trace.
  void putAttribute(String name, String value);
}
