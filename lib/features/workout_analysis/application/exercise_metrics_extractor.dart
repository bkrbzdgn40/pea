import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/angle_calculator.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_contract.dart';
import 'engine_kind.dart';
import 'exercise_landmark_requirements.dart';
import 'exercise_metrics.dart';

/// Converts a detected pose into the measurement signals the current engine uses.
class ExerciseMetricsExtractor {
  const ExerciseMetricsExtractor();

  static final RangeRepContract _emptyRangeRepContract = RangeRepContract(
    supportedPhases: const <RangeRepPhase>{},
    supportedSignals: const <RangeRepSignal>{},
  );
  static const ExerciseLandmarkRequirements _requirements =
      ExerciseLandmarkRequirements();

  ExerciseMetrics extract(
    Pose pose,
    ExerciseConfig config, {
    required EngineKind engineKind,
    RangeRepContract? rangeRepContract,
  }) {
    final effectiveRangeRepContract = engineKind == EngineKind.rangeRep
        ? (rangeRepContract ?? RangeRepContracts.squat)
        : _emptyRangeRepContract;
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
    final formMetric = _tryCalculateFormMetric(pose, config, side: side);
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
    final requirementSet = _requirements.resolve(
      config: config,
      engineKind: EngineKind.rangeRep,
      rangeRepContract: rangeRepContract,
      side: side,
    );
    final requiredLandmarks = requirementSet.requiredLandmarks;
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
    final signals = RangeRepFormSignals(
      torsoAngle: _extractConfiguredRangeRepSignalValue(
        pose,
        config,
        rangeRepContract,
        RangeRepSignal.postureAngle,
        side: side,
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      depthMetric: _extractConfiguredRangeRepSignalValue(
        pose,
        config,
        rangeRepContract,
        RangeRepSignal.depthMetric,
        side: side,
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      alignmentMetric: _extractConfiguredRangeRepSignalValue(
        pose,
        config,
        rangeRepContract,
        RangeRepSignal.alignmentMetric,
        side: side,
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      stabilityMetric: _extractConfiguredRangeRepSignalValue(
        pose,
        config,
        rangeRepContract,
        RangeRepSignal.stabilityMetric,
        side: side,
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      lockoutMetric: _extractConfiguredRangeRepSignalValue(
        pose,
        config,
        rangeRepContract,
        RangeRepSignal.endRangeMetric,
        side: side,
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      bottomControlMetric: _extractConfiguredRangeRepSignalValue(
        pose,
        config,
        rangeRepContract,
        RangeRepSignal.bottomControlMetric,
        side: side,
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
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

  double? _tryCalculateFormMetric(
    Pose pose,
    ExerciseConfig config, {
    required RangeRepSide side,
  }) {
    return _tryCalculateSignalDefinition(
      pose,
      definition: _formMetricDefinition(config),
      config: config,
      side: side,
      primaryAngle: _tryCalculatePrimaryAngle(pose, config, side: side),
    );
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
    return _requirements.landmarkTypeForSide(landmarkType, side);
  }

  bool _supportsHoldAlignmentMetrics(EngineKind engineKind) {
    return engineKind == EngineKind.hold;
  }

  RangeRepSignalDefinition? _configuredRangeRepSignalDefinition(
    ExerciseConfig config,
    RangeRepContract rangeRepContract,
    RangeRepSignal signal,
  ) {
    if (!rangeRepContract.supportsSignal(signal)) {
      return null;
    }

    final resolvedSignals = config.resolvedRangeRepSignals;
    if (resolvedSignals == null) {
      return null;
    }

    return resolvedSignals.definitionFor(signal);
  }

  RangeRepSignalDefinition? _formMetricDefinition(ExerciseConfig config) {
    return config.resolvedRangeRepSignals?.postureAngle;
  }

  double? _extractConfiguredRangeRepSignalValue(
    Pose pose,
    ExerciseConfig config,
    RangeRepContract rangeRepContract,
    RangeRepSignal signal, {
    required RangeRepSide side,
    required double? primaryAngle,
    required double? formMetric,
  }) {
    final definition = _configuredRangeRepSignalDefinition(
      config,
      rangeRepContract,
      signal,
    );
    if (definition == null) {
      return null;
    }

    if (signal == RangeRepSignal.postureAngle) {
      return formMetric;
    }

    return _tryCalculateSignalDefinition(
      pose,
      definition: definition,
      config: config,
      side: side,
      primaryAngle: primaryAngle,
      formMetric: formMetric,
    );
  }

  double? _tryCalculateSignalDefinition(
    Pose pose, {
    required RangeRepSignalDefinition? definition,
    required ExerciseConfig config,
    required RangeRepSide side,
    double? primaryAngle,
    double? formMetric,
  }) {
    if (definition == null) {
      return null;
    }

    final angle = definition.angle;
    if (angle != null) {
      return _tryCalculateSideAngle(
        pose,
        side: side,
        first: angle.first,
        middle: angle.middle,
        last: angle.last,
      );
    }

    switch (definition.source) {
      case RangeRepSignalSource.primaryMetric:
        return primaryAngle;
      case null:
        return formMetric;
    }
  }
}
