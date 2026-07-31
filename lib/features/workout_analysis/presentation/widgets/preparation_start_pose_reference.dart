import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/preparation_pose_guide.dart';
import '../providers/preparation_camera_controller.dart';

class PreparationStartPoseReference extends ConsumerWidget {
  const PreparationStartPoseReference({
    required this.template,
    required this.title,
    super.key,
  });

  final PreparationPoseTemplate template;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrackedPose = ref.watch(
      preparationCameraControllerProvider.select(
        (state) => state.landmarks.isNotEmpty,
      ),
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          key: const ValueKey<String>('preparation-start-pose-opacity'),
          duration: const Duration(milliseconds: 180),
          opacity: hasTrackedPose ? 0.28 : 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    key: const ValueKey<String>('preparation-start-pose-chip'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.56),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.accessibility_new_rounded,
                          color: Color(0xFFB9F3E7),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            title,
                            key: const ValueKey<String>(
                              'preparation-start-pose-title',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                CustomPaint(
                  key: const ValueKey<String>(
                    'preparation-start-pose-reference',
                  ),
                  painter: _PreparationStartPoseReferencePainter(template),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreparationStartPoseReferencePainter extends CustomPainter {
  const _PreparationStartPoseReferencePainter(this.template);

  final PreparationPoseTemplate template;

  @override
  void paint(Canvas canvas, Size size) {
    final ghostPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = const Color(0xFFB9F3E7).withValues(alpha: 0.32);

    final jointPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = Colors.white.withValues(alpha: 0.32);

    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = true
      ..color = const Color(0xFFB9F3E7).withValues(alpha: 0.18);

    final supportFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = const Color(0xFFB9F3E7).withValues(alpha: 0.08);

    final frame =
        Offset(size.width * 0.08, size.height * 0.06) &
        Size(size.width * 0.84, size.height * 0.88);

    final points = _templatePoints(template, frame);

    Offset? midpoint(_GuideJoint a, _GuideJoint b) {
      final first = points[a];
      final second = points[b];
      if (first == null || second == null) {
        return null;
      }
      return Offset((first.dx + second.dx) / 2, (first.dy + second.dy) / 2);
    }

    void drawSegment(_GuideJoint start, _GuideJoint end, {Paint? paint}) {
      final a = points[start];
      final b = points[end];
      if (a == null || b == null) {
        return;
      }
      canvas.drawLine(a, b, paint ?? ghostPaint);
    }

    void drawJoint(_GuideJoint joint, {double radius = 4}) {
      final point = points[joint];
      if (point == null) {
        return;
      }
      canvas.drawCircle(point, radius, jointPaint);
    }

    if (template == PreparationPoseTemplate.wallSupportedHold) {
      final wallX = frame.left + frame.width * 0.24;
      canvas.drawLine(
        Offset(wallX, frame.top + frame.height * 0.12),
        Offset(wallX, frame.bottom - frame.height * 0.06),
        accentPaint,
      );
    }
    if (template == PreparationPoseTemplate.benchDipSetup) {
      final seat = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          frame.left + frame.width * 0.59,
          frame.top + frame.height * 0.49,
          frame.left + frame.width * 0.90,
          frame.top + frame.height * 0.57,
        ),
        const Radius.circular(8),
      );
      final frontLeg = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          frame.left + frame.width * 0.64,
          frame.top + frame.height * 0.57,
          frame.left + frame.width * 0.69,
          frame.top + frame.height * 0.84,
        ),
        const Radius.circular(5),
      );
      final rearLeg = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          frame.left + frame.width * 0.84,
          frame.top + frame.height * 0.57,
          frame.left + frame.width * 0.89,
          frame.top + frame.height * 0.84,
        ),
        const Radius.circular(5),
      );

