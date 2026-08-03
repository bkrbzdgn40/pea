import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/pose_painter.dart';

void main() {
  test('repaints when visual pose inputs change', () {
    final portrait = PosePainter(const [], const Size(480, 640));
    final landscape = PosePainter(const [], const Size(640, 480));

    expect(landscape.shouldRepaint(portrait), isTrue);
    expect(
      PosePainter(const [], const Size(480, 640)).shouldRepaint(portrait),
      isFalse,
    );
    expect(
      PosePainter(
        const [],
        const Size(480, 640),
        emphasizedSide: 'right',
      ).shouldRepaint(portrait),
      isTrue,
    );
    expect(
      PosePainter(
        const [],
        const Size(480, 640),
        isFormBad: true,
      ).shouldRepaint(portrait),
      isTrue,
    );
  });

  test('does not repaint for visually equivalent side values', () {
    final lowerCase = PosePainter(
      const [],
      const Size(480, 640),
      emphasizedSide: 'left',
    );
    final normalizedEquivalent = PosePainter(
      const [],
      const Size(480, 640),
      emphasizedSide: ' LEFT ',
    );

    expect(normalizedEquivalent.shouldRepaint(lowerCase), isFalse);
  });

  testWidgets('paints all production overlay modes without exceptions', (
    tester,
  ) async {
    final variants = <PosePainter>[
      PosePainter(_landmarks, const Size(480, 640)),
      PosePainter(
        _landmarks,
        const Size(480, 640),
        isMirrored: true,
        showDebugLandmarks: true,
      ),
      PosePainter(_landmarks, const Size(480, 640), emphasizedSide: 'left'),
      PosePainter(
        _landmarks,
        const Size(480, 640),
        emphasizedSide: 'right',
        isFormBad: true,
      ),
    ];

    for (final painter in variants) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              child: SizedBox(
                width: 240,
                height: 320,
                child: CustomPaint(painter: painter),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('ignores invalid image dimensions instead of painting', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 240,
          height: 320,
          child: CustomPaint(painter: PosePainter(_landmarks, Size.zero)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

final List<PoseLandmark> _landmarks = <PoseLandmark>[
  _landmark(PoseLandmarkType.nose, 240, 70),
  _landmark(PoseLandmarkType.leftShoulder, 175, 145),
  _landmark(PoseLandmarkType.rightShoulder, 305, 145),
  _landmark(PoseLandmarkType.leftElbow, 145, 235),
  _landmark(PoseLandmarkType.rightElbow, 335, 235),
  _landmark(PoseLandmarkType.leftWrist, 120, 320),
  _landmark(PoseLandmarkType.rightWrist, 360, 320),
  _landmark(PoseLandmarkType.leftHip, 195, 330),
  _landmark(PoseLandmarkType.rightHip, 285, 330),
  _landmark(PoseLandmarkType.leftKnee, 185, 455),
  _landmark(PoseLandmarkType.rightKnee, 295, 455),
  _landmark(PoseLandmarkType.leftAnkle, 175, 585),
  _landmark(PoseLandmarkType.rightAnkle, 305, 585),
];

PoseLandmark _landmark(PoseLandmarkType type, double x, double y) {
  return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);
}
