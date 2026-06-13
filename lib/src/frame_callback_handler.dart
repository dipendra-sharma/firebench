import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Indirection over Flutter's frame callbacks so frame tracking can be tested
/// without a live binding.
abstract interface class FrameCallbackHandler {
  /// Registers [callback] to run after the next frame is rendered.
  void addPostFrameCallback(FrameCallback callback);

  /// Subscribes [callback] to per-frame timing reports.
  void addTimingsCallback(TimingsCallback callback);

  /// Removes a previously registered timings [callback].
  void removeTimingsCallback(TimingsCallback callback);
}

/// The default [FrameCallbackHandler] backed by Flutter's bindings.
class DefaultFrameCallbackHandler implements FrameCallbackHandler {
  @override
  void addPostFrameCallback(FrameCallback callback) {
    SchedulerBinding.instance.addPostFrameCallback(callback);
  }

  @override
  void addTimingsCallback(TimingsCallback callback) {
    WidgetsBinding.instance.addTimingsCallback(callback);
  }

  @override
  void removeTimingsCallback(TimingsCallback callback) {
    WidgetsBinding.instance.removeTimingsCallback(callback);
  }
}