      canvas.drawRRect(seat, supportFillPaint);
      canvas.drawRRect(seat, accentPaint);
      canvas.drawRRect(frontLeg, supportFillPaint);
      canvas.drawRRect(frontLeg, accentPaint);
      canvas.drawRRect(rearLeg, supportFillPaint);
      canvas.drawRRect(rearLeg, accentPaint);
      canvas.drawLine(
        Offset(
          frame.left + frame.width * 0.08,
          frame.top + frame.height * 0.84,
        ),
        Offset(
          frame.left + frame.width * 0.92,
          frame.top + frame.height * 0.84,
        ),
        accentPaint,
      );
    }
    if (template == PreparationPoseTemplate.dipSupport) {
      final seatTop = frame.top + frame.height * 0.52;
      final seatLeft = frame.left + frame.width * 0.30;
      final seatRight = frame.left + frame.width * 0.58;
      canvas.drawLine(
        Offset(seatLeft, seatTop),
        Offset(seatRight, seatTop),
        accentPaint,
      );
      canvas.drawLine(
        Offset(seatLeft, seatTop),
        Offset(seatLeft, seatTop + frame.height * 0.22),
        accentPaint,
      );
      canvas.drawLine(
        Offset(seatRight, seatTop),
        Offset(seatRight, seatTop + frame.height * 0.22),
        accentPaint,
      );
    }

    final shoulderCenter = midpoint(
      _GuideJoint.leftShoulder,
      _GuideJoint.rightShoulder,
    );
    final hipCenter = midpoint(_GuideJoint.leftHip, _GuideJoint.rightHip);
    final nose = points[_GuideJoint.nose];
    if (nose != null && shoulderCenter != null) {
      canvas.drawLine(nose, shoulderCenter, ghostPaint..strokeWidth = 4);
      ghostPaint.strokeWidth = 5;
    }
    if (shoulderCenter != null && hipCenter != null) {
      canvas.drawLine(shoulderCenter, hipCenter, ghostPaint..strokeWidth = 4);
      ghostPaint.strokeWidth = 5;
    }

    for (final segment in _segments) {
      drawSegment(segment.$1, segment.$2);
    }

    for (final joint in points.keys) {
      drawJoint(joint);
    }
  }

  @override
  bool shouldRepaint(
    covariant _PreparationStartPoseReferencePainter oldDelegate,
  ) {
    return oldDelegate.template != template;
  }
}

