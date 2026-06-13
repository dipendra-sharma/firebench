import 'package:flutter_test/flutter_test.dart';

import 'firebench_test.dart' show FakeTraceHandle;

void main() {
  test('frame-path cost: 1M record() calls', () {
    final frames = ScreenFramesBench();
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000000; i++) {
      frames.record(8333 + (i % 800000), 8333, 700000);
    }
    sw.stop();
    final perCallNs = sw.elapsedMicroseconds * 1000 / 1000000;
    debugPrintBench(
      'record(): ${sw.elapsedMilliseconds}ms for 1M calls '
      '= ${perCallNs.toStringAsFixed(1)}ns per frame',
    );
    expect(perCallNs, lessThan(1000));
  });

  test('navigation-path cost: 100k sanitize + trace setup', () {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 100000; i++) {
      final handle = FakeTraceHandle('x');
      handle.setMetric('ttid_ms', i);
      handle.putAttribute('route', '/checkout/step-$i/payment');
    }
    sw.stop();
    final perNavUs = sw.elapsedMicroseconds / 100000;
    debugPrintBench(
      'nav path: ${sw.elapsedMilliseconds}ms for 100k '
      '= ${perNavUs.toStringAsFixed(2)}us per navigation',
    );
    expect(perNavUs, lessThan(100));
  });
}

void debugPrintBench(String message) {
  // ignore: avoid_print
  print('BENCH $message');
}

class ScreenFramesBench {
  int total = 0;
  int slow = 0;
  int frozen = 0;
  int maxMicros = 0;
  int delayMicros = 0;

  void record(int spanMicros, int slowMicros, int frozenMicros) {
    total++;
    if (spanMicros > maxMicros) maxMicros = spanMicros;
    if (spanMicros >= frozenMicros) {
      frozen++;
    } else if (spanMicros > slowMicros) {
      slow++;
    }
    final overrun = spanMicros - slowMicros;
    if (overrun > 0) delayMicros += overrun;
  }
}
