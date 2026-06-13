import 'package:firebench/firebench.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTraceHandle implements TraceHandle {
  final String name;
  final Map<String, int> metrics = {};
  final Map<String, String> attributes = {};
  bool started = false;
  bool stopped = false;

  FakeTraceHandle(this.name);

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => stopped = true;

  @override
  void setMetric(String name, int value) => metrics[name] = value;

  @override
  void putAttribute(String name, String value) => attributes[name] = value;
}

class FakeReporter implements TraceReporter {
  final List<FakeTraceHandle> traces = [];

  @override
  TraceHandle newTrace(String name) {
    final handle = FakeTraceHandle(name);
    traces.add(handle);
    return handle;
  }
}

class ThrowingReporter implements TraceReporter {
  @override
  TraceHandle newTrace(String name) => throw StateError('backend down');
}

class FailingStartHandle extends FakeTraceHandle {
  FailingStartHandle(super.name);

  @override
  Future<void> start() async => throw StateError('channel error');
}

class FailingStartReporter implements TraceReporter {
  @override
  TraceHandle newTrace(String name) => FailingStartHandle(name);
}

class StrictTraceHandle implements TraceHandle {
  final String name;
  final Map<String, int> metrics = {};
  final Map<String, String> attributes = {};
  bool started = false;
  bool stopped = false;

  StrictTraceHandle(this.name);

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => stopped = true;

  @override
  void setMetric(String name, int value) {
    if (started && !stopped) metrics[name] = value;
  }

  @override
  void putAttribute(String name, String value) {
    if (!stopped) attributes[name] = value;
  }
}

class StrictReporter implements TraceReporter {
  final List<StrictTraceHandle> traces = [];

  @override
  TraceHandle newTrace(String name) {
    final handle = StrictTraceHandle(name);
    traces.add(handle);
    return handle;
  }
}

class FakeFrameCallbackHandler implements FrameCallbackHandler {
  FrameCallback? postFrame;
  TimingsCallback? timings;

  @override
  void addPostFrameCallback(FrameCallback callback) => postFrame = callback;

  @override
  void addTimingsCallback(TimingsCallback callback) => timings = callback;

  @override
  void removeTimingsCallback(TimingsCallback callback) => timings = null;

  void fireFirstFrame() => postFrame?.call(Duration.zero);
}

