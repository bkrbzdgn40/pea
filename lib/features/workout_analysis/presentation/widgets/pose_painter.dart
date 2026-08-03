import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<PoseLandmark> landmarks;
  final Size absoluteImageSize;
  final bool isFormBad;
  final bool isMirrored;
  final bool showDebugLandmarks;
  final String? emphasizedSide;

  PosePainter(
    this.landmarks,
    this.absoluteImageSize, {
    this.isFormBad = false,
    this.isMirrored = false,
    this.showDebugLandmarks = false,
    this.emphasizedSide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseLineColor = const Color(0xFF61E6BE).withValues(alpha: 0.94);
    final formAccentColor = const Color(0xFFFFC857).withValues(alpha: 0.98);
    final jointColor = Colors.white.withValues(alpha: 0.94);
    final debugDotColor = Colors.white.withValues(alpha: 0.20);
    final selectedSideColor = const Color(0xFF65D8FF).withValues(alpha: 0.98);

    final skeletonGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = baseLineColor.withValues(alpha: 0.14);

    final skeletonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = baseLineColor;

    final spinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = baseLineColor.withValues(alpha: 0.56);

    final accentGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = formAccentColor.withValues(alpha: 0.18);

    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = formAccentColor;

    final jointPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = jointColor;

    final jointRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..isAntiAlias = true
      ..color = baseLineColor.withValues(alpha: 0.82);

    final accentJointPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = formAccentColor;

    final accentJointRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..isAntiAlias = true
      ..color = formAccentColor.withValues(alpha: 0.88);

    final selectedSideGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = selectedSideColor.withValues(alpha: 0.18);

    final selectedSidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = selectedSideColor;

    final selectedSideJointPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = selectedSideColor;

    final selectedSideJointRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = true
      ..color = selectedSideColor.withValues(alpha: 0.92);

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

    void drawJointWithRing(
      PoseLandmarkType type, {
      required Paint fill,
      required Paint ring,
      double fillRadius = 3.2,
      double ringRadius = 5.2,
    }) {
      drawJoint(type, ring, radius: ringRadius);
      drawJoint(type, fill, radius: fillRadius);
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

    for (final segment in _commonSkeletonSegments) {
      drawSegment(segment, skeletonGlowPaint);
    }
    drawLine(points[PoseLandmarkType.nose], shoulderCenter, skeletonGlowPaint);
    drawLine(shoulderCenter, hipCenter, skeletonGlowPaint);

    drawLine(points[PoseLandmarkType.nose], shoulderCenter, spinePaint);
    drawLine(shoulderCenter, hipCenter, spinePaint);

    for (final segment in _commonSkeletonSegments) {
      drawSegment(segment, skeletonPaint);
    }

    final selectedSegments = switch (emphasizedSide?.toLowerCase()) {
      'left' => _leftLegSegments,
      'right' => _rightLegSegments,
      _ => const <_PoseSegment>[],
    };
    final selectedJoints = switch (emphasizedSide?.toLowerCase()) {
      'left' => _leftLegJoints,
      'right' => _rightLegJoints,
      _ => const <PoseLandmarkType>[],
    };
    for (final segment in selectedSegments) {
      drawSegment(segment, selectedSideGlowPaint);
      drawSegment(segment, selectedSidePaint);
    }

    if (isFormBad) {
      for (final segment in _accentSkeletonSegments) {
        drawSegment(segment, accentGlowPaint);
        drawSegment(segment, accentPaint);
      }
      drawLine(points[PoseLandmarkType.nose], shoulderCenter, accentGlowPaint);
      drawLine(shoulderCenter, hipCenter, accentGlowPaint);
      drawLine(points[PoseLandmarkType.nose], shoulderCenter, accentPaint);
      drawLine(shoulderCenter, hipCenter, accentPaint);
    }

    for (final joint in _visibleJointTypes) {
      drawJointWithRing(joint, fill: jointPaint, ring: jointRingPaint);
    }

    for (final joint in selectedJoints) {
      drawJointWithRing(
        joint,
        fill: selectedSideJointPaint,
        ring: selectedSideJointRingPaint,
        fillRadius: 4.4,
        ringRadius: 6.3,
      );
    }

    if (isFormBad) {
      for (final joint in _accentJointTypes) {
        drawJointWithRing(
          joint,
          fill: accentJointPaint,
          ring: accentJointRingPaint,
          fillRadius: 3.8,
          ringRadius: 5.9,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.landmarks != landmarks ||
        oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.isFormBad != isFormBad ||
        oldDelegate.isMirrored != isMirrored ||
        oldDelegate.showDebugLandmarks != showDebugLandmarks ||
        oldDelegate.emphasizedSide != emphasizedSide;
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

const List<_PoseSegment> _leftLegSegments = [
  _PoseSegment(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
  _PoseSegment(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
];

const List<_PoseSegment> _rightLegSegments = [
  _PoseSegment(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
  _PoseSegment(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
];

const List<PoseLandmarkType> _leftLegJoints = [
  PoseLandmarkType.leftHip,
  PoseLandmarkType.leftKnee,
  PoseLandmarkType.leftAnkle,
];

const List<PoseLandmarkType> _rightLegJoints = [
  PoseLandmarkType.rightHip,
  PoseLandmarkType.rightKnee,
  PoseLandmarkType.rightAnkle,
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
