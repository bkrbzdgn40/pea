import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/angle_calculator.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_contract.dart';
import 'engine_kind.dart';
import 'exercise_metrics.dart';

/// Converts a detected pose into the measurement signals the current engine uses.
class ExerciseMetricsExtractor {
  const ExerciseMetricsExtractor();

  ExerciseMetrics extract(
    Pose pose,
    ExerciseConfig config, {
    required EngineKind engineKind,
    RangeRepContract? rangeRepContract,
  }) {
    final effectiveRangeRepContract =
        rangeRepContract ?? RangeRepContracts.squat;
    final leftRangeRepMetrics = _extractRangeRepSideMetrics(
      pose,
      config,
      RangeRepSide.left,
      rangeRepContract: effectiveRangeRepContract,
    );
    final rightRangeRepMetrics = _extractRangeRepSideMetrics(
      pose,
      config,
      RangeRepSide.right,
      rangeRepContract: effectiveRangeRepContract,
    );
    final bodyLineAngle = _calculateBodyLineAngle(pose, engineKind);
    final armSupportAngle = _calculateArmSupportAngle(pose, engineKind);
    final legExtensionAngle = _calculateLegExtensionAngle(pose, engineKind);

    return ExerciseMetrics(
      primaryAngle: leftRangeRepMetrics.primaryAngle,
      formMetric: leftRangeRepMetrics.formMetric,
      hasPrimaryAngle: leftRangeRepMetrics.hasPrimaryAngle,
      hasFormMetric: leftRangeRepMetrics.hasFormMetric,
      bodyLineAngle: bodyLineAngle,
      armSupportAngle: armSupportAngle,
      legExtensionAngle: legExtensionAngle,
      hasPose: true,
      landmarks: pose.landmarks.values.toList(),
      leftRangeRepMetrics: leftRangeRepMetrics,
      rightRangeRepMetrics: rightRangeRepMetrics,
    );
  }

  RangeRepSideMetrics _extractRangeRepSideMetrics(
    Pose pose,
    ExerciseConfig config,
    RangeRepSide side, {
    required RangeRepContract rangeRepContract,
  }) {
    final primaryAngle = _tryCalculatePrimaryAngle(pose, config, side: side);
    final formMetric = _tryCalculateFormMetric(pose, side: side);
    final sideConfidence = _calculateRangeRepSideConfidence(
      pose,
      config,
      rangeRepContract: rangeRepContract,
      side: side,
      hasPrimaryAngle: primaryAngle != null,
      hasFormMetric: formMetric != null,
    );
    final formSignals = _extractRangeRepFormSignals(
      pose,
      config,
      rangeRepContract: rangeRepContract,
      side: side,
      primaryAngle: primaryAngle,
      formMetric: formMetric,
    );

    return RangeRepSideMetrics(
      side: side,
      primaryAngle: primaryAngle ?? 180.0,
      formMetric: formMetric ?? 90.0,
      hasPrimaryAngle: primaryAngle != null,
      hasFormMetric: formMetric != null,
      sideConfidence: sideConfidence,
      formSignals: formSignals,
    );
  }

