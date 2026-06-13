import 'package:firebench/firebench.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingHandle implements TraceHandle {
  RecordingHandle(this.name);

  final String name;
  final Map<String, int> metrics = {};
  final Map<String, String> attributes = {};
  bool stopped = false;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async => stopped = true;

  @override
  void setMetric(String name, int value) => metrics[name] = value;

  @override
  void putAttribute(String name, String value) => attributes[name] = value;
}

class RecordingReporter implements TraceReporter {
  final List<RecordingHandle> traces = [];

  @override
  TraceHandle newTrace(String name) {
    final handle = RecordingHandle(name);
    traces.add(handle);
    return handle;
  }
}

class PassthroughFrameHandler implements FrameCallbackHandler {
  @override
  void addPostFrameCallback(FrameCallback callback) {
    SchedulerBinding.instance.addPostFrameCallback(callback);
  }

  @override
  void addTimingsCallback(TimingsCallback callback) {}

  @override
  void removeTimingsCallback(TimingsCallback callback) {}
}

void main() {
  late RecordingReporter reporter;

  setUp(() async {
    reporter = RecordingReporter();
    await Firebench.init(
      config: const FirebenchConfig(
        traceInDebug: true,
        enableFrameTracking: false,
      ),
      reporter: reporter,
      frameHandler: PassthroughFrameHandler(),
    );
  });

  tearDown(Firebench.reset);

  Widget app() {
    return MaterialApp(
      navigatorObservers: [FirebenchNavigatorObserver()],
      routes: {
        '/': (_) => const _HomePage(),
        '/details': (_) => const _DetailsPage(),
      },
    );
  }

  testWidgets('push and pop produce one finished screen trace per route', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(reporter.traces.map((t) => t.name), ['screen__']);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(reporter.traces.map((t) => t.name), ['screen__', 'screen__details']);
    final home = reporter.traces[0];
    final details = reporter.traces[1];
    expect(home.stopped, isTrue);
    expect(home.metrics.containsKey('ttid_ms'), isTrue);

    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();

    expect(details.stopped, isTrue);
    expect(details.metrics.containsKey('ttid_ms'), isTrue);
    expect(details.attributes['previous_route'], '/');
  });

  testWidgets('dialog open and dismiss does not end the screen trace', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final details = reporter.traces[1];

    await tester.tap(find.text('dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(details.stopped, isFalse);
    expect(reporter.traces, hasLength(2));

    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(details.stopped, isTrue);
  });
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).pushNamed('/details'),
        child: const Text('open'),
      ),
    );
  }
}

class _DetailsPage extends StatelessWidget {
  const _DetailsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('back'),
          ),
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('close'),
              ),
            ),
            child: const Text('dialog'),
          ),
        ],
      ),
    );
  }
}
