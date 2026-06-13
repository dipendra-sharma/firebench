/// Automatic per-screen performance tracing for Flutter, reported to the free
/// Firebase Performance backend.
///
/// Initialize with [Firebench.init], add a [FirebenchNavigatorObserver] to your
/// app's navigator, and optionally measure work with [Firebench.trace].
library;

export 'src/clock.dart' show Clock, systemClock;
export 'src/firebase_reporter.dart' show FirebaseTraceReporter;
export 'src/firebench.dart' show Firebench, FirebenchDisplay, FirebenchTrace;
export 'src/firebench_config.dart' show FirebenchConfig, RouteNameExtractor;
export 'src/firebench_display_widget.dart' show FirebenchDisplayWidget;
export 'src/firebench_navigator_observer.dart' show FirebenchNavigatorObserver;
export 'src/frame_callback_handler.dart'
    show FrameCallbackHandler, DefaultFrameCallbackHandler;
export 'src/reporter.dart' show TraceReporter, TraceHandle;