  double _calculateRangeRepSideConfidence(
    Pose pose,
    ExerciseConfig config, {
    required RangeRepContract rangeRepContract,
    required RangeRepSide side,
    required bool hasPrimaryAngle,
    required bool hasFormMetric,
  }) {
    final requiresPrimaryMetric = rangeRepContract.supportsSignal(
      RangeRepSignal.primaryMetric,
    );
    final requiresFormMetric = rangeRepContract.supportsSignal(
      RangeRepSignal.formMetric,
    );
    final emitsDepthMetric = _canExtractContractAwareRangeRepFormSignal(
      config,
      rangeRepContract,
      RangeRepSignal.depthMetric,
    );
    final emitsPostureAngle = _canExtractContractAwareRangeRepFormSignal(
      config,
      rangeRepContract,
      RangeRepSignal.postureAngle,
    );
    final emitsAlignmentMetric = _canExtractContractAwareRangeRepFormSignal(
      config,
      rangeRepContract,
      RangeRepSignal.alignmentMetric,
    );
    final emitsEndRangeMetric = _canExtractContractAwareRangeRepFormSignal(
      config,
      rangeRepContract,
      RangeRepSignal.endRangeMetric,
    );
    final requiredLandmarks = <PoseLandmarkType>{};
    if (requiresPrimaryMetric || emitsDepthMetric || emitsEndRangeMetric) {
      requiredLandmarks.addAll(<PoseLandmarkType>{
        _landmarkTypeForSide(config.joint1, side),
        _landmarkTypeForSide(config.primaryJoint, side),
        _landmarkTypeForSide(config.joint2, side),
      });
    }
    if (requiresFormMetric || emitsPostureAngle) {
      requiredLandmarks.addAll(<PoseLandmarkType>{
        _landmarkTypeForSide(PoseLandmarkType.leftShoulder, side),
        _landmarkTypeForSide(PoseLandmarkType.leftHip, side),
        _landmarkTypeForSide(PoseLandmarkType.leftKnee, side),
      });
    }
    if (emitsAlignmentMetric) {
      requiredLandmarks.addAll(<PoseLandmarkType>{
        _landmarkTypeForSide(PoseLandmarkType.leftShoulder, side),
        _landmarkTypeForSide(PoseLandmarkType.leftHip, side),
        _landmarkTypeForSide(PoseLandmarkType.leftAnkle, side),
      });
    }
    final observedLandmarks = requiredLandmarks
        .where((landmarkType) => pose.landmarks[landmarkType] != null)
        .length;
    final landmarkCompleteness = requiredLandmarks.isEmpty
        ? 0.0
        : observedLandmarks / requiredLandmarks.length;
    final requiredSignalCount =
        (requiresPrimaryMetric ? 1 : 0) + (requiresFormMetric ? 1 : 0);
    final availableSignalCount =
        ((requiresPrimaryMetric && hasPrimaryAngle) ? 1 : 0) +
        ((requiresFormMetric && hasFormMetric) ? 1 : 0);
    final signalAvailability = requiredSignalCount == 0
        ? 0.0
        : availableSignalCount / requiredSignalCount;

    return ((landmarkCompleteness + signalAvailability) / 2.0)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  RangeRepFormSignals? _extractRangeRepFormSignals(
    Pose pose,
    ExerciseConfig config, {
    required RangeRepContract rangeRepContract,
    required RangeRepSide side,
    required double? primaryAngle,
    required double? formMetric,
  }) {
    if (!_supportsSquatFormSignals(config)) {
      return null;
    }

    // Reuse only the raw squat angles we already trust in this compatibility
    // step. More interpretive signals stay null until a later scoring pass.
    final signals = RangeRepFormSignals(
      torsoAngle: _canExtractContractAwareRangeRepFormSignal(
            config,
            rangeRepContract,
            RangeRepSignal.postureAngle,
          )
          ? formMetric
          : null,
      depthMetric: _canExtractContractAwareRangeRepFormSignal(
            config,
            rangeRepContract,
            RangeRepSignal.depthMetric,
          )
          ? primaryAngle
          : null,
      alignmentMetric: _canExtractContractAwareRangeRepFormSignal(
            config,
            rangeRepContract,
            RangeRepSignal.alignmentMetric,
          )
          ? _tryCalculateSideAngle(
              pose,
              side: side,
              first: PoseLandmarkType.leftShoulder,
              middle: PoseLandmarkType.leftHip,
              last: PoseLandmarkType.leftAnkle,
            )
          : null,
      stabilityMetric: null,
      lockoutMetric: _canExtractContractAwareRangeRepFormSignal(
            config,
            rangeRepContract,
            RangeRepSignal.endRangeMetric,
          )
          ? _tryCalculateSideAngle(
              pose,
              side: side,
              first: PoseLandmarkType.leftHip,
              middle: PoseLandmarkType.leftKnee,
              last: PoseLandmarkType.leftAnkle,
            )
          : null,
      bottomControlMetric: null,
    );

    return signals.hasAnyValue ? signals : null;
  }

  double? _tryCalculatePrimaryAngle(
    Pose pose,
    ExerciseConfig config, {
    required RangeRepSide side,
  }) {
    final p1 = pose.landmarks[_landmarkTypeForSide(config.joint1, side)];
    final mid = pose.landmarks[_landmarkTypeForSide(config.primaryJoint, side)];
    final p2 = pose.landmarks[_landmarkTypeForSide(config.joint2, side)];

    if (p1 != null && mid != null && p2 != null) {
      return AngleCalculator.calculate(
        math.Point(p1.x, p1.y),
        math.Point(mid.x, mid.y),
        math.Point(p2.x, p2.y),
      );
    }

    return null;
  }

  double? _tryCalculateFormMetric(Pose pose, {required RangeRepSide side}) {
    final shoulder = pose
        .landmarks[_landmarkTypeForSide(PoseLandmarkType.leftShoulder, side)];
    final hip =
        pose.landmarks[_landmarkTypeForSide(PoseLandmarkType.leftHip, side)];
    final knee =
        pose.landmarks[_landmarkTypeForSide(PoseLandmarkType.leftKnee, side)];

    if (shoulder != null && hip != null && knee != null) {
      return AngleCalculator.calculate(
        math.Point(shoulder.x, shoulder.y),
        math.Point(hip.x, hip.y),
        math.Point(knee.x, knee.y),
      );
    }

    return null;
  }

  double? _tryCalculateSideAngle(
    Pose pose, {
    required RangeRepSide side,
    required PoseLandmarkType first,
    required PoseLandmarkType middle,
    required PoseLandmarkType last,
  }) {
    return _tryCalculateAngle(
      pose,
      _landmarkTypeForSide(first, side),
      _landmarkTypeForSide(middle, side),
      _landmarkTypeForSide(last, side),
    );
  }

  double? _calculateBodyLineAngle(Pose pose, EngineKind engineKind) {
    if (!_supportsHoldAlignmentMetrics(engineKind)) {
      return null;
    }

    return _tryCalculateAngle(
      pose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftAnkle,
    );
  }

  double? _calculateArmSupportAngle(Pose pose, EngineKind engineKind) {
    if (!_supportsHoldAlignmentMetrics(engineKind)) {
      return null;
    }

    return _tryCalculateAngle(
      pose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    );
  }

  double? _calculateLegExtensionAngle(Pose pose, EngineKind engineKind) {
    if (!_supportsHoldAlignmentMetrics(engineKind)) {
      return null;
    }

    return _tryCalculateAngle(
      pose,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
    );
  }

  double? _tryCalculateAngle(
    Pose pose,
    PoseLandmarkType first,
    PoseLandmarkType middle,
    PoseLandmarkType last,
  ) {
    final firstLandmark = pose.landmarks[first];
    final middleLandmark = pose.landmarks[middle];
    final lastLandmark = pose.landmarks[last];

    if (firstLandmark == null ||
        middleLandmark == null ||
        lastLandmark == null) {
      return null;
    }

    return AngleCalculator.calculate(
      math.Point(firstLandmark.x, firstLandmark.y),
      math.Point(middleLandmark.x, middleLandmark.y),
      math.Point(lastLandmark.x, lastLandmark.y),
    );
  }

  PoseLandmarkType _landmarkTypeForSide(
    PoseLandmarkType landmarkType,
    RangeRepSide side,
  ) {
    if (side == RangeRepSide.left) {
      return landmarkType;
    }

    switch (landmarkType) {
      case PoseLandmarkType.leftShoulder:
        return PoseLandmarkType.rightShoulder;
      case PoseLandmarkType.leftElbow:
        return PoseLandmarkType.rightElbow;
      case PoseLandmarkType.leftWrist:
        return PoseLandmarkType.rightWrist;
      case PoseLandmarkType.leftHip:
        return PoseLandmarkType.rightHip;
      case PoseLandmarkType.leftKnee:
        return PoseLandmarkType.rightKnee;
      case PoseLandmarkType.leftAnkle:
        return PoseLandmarkType.rightAnkle;
      case PoseLandmarkType.rightShoulder:
        return PoseLandmarkType.leftShoulder;
      case PoseLandmarkType.rightElbow:
        return PoseLandmarkType.leftElbow;
      case PoseLandmarkType.rightWrist:
        return PoseLandmarkType.leftWrist;
      case PoseLandmarkType.rightHip:
        return PoseLandmarkType.leftHip;
      case PoseLandmarkType.rightKnee:
        return PoseLandmarkType.leftKnee;
      case PoseLandmarkType.rightAnkle:
        return PoseLandmarkType.leftAnkle;
      default:
        return landmarkType;
    }
  }

  bool _supportsHoldAlignmentMetrics(EngineKind engineKind) {
    return engineKind == EngineKind.hold;
  }

  bool _canExtractContractAwareRangeRepFormSignal(
    ExerciseConfig config,
    RangeRepContract rangeRepContract,
    RangeRepSignal signal,
  ) {
    if (!rangeRepContract.supportsSignal(signal)) {
      return false;
    }

    switch (signal) {
      case RangeRepSignal.postureAngle:
      case RangeRepSignal.depthMetric:
      case RangeRepSignal.alignmentMetric:
      case RangeRepSignal.endRangeMetric:
        return _supportsSquatFormSignals(config);
      case RangeRepSignal.stabilityMetric:
      case RangeRepSignal.bottomControlMetric:
        return false;
      case RangeRepSignal.primaryMetric:
      case RangeRepSignal.formMetric:
        return true;
    }
  }

  bool _supportsSquatFormSignals(ExerciseConfig config) {
    return config.primaryJoint == PoseLandmarkType.leftKnee &&
        config.joint1 == PoseLandmarkType.leftHip &&
        config.joint2 == PoseLandmarkType.leftAnkle;
  }
}