enum _GuideJoint {
  nose,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

const List<(_GuideJoint, _GuideJoint)> _segments = [
  (_GuideJoint.leftShoulder, _GuideJoint.rightShoulder),
  (_GuideJoint.leftShoulder, _GuideJoint.leftElbow),
  (_GuideJoint.leftElbow, _GuideJoint.leftWrist),
  (_GuideJoint.rightShoulder, _GuideJoint.rightElbow),
  (_GuideJoint.rightElbow, _GuideJoint.rightWrist),
  (_GuideJoint.leftShoulder, _GuideJoint.leftHip),
  (_GuideJoint.rightShoulder, _GuideJoint.rightHip),
  (_GuideJoint.leftHip, _GuideJoint.rightHip),
  (_GuideJoint.leftHip, _GuideJoint.leftKnee),
  (_GuideJoint.leftKnee, _GuideJoint.leftAnkle),
  (_GuideJoint.rightHip, _GuideJoint.rightKnee),
  (_GuideJoint.rightKnee, _GuideJoint.rightAnkle),
];

Map<_GuideJoint, Offset> _templatePoints(
  PreparationPoseTemplate template,
  Rect frame,
) {
  Offset p(double x, double y) =>
      Offset(frame.left + frame.width * x, frame.top + frame.height * y);

  switch (template) {
    case PreparationPoseTemplate.standingNeutralSide:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.56, 0.10),
        _GuideJoint.leftShoulder: p(0.52, 0.18),
        _GuideJoint.rightShoulder: p(0.58, 0.19),
        _GuideJoint.leftElbow: p(0.51, 0.32),
        _GuideJoint.rightElbow: p(0.59, 0.33),
        _GuideJoint.leftWrist: p(0.50, 0.46),
        _GuideJoint.rightWrist: p(0.60, 0.47),
        _GuideJoint.leftHip: p(0.51, 0.43),
        _GuideJoint.rightHip: p(0.57, 0.44),
        _GuideJoint.leftKnee: p(0.52, 0.65),
        _GuideJoint.rightKnee: p(0.58, 0.66),
        _GuideJoint.leftAnkle: p(0.53, 0.90),
        _GuideJoint.rightAnkle: p(0.59, 0.91),
      };
    case PreparationPoseTemplate.standingArmsDownSide:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.52, 0.10),
        _GuideJoint.leftShoulder: p(0.47, 0.18),
        _GuideJoint.rightShoulder: p(0.57, 0.18),
        _GuideJoint.leftElbow: p(0.42, 0.36),
        _GuideJoint.rightElbow: p(0.61, 0.36),
        _GuideJoint.leftWrist: p(0.40, 0.52),
        _GuideJoint.rightWrist: p(0.63, 0.52),
        _GuideJoint.leftHip: p(0.47, 0.42),
        _GuideJoint.rightHip: p(0.57, 0.42),
        _GuideJoint.leftKnee: p(0.47, 0.65),
        _GuideJoint.rightKnee: p(0.57, 0.65),
        _GuideJoint.leftAnkle: p(0.47, 0.90),
        _GuideJoint.rightAnkle: p(0.57, 0.90),
      };
    case PreparationPoseTemplate.standingArmsDownFront:
    case PreparationPoseTemplate.dynamicBilateralNeutral:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.50, 0.10),
        _GuideJoint.leftShoulder: p(0.38, 0.18),
        _GuideJoint.rightShoulder: p(0.62, 0.18),
        _GuideJoint.leftElbow: p(0.34, 0.36),
        _GuideJoint.rightElbow: p(0.66, 0.36),
        _GuideJoint.leftWrist: p(0.32, 0.54),
        _GuideJoint.rightWrist: p(0.68, 0.54),
        _GuideJoint.leftHip: p(0.42, 0.42),
        _GuideJoint.rightHip: p(0.58, 0.42),
        _GuideJoint.leftKnee: p(0.43, 0.66),
        _GuideJoint.rightKnee: p(0.57, 0.66),
        _GuideJoint.leftAnkle: p(0.42, 0.90),
        _GuideJoint.rightAnkle: p(0.58, 0.90),
      };
    case PreparationPoseTemplate.standingElbowsBentFront:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.50, 0.10),
        _GuideJoint.leftShoulder: p(0.41, 0.18),
        _GuideJoint.rightShoulder: p(0.59, 0.18),
        _GuideJoint.leftElbow: p(0.44, 0.12),
        _GuideJoint.rightElbow: p(0.56, 0.12),
        _GuideJoint.leftWrist: p(0.46, 0.04),
        _GuideJoint.rightWrist: p(0.54, 0.04),
        _GuideJoint.leftHip: p(0.43, 0.42),
        _GuideJoint.rightHip: p(0.57, 0.42),
        _GuideJoint.leftKnee: p(0.44, 0.66),
        _GuideJoint.rightKnee: p(0.56, 0.66),
        _GuideJoint.leftAnkle: p(0.43, 0.90),
        _GuideJoint.rightAnkle: p(0.57, 0.90),
      };
    case PreparationPoseTemplate.shoulderPressRack:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.50, 0.10),
        _GuideJoint.leftShoulder: p(0.40, 0.18),
        _GuideJoint.rightShoulder: p(0.60, 0.18),
        _GuideJoint.leftElbow: p(0.33, 0.28),
        _GuideJoint.rightElbow: p(0.67, 0.28),
        _GuideJoint.leftWrist: p(0.33, 0.17),
        _GuideJoint.rightWrist: p(0.67, 0.17),
        _GuideJoint.leftHip: p(0.42, 0.42),
        _GuideJoint.rightHip: p(0.58, 0.42),
        _GuideJoint.leftKnee: p(0.43, 0.66),
        _GuideJoint.rightKnee: p(0.57, 0.66),
        _GuideJoint.leftAnkle: p(0.42, 0.90),
        _GuideJoint.rightAnkle: p(0.58, 0.90),
      };
    case PreparationPoseTemplate.splitStanceSide:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.52, 0.12),
        _GuideJoint.leftShoulder: p(0.48, 0.20),
        _GuideJoint.rightShoulder: p(0.56, 0.21),
        _GuideJoint.leftElbow: p(0.46, 0.34),
        _GuideJoint.rightElbow: p(0.58, 0.35),
        _GuideJoint.leftWrist: p(0.45, 0.48),
        _GuideJoint.rightWrist: p(0.59, 0.49),
        _GuideJoint.leftHip: p(0.48, 0.44),
        _GuideJoint.rightHip: p(0.56, 0.45),
        _GuideJoint.leftKnee: p(0.44, 0.66),
        _GuideJoint.rightKnee: p(0.60, 0.62),
        _GuideJoint.leftAnkle: p(0.40, 0.90),
        _GuideJoint.rightAnkle: p(0.64, 0.86),
      };
    case PreparationPoseTemplate.stationaryLungeSetup:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.50, 0.10),
        _GuideJoint.leftShoulder: p(0.46, 0.18),
        _GuideJoint.rightShoulder: p(0.54, 0.19),
        _GuideJoint.leftElbow: p(0.44, 0.35),
        _GuideJoint.rightElbow: p(0.56, 0.36),
        _GuideJoint.leftWrist: p(0.43, 0.51),
        _GuideJoint.rightWrist: p(0.57, 0.52),
        _GuideJoint.leftHip: p(0.46, 0.42),
        _GuideJoint.rightHip: p(0.54, 0.43),
        _GuideJoint.leftKnee: p(0.35, 0.64),
        _GuideJoint.rightKnee: p(0.62, 0.64),
        _GuideJoint.leftAnkle: p(0.23, 0.88),
        _GuideJoint.rightAnkle: p(0.74, 0.88),
      };
    case PreparationPoseTemplate.floorProneSupport:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.28, 0.30),
        _GuideJoint.leftShoulder: p(0.34, 0.36),
        _GuideJoint.rightShoulder: p(0.38, 0.39),
        _GuideJoint.leftElbow: p(0.28, 0.48),
        _GuideJoint.rightElbow: p(0.33, 0.50),
        _GuideJoint.leftWrist: p(0.24, 0.58),
        _GuideJoint.rightWrist: p(0.29, 0.60),
        _GuideJoint.leftHip: p(0.57, 0.41),
        _GuideJoint.rightHip: p(0.61, 0.44),
        _GuideJoint.leftKnee: p(0.74, 0.45),
        _GuideJoint.rightKnee: p(0.78, 0.48),
        _GuideJoint.leftAnkle: p(0.88, 0.48),
        _GuideJoint.rightAnkle: p(0.92, 0.51),
      };
    case PreparationPoseTemplate.floorSupineStraight:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.82, 0.45),
        _GuideJoint.leftShoulder: p(0.72, 0.46),
        _GuideJoint.rightShoulder: p(0.71, 0.53),
        _GuideJoint.leftElbow: p(0.62, 0.54),
        _GuideJoint.rightElbow: p(0.59, 0.62),
        _GuideJoint.leftWrist: p(0.50, 0.56),
        _GuideJoint.rightWrist: p(0.43, 0.66),
        _GuideJoint.leftHip: p(0.51, 0.52),
        _GuideJoint.rightHip: p(0.50, 0.58),
        _GuideJoint.leftKnee: p(0.29, 0.52),
        _GuideJoint.rightKnee: p(0.29, 0.58),
        _GuideJoint.leftAnkle: p(0.10, 0.52),
        _GuideJoint.rightAnkle: p(0.10, 0.58),
      };
    case PreparationPoseTemplate.floorSupineBentKnees:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.82, 0.45),
        _GuideJoint.leftShoulder: p(0.72, 0.46),
        _GuideJoint.rightShoulder: p(0.71, 0.53),
        _GuideJoint.leftElbow: p(0.62, 0.54),
        _GuideJoint.rightElbow: p(0.59, 0.62),
        _GuideJoint.leftWrist: p(0.50, 0.56),
        _GuideJoint.rightWrist: p(0.43, 0.66),
        _GuideJoint.leftHip: p(0.51, 0.52),
        _GuideJoint.rightHip: p(0.50, 0.58),
        _GuideJoint.leftKnee: p(0.29, 0.31),
        _GuideJoint.rightKnee: p(0.30, 0.33),
        _GuideJoint.leftAnkle: p(0.15, 0.49),
        _GuideJoint.rightAnkle: p(0.16, 0.54),
      };
    case PreparationPoseTemplate.floorSupineBentKneeRaiseSetup:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.82, 0.45),
        _GuideJoint.leftShoulder: p(0.72, 0.47),
        _GuideJoint.rightShoulder: p(0.71, 0.53),
        _GuideJoint.leftElbow: p(0.62, 0.54),
        _GuideJoint.rightElbow: p(0.59, 0.62),
        _GuideJoint.leftWrist: p(0.50, 0.56),
        _GuideJoint.rightWrist: p(0.43, 0.66),
        _GuideJoint.leftHip: p(0.50, 0.54),
        _GuideJoint.rightHip: p(0.50, 0.59),
        _GuideJoint.leftKnee: p(0.33, 0.36),
        _GuideJoint.rightKnee: p(0.33, 0.40),
        _GuideJoint.leftAnkle: p(0.23, 0.48),
        _GuideJoint.rightAnkle: p(0.23, 0.53),
      };
    case PreparationPoseTemplate.floorSupineFrogPumpSetup:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.82, 0.45),
        _GuideJoint.leftShoulder: p(0.72, 0.47),
        _GuideJoint.rightShoulder: p(0.71, 0.53),
        _GuideJoint.leftElbow: p(0.62, 0.54),
        _GuideJoint.rightElbow: p(0.59, 0.62),
        _GuideJoint.leftWrist: p(0.50, 0.56),
        _GuideJoint.rightWrist: p(0.43, 0.66),
        _GuideJoint.leftHip: p(0.50, 0.54),
        _GuideJoint.rightHip: p(0.50, 0.59),
        _GuideJoint.leftKnee: p(0.32, 0.42),
        _GuideJoint.rightKnee: p(0.32, 0.67),
        _GuideJoint.leftAnkle: p(0.20, 0.54),
        _GuideJoint.rightAnkle: p(0.20, 0.59),
      };
    case PreparationPoseTemplate.floorSupineTabletop:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.20, 0.58),
        _GuideJoint.leftShoulder: p(0.27, 0.55),
        _GuideJoint.rightShoulder: p(0.27, 0.62),
        _GuideJoint.leftElbow: p(0.20, 0.47),
        _GuideJoint.rightElbow: p(0.20, 0.69),
        _GuideJoint.leftWrist: p(0.15, 0.42),
        _GuideJoint.rightWrist: p(0.15, 0.74),
        _GuideJoint.leftHip: p(0.46, 0.55),
        _GuideJoint.rightHip: p(0.46, 0.62),
        _GuideJoint.leftKnee: p(0.58, 0.40),
        _GuideJoint.rightKnee: p(0.58, 0.77),
        _GuideJoint.leftAnkle: p(0.69, 0.40),
        _GuideJoint.rightAnkle: p(0.69, 0.77),
      };
    case PreparationPoseTemplate.floorSupineBridgeSetup:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.20, 0.58),
        _GuideJoint.leftShoulder: p(0.27, 0.55),
        _GuideJoint.rightShoulder: p(0.27, 0.62),
        _GuideJoint.leftElbow: p(0.30, 0.47),
        _GuideJoint.rightElbow: p(0.30, 0.69),
        _GuideJoint.leftWrist: p(0.37, 0.45),
        _GuideJoint.rightWrist: p(0.37, 0.72),
        _GuideJoint.leftHip: p(0.46, 0.55),
        _GuideJoint.rightHip: p(0.46, 0.62),
        _GuideJoint.leftKnee: p(0.63, 0.44),
        _GuideJoint.rightKnee: p(0.63, 0.73),
        _GuideJoint.leftAnkle: p(0.57, 0.55),
        _GuideJoint.rightAnkle: p(0.57, 0.62),
      };
    case PreparationPoseTemplate.floorSupineElbowsBentOverhead:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.82, 0.45),
        _GuideJoint.leftShoulder: p(0.72, 0.46),
        _GuideJoint.rightShoulder: p(0.71, 0.53),
        _GuideJoint.leftElbow: p(0.66, 0.31),
        _GuideJoint.rightElbow: p(0.64, 0.38),
        _GuideJoint.leftWrist: p(0.77, 0.25),
        _GuideJoint.rightWrist: p(0.75, 0.32),
        _GuideJoint.leftHip: p(0.51, 0.52),
        _GuideJoint.rightHip: p(0.50, 0.58),
        _GuideJoint.leftKnee: p(0.29, 0.31),
        _GuideJoint.rightKnee: p(0.30, 0.33),
        _GuideJoint.leftAnkle: p(0.15, 0.49),
        _GuideJoint.rightAnkle: p(0.16, 0.54),
      };
    case PreparationPoseTemplate.floorSupineChestPress:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.82, 0.45),
        _GuideJoint.leftShoulder: p(0.72, 0.48),
        _GuideJoint.rightShoulder: p(0.71, 0.54),
        _GuideJoint.leftElbow: p(0.58, 0.48),
        _GuideJoint.rightElbow: p(0.58, 0.54),
        _GuideJoint.leftWrist: p(0.58, 0.34),
        _GuideJoint.rightWrist: p(0.58, 0.40),
        _GuideJoint.leftHip: p(0.50, 0.54),
        _GuideJoint.rightHip: p(0.50, 0.59),
        _GuideJoint.leftKnee: p(0.30, 0.36),
        _GuideJoint.rightKnee: p(0.30, 0.40),
        _GuideJoint.leftAnkle: p(0.17, 0.54),
        _GuideJoint.rightAnkle: p(0.17, 0.59),
      };
    case PreparationPoseTemplate.wallSupportedHold:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.28, 0.18),
        _GuideJoint.leftShoulder: p(0.31, 0.25),
        _GuideJoint.rightShoulder: p(0.38, 0.25),
        _GuideJoint.leftElbow: p(0.30, 0.38),
        _GuideJoint.rightElbow: p(0.39, 0.38),
        _GuideJoint.leftWrist: p(0.29, 0.50),
        _GuideJoint.rightWrist: p(0.40, 0.50),
        _GuideJoint.leftHip: p(0.33, 0.47),
        _GuideJoint.rightHip: p(0.40, 0.47),
        _GuideJoint.leftKnee: p(0.55, 0.65),
        _GuideJoint.rightKnee: p(0.62, 0.65),
        _GuideJoint.leftAnkle: p(0.55, 0.88),
        _GuideJoint.rightAnkle: p(0.62, 0.88),
      };
    case PreparationPoseTemplate.sideSupport:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.30, 0.30),
        _GuideJoint.leftShoulder: p(0.35, 0.36),
        _GuideJoint.rightShoulder: p(0.39, 0.41),
        _GuideJoint.leftElbow: p(0.28, 0.48),
        _GuideJoint.rightElbow: p(0.34, 0.52),
        _GuideJoint.leftWrist: p(0.22, 0.60),
        _GuideJoint.rightWrist: p(0.30, 0.63),
        _GuideJoint.leftHip: p(0.56, 0.41),
        _GuideJoint.rightHip: p(0.60, 0.46),
        _GuideJoint.leftKnee: p(0.74, 0.46),
        _GuideJoint.rightKnee: p(0.78, 0.50),
        _GuideJoint.leftAnkle: p(0.89, 0.50),
        _GuideJoint.rightAnkle: p(0.93, 0.54),
      };
    case PreparationPoseTemplate.benchDipSetup:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.47, 0.22),
        _GuideJoint.leftShoulder: p(0.48, 0.31),
        _GuideJoint.rightShoulder: p(0.52, 0.34),
        _GuideJoint.leftElbow: p(0.55, 0.40),
        _GuideJoint.rightElbow: p(0.58, 0.42),
        _GuideJoint.leftWrist: p(0.59, 0.49),
        _GuideJoint.rightWrist: p(0.62, 0.51),
        _GuideJoint.leftHip: p(0.45, 0.50),
        _GuideJoint.rightHip: p(0.49, 0.53),
        _GuideJoint.leftKnee: p(0.31, 0.61),
        _GuideJoint.rightKnee: p(0.34, 0.64),
        _GuideJoint.leftAnkle: p(0.14, 0.73),
        _GuideJoint.rightAnkle: p(0.17, 0.76),
      };
    case PreparationPoseTemplate.dipSupport:
      return <_GuideJoint, Offset>{
        _GuideJoint.nose: p(0.38, 0.28),
        _GuideJoint.leftShoulder: p(0.36, 0.36),
        _GuideJoint.rightShoulder: p(0.44, 0.36),
        _GuideJoint.leftElbow: p(0.32, 0.50),
        _GuideJoint.rightElbow: p(0.48, 0.50),
        _GuideJoint.leftWrist: p(0.30, 0.60),
        _GuideJoint.rightWrist: p(0.50, 0.60),
        _GuideJoint.leftHip: p(0.40, 0.52),
        _GuideJoint.rightHip: p(0.48, 0.52),
        _GuideJoint.leftKnee: p(0.56, 0.68),
        _GuideJoint.rightKnee: p(0.64, 0.68),
        _GuideJoint.leftAnkle: p(0.70, 0.86),
        _GuideJoint.rightAnkle: p(0.80, 0.86),
      };
  }
}
