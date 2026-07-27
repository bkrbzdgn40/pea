import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<PoseLandmark> landmarks;
  final Size absoluteImageSize;
  final bool isFormBad;
  final bool isMirrored;
  final bool showDebugLandmarks;

  PosePainter(
    this.landmarks,
    this.absoluteImageSize, {
    this.isFormBad = false,
    this.isMirrored = false,
    this.showDebugLandmarks = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseLineColor = const Color(0xFFB9F3E7).withValues(alpha: 0.84);
    final formAccentColor = const Color(0xFFFFBE78).withValues(alpha: 0.92);
    final jointColor = Colors.white.withValues(alpha: 0.86);
    final debugDotColor = Colors.white.withValues(alpha: 0.20);

    final skeletonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = baseLineColor;

    final spinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = baseLineColor.withValues(alpha: 0.46);

    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = formAccentColor;

    final jointPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = jointColor;

    final accentJointPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = formAccentColor;

    final debugDotPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = debugDotColor;

    double translateX(double x) {
      final scaledX = x * size.width / absoluteImageSize.width;
      return isMirrored ? size.width - scaledX : scaledX;
    }

    double translateY(double y) {
      return y * size.height / absoluteImageSize.height;
    }

    final points = <PoseLandmarkType, Offset>{};
    for (final landmark in landmarks) {
      points[landmark.type] = Offset(
        translateX(landmark.x),
        translateY(landmark.y),
      );
    }

    Offset? midpoint(PoseLandmarkType a, PoseLandmarkType b) {
      final first = points[a];
      final second = points[b];
      if (first == null || second == null) {
        return null;
      }

      return Offset((first.dx + second.dx) / 2, (first.dy + second.dy) / 2);
    }

    void drawLine(Offset? start, Offset? end, Paint paint) {
      if (start == null || end == null) {
        return;
      }

      canvas.drawLine(start, end, paint);
    }

    void drawSegment(_PoseSegment segment, Paint paint) {
      drawLine(points[segment.start], points[segment.end], paint);
    }

    void drawJoint(PoseLandmarkType type, Paint paint, {double radius = 3.2}) {
      final point = points[type];
      if (point == null) {
        return;
      }

      canvas.drawCircle(point, radius, paint);
    }

    if (showDebugLandmarks) {
      for (final point in points.values) {
        canvas.drawCircle(point, 2.1, debugDotPaint);
      }
    }

    final shoulderCenter = midpoint(
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    );
    final hipCenter = midpoint(
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    );

    drawLine(points[PoseLandmarkType.nose], shoulderCenter, spinePaint);
    drawLine(shoulderCenter, hipCenter, spinePaint);

    for (final segment in _commonSkeletonSegments) {
      drawSegment(segment, skeletonPaint);
    }

    if (isFormBad) {
      for (final segment in _accentSkeletonSegments) {
        drawSegment(segment, accentPaint);
      }
      drawLine(points[PoseLandmarkType.nose], shoulderCenter, accentPaint);
      drawLine(shoulderCenter, hipCenter, accentPaint);
    }

    for (final joint in _visibleJointTypes) {
      drawJoint(joint, jointPaint);
    }

    if (isFormBad) {
      for (final joint in _accentJointTypes) {
        drawJoint(joint, accentJointPaint, radius: 3.5);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.landmarks != landmarks ||
        oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.isFormBad != isFormBad ||
        oldDelegate.isMirrored != isMirrored ||
        oldDelegate.showDebugLandmarks != showDebugLandmarks;
  }
}

const List<_PoseSegment> _commonSkeletonSegments = [
  _PoseSegment(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
  _PoseSegment(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
  _PoseSegment(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
  _PoseSegment(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
  _PoseSegment(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
  _PoseSegment(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
  _PoseSegment(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
  _PoseSegment(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
  _PoseSegment(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
  _PoseSegment(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
  _PoseSegment(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
  _PoseSegment(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
];

const List<_PoseSegment> _accentSkeletonSegments = [
  _PoseSegment(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
  _PoseSegment(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
  _PoseSegment(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
  _PoseSegment(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
];

const List<PoseLandmarkType> _visibleJointTypes = [
  PoseLandmarkType.nose,
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.leftElbow,
  PoseLandmarkType.rightElbow,
  PoseLandmarkType.leftWrist,
  PoseLandmarkType.rightWrist,
  PoseLandmarkType.leftHip,
  PoseLandmarkType.rightHip,
  PoseLandmarkType.leftKnee,
  PoseLandmarkType.rightKnee,
  PoseLandmarkType.leftAnkle,
  PoseLandmarkType.rightAnkle,
];

const List<PoseLandmarkType> _accentJointTypes = [
  PoseLandmarkType.nose,
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.leftHip,
  PoseLandmarkType.rightHip,
];

class _PoseSegment {
  const _PoseSegment(this.start, this.end);

  final PoseLandmarkType start;
  final PoseLandmarkType end;
}
