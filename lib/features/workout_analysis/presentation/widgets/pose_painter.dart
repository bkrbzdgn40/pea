import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<PoseLandmark> landmarks;
  final Size absoluteImageSize;
  final bool isFormBad;
  final bool isMirrored;

  PosePainter(
    this.landmarks,
    this.absoluteImageSize, {
    this.isFormBad = false,
    this.isMirrored = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = isFormBad ? Colors.redAccent : Colors.greenAccent;

    final paintDot = Paint()
      ..style = PaintingStyle.fill
      ..color = isFormBad ? Colors.orange : Colors.redAccent;

    double translateX(double x) {
      final scaledX = x * size.width / absoluteImageSize.width;
      return isMirrored ? size.width - scaledX : scaledX;
    }

    double translateY(double y) {
      return y * size.height / absoluteImageSize.height;
    }

    for (final landmark in landmarks) {
      canvas.drawCircle(
        Offset(translateX(landmark.x), translateY(landmark.y)),
        5,
        paintDot,
      );
    }

    void drawConnection(PoseLandmarkType type1, PoseLandmarkType type2) {
      try {
        final l1 = landmarks.firstWhere((l) => l.type == type1);
        final l2 = landmarks.firstWhere((l) => l.type == type2);

        canvas.drawLine(
          Offset(translateX(l1.x), translateY(l1.y)),
          Offset(translateX(l2.x), translateY(l2.y)),
          paintLine,
        );
      } catch (_) {}
    }

    drawConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawConnection(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawConnection(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);

    drawConnection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawConnection(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawConnection(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    drawConnection(
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    );
    drawConnection(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.landmarks != landmarks ||
        oldDelegate.isFormBad != isFormBad ||
        oldDelegate.isMirrored != isMirrored;
  }
}
