/// Returns the current time. Injected so tests can supply a fake clock.
typedef Clock = DateTime Function();

/// The default [Clock], backed by [DateTime.now].
DateTime systemClock() => DateTime.now();
