import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<PoseLandmark> landmarks;
  final Size absoluteImageSize;
  final bool isFormBad;
  final bool isMirrored;
  final bool showDebugLandmarks;
  final String? emphasizedSide;
  final _PoseEmphasis _emphasis;

  PosePainter(
    this.landmarks,
    this.absoluteImageSize, {
    this.isFormBad = false,
    this.isMirrored = false,
    this.showDebugLandmarks = false,
    this.emphasizedSide,
  }) : _emphasis = _PoseEmphasis.parse(emphasizedSide);

  static final Paint _skeletonGlowPaint = _strokePaint(
    color: const Color(0xFF61E6BE).withValues(alpha: 0.14),
    strokeWidth: 7.5,
  );
  static final Paint _skeletonPaint = _strokePaint(
    color: const Color(0xFF61E6BE).withValues(alpha: 0.94),
    strokeWidth: 3.1,
  );
  static final Paint _spinePaint = _strokePaint(
    color: const Color(0xFF61E6BE).withValues(alpha: 0.56),
    strokeWidth: 2.4,
  );
  static final Paint _accentGlowPaint = _strokePaint(
    color: const Color(0xFFFFC857).withValues(alpha: 0.18),
    strokeWidth: 8.5,
  );
  static final Paint _accentPaint = _strokePaint(
    color: const Color(0xFFFFC857).withValues(alpha: 0.98),
    strokeWidth: 3.8,
  );
  static final Paint _jointPaint = _fillPaint(
    Colors.white.withValues(alpha: 0.94),
  );
  static final Paint _jointRingPaint = _ringPaint(
    color: const Color(0xFF61E6BE).withValues(alpha: 0.82),
    strokeWidth: 1.35,
  );
  static final Paint _accentJointPaint = _fillPaint(
    const Color(0xFFFFC857).withValues(alpha: 0.98),
  );
  static final Paint _accentJointRingPaint = _ringPaint(
    color: const Color(0xFFFFC857).withValues(alpha: 0.88),
    strokeWidth: 1.7,
  );
  static final Paint _selectedSideGlowPaint = _strokePaint(
    color: const Color(0xFF65D8FF).withValues(alpha: 0.18),
    strokeWidth: 10.5,
  );
  static final Paint _selectedSidePaint = _strokePaint(
    color: const Color(0xFF65D8FF).withValues(alpha: 0.98),
    strokeWidth: 5.2,
  );
  static final Paint _selectedSideJointPaint = _fillPaint(
    const Color(0xFF65D8FF).withValues(alpha: 0.98),
  );
  static final Paint _selectedSideJointRingPaint = _ringPaint(
    color: const Color(0xFF65D8FF).withValues(alpha: 0.92),
    strokeWidth: 2,
  );
  static final Paint _debugDotPaint = _fillPaint(
    Colors.white.withValues(alpha: 0.20),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty ||
        size.isEmpty ||
        absoluteImageSize.width <= 0 ||
        absoluteImageSize.height <= 0) {
      return;
    }

    final geometry = _PoseGeometry.fromLandmarks(
      landmarks: landmarks,
      imageSize: absoluteImageSize,
      canvasSize: size,
      isMirrored: isMirrored,
    );

    if (showDebugLandmarks) {
      canvas.drawPath(geometry.allLandmarksPath(radius: 2.1), _debugDotPaint);
    }

    final shoulderCenter = geometry.midpoint(
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    );
    final hipCenter = geometry.midpoint(
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    );
    final commonSkeletonPath = geometry.segmentPath(_commonSkeletonSegments);
    final spinePath = Path();
    _appendLine(spinePath, geometry[PoseLandmarkType.nose], shoulderCenter);
    _appendLine(spinePath, shoulderCenter, hipCenter);

    canvas
      ..drawPath(commonSkeletonPath, _skeletonGlowPaint)
      ..drawPath(spinePath, _skeletonGlowPaint)
      ..drawPath(spinePath, _spinePaint)
      ..drawPath(commonSkeletonPath, _skeletonPaint);

    final selectedSegments = _emphasis.segments;
    if (selectedSegments.isNotEmpty) {
      final selectedPath = geometry.segmentPath(selectedSegments);
      canvas
        ..drawPath(selectedPath, _selectedSideGlowPaint)
        ..drawPath(selectedPath, _selectedSidePaint);
    }

    if (isFormBad) {
      final accentPath = geometry.segmentPath(_accentSkeletonSegments);
      _appendLine(accentPath, geometry[PoseLandmarkType.nose], shoulderCenter);
      _appendLine(accentPath, shoulderCenter, hipCenter);
      canvas
        ..drawPath(accentPath, _accentGlowPaint)
        ..drawPath(accentPath, _accentPaint);
    }

    _drawJointGroup(
      canvas,
      geometry,
      _visibleJointTypes,
      fillPaint: _jointPaint,
      ringPaint: _jointRingPaint,
      fillRadius: 3.2,
      ringRadius: 5.2,
    );

    final selectedJoints = _emphasis.joints;
    if (selectedJoints.isNotEmpty) {
      _drawJointGroup(
        canvas,
        geometry,
        selectedJoints,
        fillPaint: _selectedSideJointPaint,
        ringPaint: _selectedSideJointRingPaint,
        fillRadius: 4.4,
        ringRadius: 6.3,
      );
    }

    if (isFormBad) {
      _drawJointGroup(
        canvas,
        geometry,
        _accentJointTypes,
        fillPaint: _accentJointPaint,
        ringPaint: _accentJointRingPaint,
        fillRadius: 3.8,
        ringRadius: 5.9,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.landmarks != landmarks ||
        oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.isFormBad != isFormBad ||
        oldDelegate.isMirrored != isMirrored ||
        oldDelegate.showDebugLandmarks != showDebugLandmarks ||
        oldDelegate._emphasis != _emphasis;
  }
}

