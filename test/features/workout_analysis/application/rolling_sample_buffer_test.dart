import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/rolling_sample_buffer.dart';

void main() {
  test('requires a positive capacity', () {
    expect(() => RollingSampleBuffer<int>(capacity: 0), throwsArgumentError);
  });

  test('keeps only the newest values at fixed capacity', () {
    final subject = RollingSampleBuffer<int>(capacity: 3)
      ..add(30)
      ..add(10)
      ..add(20)
      ..add(40);

    expect(subject.length, 3);
    expect(subject.sortedValues(), <int>[10, 20, 40]);
  });

  test('reuses sorted snapshots until the buffer changes', () {
    final subject = RollingSampleBuffer<double>(capacity: 3)
      ..add(3.0)
      ..add(1.0);

    final first = subject.sortedValues();
    final second = subject.sortedValues();
    expect(second, same(first));

    subject.add(2.0);
    final third = subject.sortedValues();
    expect(third, isNot(same(first)));
    expect(third, <double>[1, 2, 3]);
  });

  test('clear removes samples and invalidates the sorted cache', () {
    final subject = RollingSampleBuffer<int>(capacity: 2)..add(1);
    final beforeClear = subject.sortedValues();

    subject.clear();

    expect(subject.isEmpty, isTrue);
    expect(subject.sortedValues(), isEmpty);
    expect(subject.sortedValues(), isNot(same(beforeClear)));
  });
}
