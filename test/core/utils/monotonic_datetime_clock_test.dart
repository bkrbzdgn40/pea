import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/core/utils/monotonic_datetime_clock.dart';

void main() {
  test('anchors readable DateTime values to a monotonic elapsed source', () {
    var elapsed = Duration.zero;
    final anchor = DateTime.utc(2026, 7, 31, 8);
    final clock = MonotonicDateTimeClock(
      anchor: anchor,
      elapsed: () => elapsed,
    );

    expect(clock.now(), anchor);

    elapsed = const Duration(milliseconds: 275);
    expect(clock.now(), anchor.add(const Duration(milliseconds: 275)));

    elapsed = const Duration(seconds: 3, milliseconds: 40);
    expect(
      clock.now(),
      anchor.add(const Duration(seconds: 3, milliseconds: 40)),
    );
  });
}
