import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/pose_painter.dart';

void main() {
  test('repaints when the oriented camera image size changes', () {
    final portrait = PosePainter(const [], const Size(480, 640));
    final landscape = PosePainter(const [], const Size(640, 480));

    expect(landscape.shouldRepaint(portrait), isTrue);
    expect(
      PosePainter(const [], const Size(480, 640)).shouldRepaint(portrait),
      isFalse,
    );
  });
}