Paint _strokePaint({required Color color, required double strokeWidth}) {
  return Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true
    ..color = color;
}

Paint _ringPaint({required Color color, required double strokeWidth}) {
  return Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..isAntiAlias = true
    ..color = color;
}

Paint _fillPaint(Color color) {
  return Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true
    ..color = color;
}

void _drawJointGroup(
  Canvas canvas,
  _PoseGeometry geometry,
  List<PoseLandmarkType> jointTypes, {
  required Paint fillPaint,
  required Paint ringPaint,
  required double fillRadius,
  required double ringRadius,
}) {
  canvas
    ..drawPath(geometry.jointPath(jointTypes, ringRadius), ringPaint)
    ..drawPath(geometry.jointPath(jointTypes, fillRadius), fillPaint);
}

void _appendLine(Path path, Offset? start, Offset? end) {
  if (start == null || end == null) {
    return;
  }

  path
    ..moveTo(start.dx, start.dy)
    ..lineTo(end.dx, end.dy);
}

class _PoseGeometry {
  _PoseGeometry(this._points);

  factory _PoseGeometry.fromLandmarks({
    required List<PoseLandmark> landmarks,
    required Size imageSize,
    required Size canvasSize,
    required bool isMirrored,
  }) {
    final points = List<Offset?>.filled(PoseLandmarkType.values.length, null);
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;

    for (final landmark in landmarks) {
      final scaledX = landmark.x * scaleX;
      points[landmark.type.index] = Offset(
        isMirrored ? canvasSize.width - scaledX : scaledX,
        landmark.y * scaleY,
      );
    }

    return _PoseGeometry(points);
  }

  final List<Offset?> _points;

  Offset? operator [](PoseLandmarkType type) => _points[type.index];

  Offset? midpoint(PoseLandmarkType firstType, PoseLandmarkType secondType) {
    final first = this[firstType];
    final second = this[secondType];
    if (first == null || second == null) {
      return null;
    }

    return Offset((first.dx + second.dx) / 2, (first.dy + second.dy) / 2);
  }

  Path segmentPath(List<_PoseSegment> segments) {
    final path = Path();
    for (final segment in segments) {
      _appendLine(path, this[segment.start], this[segment.end]);
    }
    return path;
  }

  Path jointPath(List<PoseLandmarkType> jointTypes, double radius) {
    final path = Path();
    for (final type in jointTypes) {
      final point = this[type];
      if (point != null) {
        path.addOval(Rect.fromCircle(center: point, radius: radius));
      }
    }
    return path;
  }

  Path allLandmarksPath({required double radius}) {
    final path = Path();
    for (final point in _points) {
      if (point != null) {
        path.addOval(Rect.fromCircle(center: point, radius: radius));
      }
    }
    return path;
  }
}

enum _PoseEmphasis {
  none(<_PoseSegment>[], <PoseLandmarkType>[]),
  left(_leftLegSegments, _leftLegJoints),
  right(_rightLegSegments, _rightLegJoints);

  const _PoseEmphasis(this.segments, this.joints);

  static _PoseEmphasis parse(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'left' => _PoseEmphasis.left,
      'right' => _PoseEmphasis.right,
      _ => _PoseEmphasis.none,
    };
  }

  final List<_PoseSegment> segments;
  final List<PoseLandmarkType> joints;
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