void main() {
  late FakeReporter reporter;
  late FakeFrameCallbackHandler frames;
  late List<DateTime> clockValues;

  DateTime clock() => clockValues.removeAt(0);

  setUp(() {
    reporter = FakeReporter();
    frames = FakeFrameCallbackHandler();
    clockValues = [];
  });

  tearDown(Firebench.reset);

  Future<void> initWith(FirebenchConfig config) {
    return Firebench.init(
      config: config,
      reporter: reporter,
      frameHandler: frames,
      clock: clock,
    );
  }

  test('screen visit produces a prefixed, sanitized trace name', () async {
    await initWith(const FirebenchConfig(traceInDebug: true));
    clockValues = [DateTime(2026, 6, 12, 10, 0, 0)];

    Firebench.instance.beginScreen('/checkout/step-1');
    await Future<void>.delayed(Duration.zero);

    expect(reporter.traces.single.name, 'screen__checkout_step_1');
    expect(reporter.traces.single.started, isTrue);
  });

  test('records ttid from push to first frame', () async {
    await initWith(const FirebenchConfig(traceInDebug: true));
    clockValues = [
      DateTime(2026, 6, 12, 10, 0, 0),
      DateTime(2026, 6, 12, 10, 0, 0, 120),
      DateTime(2026, 6, 12, 10, 0, 5),
    ];

    Firebench.instance.beginScreen('Home');
    await Future<void>.delayed(Duration.zero);
    frames.fireFirstFrame();
    Firebench.instance.finalizeActiveScreen();
    await Future<void>.delayed(Duration.zero);

    final trace = reporter.traces.single;
    expect(trace.metrics['ttid_ms'], 120);
    expect(trace.attributes['route'], 'Home');
    expect(trace.stopped, isTrue);
  });

  test('ttfd recorded only when enabled and reported', () async {
    await initWith(
      const FirebenchConfig(
        traceInDebug: true,
        enableTtfd: true,
        enableFrameTracking: false,
      ),
    );
    clockValues = [
      DateTime(2026, 6, 12, 10, 0, 0),
      DateTime(2026, 6, 12, 10, 0, 0, 500),
      DateTime(2026, 6, 12, 10, 0, 1),
    ];

    Firebench.instance.beginScreen('Feed');
    await Future<void>.delayed(Duration.zero);
    Firebench.instance.reportFullyDisplayed();
    Firebench.instance.finalizeActiveScreen();
    await Future<void>.delayed(Duration.zero);

    final trace = reporter.traces.single;
    expect(trace.metrics['ttfd_ms'], 500);
    expect(trace.attributes['display_complete'], 'true');
  });

  test('frame jank metrics classify slow and frozen frames', () async {
    await initWith(const FirebenchConfig(traceInDebug: true));
    clockValues = [
      DateTime(2026, 6, 12, 10, 0, 0),
      DateTime(2026, 6, 12, 10, 0, 1),
    ];

    Firebench.instance.beginScreen('Gallery');
    await Future<void>.delayed(Duration.zero);
    frames.timings?.call([_timing(8), _timing(40), _timing(800)]);
    Firebench.instance.finalizeActiveScreen();
    await Future<void>.delayed(Duration.zero);

    final trace = reporter.traces.single;
    expect(trace.metrics['total_frames'], 3);
    expect(trace.metrics['slow_frames'], 1);
    expect(trace.metrics['frozen_frames'], 1);
    expect(trace.metrics['max_frame_ms'], 800);
  });

  test('disabled in debug by default produces no traces', () async {
    await initWith(const FirebenchConfig());

    final result = Firebench.instance.beginScreen('Home');

    expect(result, isNull);
    expect(reporter.traces, isEmpty);
  });

  test('ignored routes are skipped', () async {
    await initWith(
      const FirebenchConfig(traceInDebug: true, ignoreRoutes: {'/splash'}),
    );
    clockValues = [DateTime(2026, 6, 12, 10, 0, 0)];

    Firebench.instance.beginScreen('Home');
    expect(reporter.traces.single.name, 'screen_Home');
  });

  test('pop before start resolves still stops trace exactly once', () async {
    await initWith(const FirebenchConfig(traceInDebug: true));
    clockValues = [DateTime(2026, 6, 12, 10, 0, 0)];

    Firebench.instance.beginScreen('Transient');
    Firebench.instance.finalizeActiveScreen();
    await Future<void>.delayed(Duration.zero);

    expect(reporter.traces.single.stopped, isTrue);
  });

  test('finalizeScreenNamed ignores non-matching route (dialog pop)', () async {
    await initWith(const FirebenchConfig(traceInDebug: true));
    clockValues = [DateTime(2026, 6, 12, 10, 0, 0)];

    Firebench.instance.beginScreen('Home');
    await Future<void>.delayed(Duration.zero);
    Firebench.instance.finalizeScreenNamed('SomeDialog');

    expect(reporter.traces.single.stopped, isFalse);

    Firebench.instance.finalizeScreenNamed('Home');
    await Future<void>.delayed(Duration.zero);
    expect(reporter.traces.single.stopped, isTrue);
  });

  test('throwing reporter never crashes beginScreen or manual trace', () async {
    await Firebench.init(
      config: const FirebenchConfig(traceInDebug: true),
      reporter: ThrowingReporter(),
      frameHandler: frames,
      clock: clock,
    );

    expect(Firebench.instance.beginScreen('Home'), isNull);
    final value = await Firebench.instance.trace('load', () async => 7);
    expect(value, 7);
    expect(Firebench.instance.startTrace('x').stop(), completes);
  });

  test('handle whose start throws is contained and frames released', () async {
    await Firebench.init(
      config: const FirebenchConfig(traceInDebug: true),
      reporter: FailingStartReporter(),
      frameHandler: frames,
      clock: clock,
    );
    clockValues = [DateTime(2026, 6, 12, 10, 0, 0)];

    final trace = Firebench.instance.beginScreen('Home');
    await Future<void>.delayed(Duration.zero);
    Firebench.instance.finalizeActiveScreen();
    await Future<void>.delayed(Duration.zero);

    expect(trace, isNotNull);
  });

  test('re-init disposes previous frame listener', () async {
    await initWith(const FirebenchConfig(traceInDebug: true));
    clockValues = [DateTime(2026, 6, 12, 10, 0, 0)];
    Firebench.instance.beginScreen('Home');
    expect(frames.timings, isNotNull);

    await initWith(const FirebenchConfig(traceInDebug: true));

    expect(frames.timings, isNull);
  });

  test('manual trace runs action, starts and stops handle', () async {
    await initWith(const FirebenchConfig(traceInDebug: true));

    final value = await Firebench.instance.trace('load_data', () async => 42);

    expect(value, 42);
    expect(reporter.traces.single.name, 'load_data');
    expect(reporter.traces.single.started, isTrue);
    expect(reporter.traces.single.stopped, isTrue);
  });

  test('manual trace stops handle even when action throws', () async {
    await initWith(const FirebenchConfig(traceInDebug: true));

    await expectLater(
      Firebench.instance.trace('boom', () async => throw StateError('x')),
      throwsStateError,
    );
    expect(reporter.traces.single.stopped, isTrue);
  });

  test('startTrace metrics set before start resolves are not dropped', () async {
    final strict = StrictReporter();
    await Firebench.init(
      config: const FirebenchConfig(traceInDebug: true),
      reporter: strict,
      frameHandler: frames,
      clock: clock,
    );

    final t = Firebench.instance.startTrace('checkout');
    t.setMetric('items', 3);
    t.putAttribute('coupon', 'SAVE10');
    await t.stop();

    final handle = strict.traces.single;
    expect(handle.metrics['items'], 3);
    expect(handle.attributes['coupon'], 'SAVE10');
    expect(handle.stopped, isTrue);
  });

  test('screen metrics flushed after start when finalized early', () async {
    final strict = StrictReporter();
    await Firebench.init(
      config: const FirebenchConfig(
        traceInDebug: true,
        enableFrameTracking: false,
      ),
      reporter: strict,
      frameHandler: frames,
      clock: clock,
    );
    clockValues = [
      DateTime(2026, 6, 12, 10, 0, 0),
      DateTime(2026, 6, 12, 10, 0, 0, 90),
    ];

    Firebench.instance.beginScreen('Home');
    frames.fireFirstFrame();
    Firebench.instance.finalizeActiveScreen();
    await Future<void>.delayed(Duration.zero);

    final handle = strict.traces.single;
    expect(handle.metrics['ttid_ms'], 90);
    expect(handle.stopped, isTrue);
  });

  test('custom per-screen metric and attribute reach the trace', () async {
    await initWith(
      const FirebenchConfig(traceInDebug: true, enableFrameTracking: false),
    );
    clockValues = [DateTime(2026, 6, 12, 10, 0, 0)];

    Firebench.instance.beginScreen('Cart');
    await Future<void>.delayed(Duration.zero);
    final display = Firebench.instance.currentDisplay();
    display?.setMetric('cart_size', 5);
    display?.putAttribute('tier', 'gold');
    Firebench.instance.finalizeActiveScreen();
    await Future<void>.delayed(Duration.zero);

    final trace = reporter.traces.single;
    expect(trace.metrics['cart_size'], 5);
    expect(trace.attributes['tier'], 'gold');
  });

  test('nested navigators keep independent concurrent screen traces', () async {
    await initWith(
      const FirebenchConfig(traceInDebug: true, enableFrameTracking: false),
    );
    clockValues = [
      DateTime(2026, 6, 12, 10, 0, 0),
      DateTime(2026, 6, 12, 10, 0, 0),
    ];

    final root = Firebench.instance.beginScreen('RootHost');
    final nested = Firebench.instance.beginScreen('NestedTab');
    await Future<void>.delayed(Duration.zero);

    expect(Firebench.instance.currentDisplay(), isNotNull);
    Firebench.instance.finalizeScreen(root!);
    Firebench.instance.finalizeScreen(nested!);
    await Future<void>.delayed(Duration.zero);

    expect(reporter.traces.map((t) => t.name), [
      'screen_RootHost',
      'screen_NestedTab',
    ]);
    expect(reporter.traces.every((t) => t.stopped), isTrue);
  });
}

FrameTiming _timing(int totalMs) {
  final us = totalMs * 1000;
  return FrameTiming(
    vsyncStart: 0,
    buildStart: 0,
    buildFinish: us,
    rasterStart: us,
    rasterFinish: us,
    rasterFinishWallTime: us,
  );
}
