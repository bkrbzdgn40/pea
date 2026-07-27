import 'dart:math' as math;

import 'models/exercise_setup_contract.dart';
import 'models/exercise_type.dart';
import 'models/setup_start_pose.dart';

/// Conservative, non-clinical thresholds for preparation start-pose checks.
class SetupStartPoseThresholds {
  const SetupStartPoseThresholds({
    required this.minimumLandmarkLikelihood,
    required this.uprightMaximumDeviationDegrees,
    required this.horizontalMaximumDeviationDegrees,
    required this.straightBodyMinimumAngleDegrees,
    required this.extendedJointMinimumAngleDegrees,
    required this.bentJointMinimumAngleDegrees,
    required this.bentJointMaximumAngleDegrees,
    required this.armsDownMinimumDropToTorsoRatio,
    required this.splitStanceMinimumSeparationToTorsoRatio,
    required this.feetTogetherMaximumSeparationToTorsoRatio,
    required this.supportMaximumHorizontalOffsetToTorsoRatio,
    required this.hollowCompressionMaximumAngleDegrees,
    required this.wallSitKneeMinimumAngleDegrees,
    required this.wallSitKneeMaximumAngleDegrees,
    required this.wallSitHipMinimumAngleDegrees,
    required this.wallSitHipMaximumAngleDegrees,
    required this.dipSupportMinimumElbowAngleDegrees,
  }) : assert(minimumLandmarkLikelihood >= 0),
       assert(minimumLandmarkLikelihood <= 1),
       assert(uprightMaximumDeviationDegrees > 0),
       assert(uprightMaximumDeviationDegrees < 90),
       assert(horizontalMaximumDeviationDegrees > 0),
       assert(horizontalMaximumDeviationDegrees < 90),
       assert(straightBodyMinimumAngleDegrees > 90),
       assert(straightBodyMinimumAngleDegrees <= 180),
       assert(extendedJointMinimumAngleDegrees > 90),
       assert(extendedJointMinimumAngleDegrees <= 180),
       assert(bentJointMinimumAngleDegrees >= 0),
       assert(bentJointMinimumAngleDegrees < bentJointMaximumAngleDegrees),
       assert(bentJointMaximumAngleDegrees < 180),
       assert(armsDownMinimumDropToTorsoRatio >= 0),
       assert(splitStanceMinimumSeparationToTorsoRatio > 0),
       assert(feetTogetherMaximumSeparationToTorsoRatio > 0),
       assert(supportMaximumHorizontalOffsetToTorsoRatio > 0),
       assert(hollowCompressionMaximumAngleDegrees > 90),
       assert(hollowCompressionMaximumAngleDegrees <= 180),
       assert(wallSitKneeMinimumAngleDegrees < wallSitKneeMaximumAngleDegrees),
       assert(wallSitHipMinimumAngleDegrees < wallSitHipMaximumAngleDegrees),
       assert(dipSupportMinimumElbowAngleDegrees > 90),
       assert(dipSupportMinimumElbowAngleDegrees <= 180);

  static const SetupStartPoseThresholds defaults = SetupStartPoseThresholds(
    minimumLandmarkLikelihood: 0.5,
    uprightMaximumDeviationDegrees: 25,
    horizontalMaximumDeviationDegrees: 28,
    straightBodyMinimumAngleDegrees: 150,
    extendedJointMinimumAngleDegrees: 145,
    bentJointMinimumAngleDegrees: 55,
    bentJointMaximumAngleDegrees: 140,
    armsDownMinimumDropToTorsoRatio: 0.12,
    splitStanceMinimumSeparationToTorsoRatio: 0.42,
    feetTogetherMaximumSeparationToTorsoRatio: 0.48,
    supportMaximumHorizontalOffsetToTorsoRatio: 0.7,
    hollowCompressionMaximumAngleDegrees: 172,
    wallSitKneeMinimumAngleDegrees: 75,
    wallSitKneeMaximumAngleDegrees: 135,
    wallSitHipMinimumAngleDegrees: 65,
    wallSitHipMaximumAngleDegrees: 135,
    dipSupportMinimumElbowAngleDegrees: 140,
  );

  final double minimumLandmarkLikelihood;
  final double uprightMaximumDeviationDegrees;
  final double horizontalMaximumDeviationDegrees;
  final double straightBodyMinimumAngleDegrees;
  final double extendedJointMinimumAngleDegrees;
  final double bentJointMinimumAngleDegrees;
  final double bentJointMaximumAngleDegrees;
  final double armsDownMinimumDropToTorsoRatio;
  final double splitStanceMinimumSeparationToTorsoRatio;
  final double feetTogetherMaximumSeparationToTorsoRatio;
  final double supportMaximumHorizontalOffsetToTorsoRatio;
  final double hollowCompressionMaximumAngleDegrees;
  final double wallSitKneeMinimumAngleDegrees;
  final double wallSitKneeMaximumAngleDegrees;
  final double wallSitHipMinimumAngleDegrees;
  final double wallSitHipMaximumAngleDegrees;
  final double dipSupportMinimumElbowAngleDegrees;
}

/// Resolves the 19 exercise contracts while sharing checks across pose families.
class SetupStartPoseContractResolver {
  const SetupStartPoseContractResolver();

  SetupStartPoseContract resolve({
    required ExerciseType exerciseType,
    required ExerciseSetupContract setupContract,
  }) {
    final expectedFamily = _expectedFamily(exerciseType);
    if (setupContract.startPoseFamily != expectedFamily) {
      throw StateError(
        '${exerciseType.name} start-pose evaluation expects '
        '${expectedFamily.name}, but the setup contract declares '
        '${setupContract.startPoseFamily.name}.',
      );
    }

    return SetupStartPoseContract(
      exerciseType: exerciseType,
      family: expectedFamily,
      checks: _checksFor(exerciseType),
    );
  }

  StartPoseFamily _expectedFamily(ExerciseType exerciseType) {
    return switch (exerciseType) {
      ExerciseType.squat ||
      ExerciseType.romanianDeadlift ||
      ExerciseType.goodMorning ||
      ExerciseType.calfRaise => StartPoseFamily.standingNeutralSide,
      ExerciseType.plank ||
      ExerciseType.pushUp => StartPoseFamily.floorProneSupport,
      ExerciseType.hollowHold ||
      ExerciseType.sitUp ||
      ExerciseType.lyingLegRaise ||
      ExerciseType.gluteBridge => StartPoseFamily.floorSupine,
      ExerciseType.lunge => StartPoseFamily.splitStanceSide,
      ExerciseType.bicepsCurl ||
      ExerciseType.lateralRaise => StartPoseFamily.standingArmsDownFront,
      ExerciseType.tricepsDip => StartPoseFamily.dipSupport,
      ExerciseType.shoulderPress => StartPoseFamily.standingElbowsBentFront,
      ExerciseType.frontRaise => StartPoseFamily.standingArmsDownSide,
      ExerciseType.wallSit => StartPoseFamily.wallSupportedHold,
      ExerciseType.sidePlank => StartPoseFamily.sideSupport,
      ExerciseType.jumpingJack => StartPoseFamily.dynamicBilateralNeutral,
    };
  }

  Set<SetupStartPoseCheck> _checksFor(ExerciseType exerciseType) {
    return switch (exerciseType) {
      ExerciseType.squat ||
      ExerciseType.romanianDeadlift ||
      ExerciseType.goodMorning ||
      ExerciseType.calfRaise => const <SetupStartPoseCheck>{
        SetupStartPoseCheck.uprightTorso,
        SetupStartPoseCheck.kneesExtended,
      },
      ExerciseType.plank || ExerciseType.pushUp => const <SetupStartPoseCheck>{
        SetupStartPoseCheck.horizontalTorso,
        SetupStartPoseCheck.straightBodyLine,
        SetupStartPoseCheck.kneesExtended,
        SetupStartPoseCheck.supportUnderShoulders,
      },
      ExerciseType.hollowHold => const <SetupStartPoseCheck>{
        SetupStartPoseCheck.horizontalTorso,
        SetupStartPoseCheck.kneesExtended,
        SetupStartPoseCheck.armsExtended,
        SetupStartPoseCheck.hollowCompression,
      },
      ExerciseType.lunge => const <SetupStartPoseCheck>{
        SetupStartPoseCheck.uprightTorso,
        SetupStartPoseCheck.splitStance,
      },
      ExerciseType.sitUp ||
      ExerciseType.gluteBridge => const <SetupStartPoseCheck>{
        SetupStartPoseCheck.horizontalTorso,
        SetupStartPoseCheck.kneesBent,
      },
      ExerciseType.bicepsCurl ||
      ExerciseType.lateralRaise ||
      ExerciseType.frontRaise => const <SetupStartPoseCheck>{
        SetupStartPoseCheck.uprightTorso,
        SetupStartPoseCheck.armsDown,
      },
      ExerciseType.lyingLegRaise => const <SetupStartPoseCheck>{
        SetupStartPoseCheck.horizontalTorso,
        SetupStartPoseCheck.kneesExtended,
        SetupStartPoseCheck.feetTogether,
      },
      ExerciseType.tricepsDip => const <SetupStartPoseCheck>{
        SetupStartPoseCheck.dipSupport,
      },
      ExerciseType.shoulderPress => const <SetupStartPoseCheck>{
        SetupStartPoseCheck.uprightTorso,
        SetupStartPoseCheck.elbowsBent,
      },
      ExerciseType.wallSit => const <SetupStartPoseCheck>{
        SetupStartPoseCheck.wallSitDepth,
      },
      ExerciseType.sidePlank => const <SetupStartPoseCheck>{
        SetupStartPoseCheck.horizontalTorso,
        SetupStartPoseCheck.straightBodyLine,
        SetupStartPoseCheck.kneesExtended,
        SetupStartPoseCheck.supportUnderShoulders,
      },
      ExerciseType.jumpingJack => const <SetupStartPoseCheck>{
        SetupStartPoseCheck.uprightTorso,
        SetupStartPoseCheck.kneesExtended,
        SetupStartPoseCheck.armsDown,
        SetupStartPoseCheck.feetTogether,
      },
    };
  }
}

/// Evaluates whether the current pose matches the exercise start-pose contract.
///
/// This evaluator is a setup gate candidate, not a full-form scorer. It checks
/// only the neutral/ready pose required before movement analysis begins.
class SetupStartPoseEvaluator {
  const SetupStartPoseEvaluator({
    this.thresholds = SetupStartPoseThresholds.defaults,
  });

  final SetupStartPoseThresholds thresholds;

  SetupStartPoseAssessment evaluate({
    required SetupStartPoseContract contract,
    required SetupStartPose pose,
  }) {
    final results = <SetupStartPoseCheck, SetupStartPoseCheckResult>{};
    for (final check in contract.checks) {
      results[check] = _evaluateCheck(check, pose);
    }

    final unavailable = results.values.any(
      (result) => result.outcome == SetupStartPoseCheckOutcome.unavailable,
    );
    final failed = results.values.any(
      (result) => result.outcome == SetupStartPoseCheckOutcome.failed,
    );
    final status = unavailable
        ? SetupStartPoseStatus.insufficientEvidence
        : failed
        ? SetupStartPoseStatus.notMatched
        : SetupStartPoseStatus.matched;
    final confidence = results.isEmpty
        ? 0.0
        : results.values
                  .map((result) => result.confidence)
                  .reduce((sum, value) => sum + value) /
              results.length;

    return SetupStartPoseAssessment(
      contract: contract,
      status: status,
      results: results,
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
    );
  }

  SetupStartPoseCheckResult _evaluateCheck(
    SetupStartPoseCheck check,
    SetupStartPose pose,
  ) {
    return switch (check) {
      SetupStartPoseCheck.uprightTorso => _axisCheck(
        check: check,
        pose: pose,
        horizontal: false,
      ),
      SetupStartPoseCheck.horizontalTorso => _axisCheck(
        check: check,
        pose: pose,
        horizontal: true,
      ),
      SetupStartPoseCheck.straightBodyLine => _straightBodyLine(pose),
      SetupStartPoseCheck.kneesExtended => _jointAngleCheck(
        check: check,
        pose: pose,
        joints: _kneeTriplets,
        minimum: thresholds.extendedJointMinimumAngleDegrees,
      ),
      SetupStartPoseCheck.kneesBent => _jointAngleCheck(
        check: check,
        pose: pose,
        joints: _kneeTriplets,
        minimum: thresholds.bentJointMinimumAngleDegrees,
        maximum: thresholds.bentJointMaximumAngleDegrees,
      ),
      SetupStartPoseCheck.armsDown => _armsDown(pose),
      SetupStartPoseCheck.armsExtended => _jointAngleCheck(
        check: check,
        pose: pose,
        joints: _elbowTriplets,
        minimum: thresholds.extendedJointMinimumAngleDegrees,
      ),
      SetupStartPoseCheck.elbowsBent => _elbowsBent(pose),
      SetupStartPoseCheck.splitStance => _splitStance(pose),
      SetupStartPoseCheck.feetTogether => _feetTogether(pose),
      SetupStartPoseCheck.supportUnderShoulders => _supportUnderShoulders(pose),
      SetupStartPoseCheck.hollowCompression => _hollowCompression(pose),
      SetupStartPoseCheck.wallSitDepth => _wallSitDepth(pose),
      SetupStartPoseCheck.dipSupport => _dipSupport(pose),
    };
  }

  SetupStartPoseCheckResult _axisCheck({
    required SetupStartPoseCheck check,
    required SetupStartPose pose,
    required bool horizontal,
  }) {
    final torso = _torsoAxis(pose);
    if (torso == null) {
      return _unavailable(check);
    }

    final absoluteAngle = _vectorAngleDegrees(torso.$1, torso.$2).abs();
    final normalized = absoluteAngle > 90 ? 180 - absoluteAngle : absoluteAngle;
    final deviation = horizontal
        ? math.min(normalized, (180 - normalized).abs())
        : (90 - normalized).abs();
    final maximum = horizontal
        ? thresholds.horizontalMaximumDeviationDegrees
        : thresholds.uprightMaximumDeviationDegrees;
    return _thresholdResult(
      check: check,
      passed: deviation <= maximum,
      observedValue: deviation,
      confidence: _minimumLikelihood(<SetupStartPosePoint>[torso.$1, torso.$2]),
    );
  }

  SetupStartPoseCheckResult _straightBodyLine(SetupStartPose pose) {
    final values = _anglesForTriplets(pose, _bodyLineTriplets);
    if (values.isEmpty) {
      return _unavailable(SetupStartPoseCheck.straightBodyLine);
    }
    final minimumAngle = values
        .map((value) => value.$1)
        .reduce((current, candidate) => math.min(current, candidate));
    return _thresholdResult(
      check: SetupStartPoseCheck.straightBodyLine,
      passed: minimumAngle >= thresholds.straightBodyMinimumAngleDegrees,
      observedValue: minimumAngle,
      confidence: _average(values.map((value) => value.$2)),
    );
  }

  SetupStartPoseCheckResult _jointAngleCheck({
    required SetupStartPoseCheck check,
    required SetupStartPose pose,
    required List<_JointTriplet> joints,
    required double minimum,
    double? maximum,
  }) {
    final values = _anglesForTriplets(pose, joints);
    if (values.isEmpty) {
      return _unavailable(check);
    }
    final conservativeValue = maximum == null
        ? values
              .map((value) => value.$1)
              .reduce((current, candidate) => math.min(current, candidate))
        : _average(values.map((value) => value.$1));
    final passed =
        conservativeValue >= minimum &&
        (maximum == null || conservativeValue <= maximum);
    return _thresholdResult(
      check: check,
      passed: passed,
      observedValue: conservativeValue,
      confidence: _average(values.map((value) => value.$2)),
    );
  }

  SetupStartPoseCheckResult _armsDown(SetupStartPose pose) {
    final torsoLength = _torsoLength(pose);
    if (torsoLength == null) {
      return _unavailable(SetupStartPoseCheck.armsDown);
    }

    final sideResults = <(double, double)>[];
    for (final side in _bodySides) {
      final shoulder = _point(pose, side.shoulder);
      final elbow = _point(pose, side.elbow);
      final wrist = _point(pose, side.wrist);
      if (shoulder == null || elbow == null || wrist == null) {
        continue;
      }
      final elbowAngle = _angle(shoulder, elbow, wrist);
      final wristDrop = (wrist.y - shoulder.y) / torsoLength;
      final passed =
          elbowAngle >= thresholds.extendedJointMinimumAngleDegrees &&
          wristDrop >= thresholds.armsDownMinimumDropToTorsoRatio;
      sideResults.add((
        passed ? 1.0 : 0.0,
        _minimumLikelihood(<SetupStartPosePoint>[shoulder, elbow, wrist]),
      ));
    }
    if (sideResults.isEmpty) {
      return _unavailable(SetupStartPoseCheck.armsDown);
    }
    return _thresholdResult(
      check: SetupStartPoseCheck.armsDown,
      passed: sideResults.every((result) => result.$1 == 1),
      observedValue: _average(sideResults.map((result) => result.$1)),
      confidence: _average(sideResults.map((result) => result.$2)),
    );
  }

  SetupStartPoseCheckResult _elbowsBent(SetupStartPose pose) {
    final torsoLength = _torsoLength(pose);
    if (torsoLength == null) {
      return _unavailable(SetupStartPoseCheck.elbowsBent);
    }
    final values = <(double, double, double)>[];
    for (final side in _bodySides) {
      final shoulder = _point(pose, side.shoulder);
      final elbow = _point(pose, side.elbow);
      final wrist = _point(pose, side.wrist);
      if (shoulder == null || elbow == null || wrist == null) {
        continue;
      }
      values.add((
        _angle(shoulder, elbow, wrist),
        _distance(shoulder, wrist) / torsoLength,
        _minimumLikelihood(<SetupStartPosePoint>[shoulder, elbow, wrist]),
      ));
    }
    if (values.isEmpty) {
      return _unavailable(SetupStartPoseCheck.elbowsBent);
    }
    final passed = values.every(
      (value) =>
          value.$1 >= thresholds.bentJointMinimumAngleDegrees &&
          value.$1 <= thresholds.bentJointMaximumAngleDegrees &&
          value.$2 <= 1.05,
    );
    return _thresholdResult(
      check: SetupStartPoseCheck.elbowsBent,
      passed: passed,
      observedValue: _average(values.map((value) => value.$1)),
      confidence: _average(values.map((value) => value.$3)),
    );
  }

  SetupStartPoseCheckResult _splitStance(SetupStartPose pose) {
    final torsoLength = _torsoLength(pose);
    final left = _point(pose, SetupStartPoseJoint.leftAnkle);
    final right = _point(pose, SetupStartPoseJoint.rightAnkle);
    if (torsoLength == null || left == null || right == null) {
      return _unavailable(SetupStartPoseCheck.splitStance);
    }
    final ratio = _distance(left, right) / torsoLength;
    return _thresholdResult(
      check: SetupStartPoseCheck.splitStance,
      passed: ratio >= thresholds.splitStanceMinimumSeparationToTorsoRatio,
      observedValue: ratio,
      confidence: _minimumLikelihood(<SetupStartPosePoint>[left, right]),
    );
  }

  SetupStartPoseCheckResult _feetTogether(SetupStartPose pose) {
    final torsoLength = _torsoLength(pose);
    final left = _point(pose, SetupStartPoseJoint.leftAnkle);
    final right = _point(pose, SetupStartPoseJoint.rightAnkle);
    if (torsoLength == null || left == null || right == null) {
      return _unavailable(SetupStartPoseCheck.feetTogether);
    }
    final ratio = _distance(left, right) / torsoLength;
    return _thresholdResult(
      check: SetupStartPoseCheck.feetTogether,
      passed: ratio <= thresholds.feetTogetherMaximumSeparationToTorsoRatio,
      observedValue: ratio,
      confidence: _minimumLikelihood(<SetupStartPosePoint>[left, right]),
    );
  }

  SetupStartPoseCheckResult _supportUnderShoulders(SetupStartPose pose) {
    final torsoLength = _torsoLength(pose);
    if (torsoLength == null) {
      return _unavailable(SetupStartPoseCheck.supportUnderShoulders);
    }
    final offsets = <(double, double)>[];
    for (final side in _bodySides) {
      final shoulder = _point(pose, side.shoulder);
      final elbow = _point(pose, side.elbow);
      final wrist = _point(pose, side.wrist);
      if (shoulder == null || (elbow == null && wrist == null)) {
        continue;
      }
      final support = <SetupStartPosePoint>[?elbow, ?wrist].reduce(
        (current, candidate) =>
            (candidate.x - shoulder.x).abs() < (current.x - shoulder.x).abs()
            ? candidate
            : current,
      );
      offsets.add((
        (support.x - shoulder.x).abs() / torsoLength,
        _minimumLikelihood(<SetupStartPosePoint>[shoulder, support]),
      ));
    }
    if (offsets.isEmpty) {
      return _unavailable(SetupStartPoseCheck.supportUnderShoulders);
    }
    final maximumOffset = offsets
        .map((value) => value.$1)
        .reduce((current, candidate) => math.max(current, candidate));
    return _thresholdResult(
      check: SetupStartPoseCheck.supportUnderShoulders,
      passed:
          maximumOffset <=
          thresholds.supportMaximumHorizontalOffsetToTorsoRatio,
      observedValue: maximumOffset,
      confidence: _average(offsets.map((value) => value.$2)),
    );
  }

  SetupStartPoseCheckResult _hollowCompression(SetupStartPose pose) {
    final values = _anglesForTriplets(pose, _bodyLineTriplets);
    if (values.isEmpty) {
      return _unavailable(SetupStartPoseCheck.hollowCompression);
    }
    final averageAngle = _average(values.map((value) => value.$1));
    return _thresholdResult(
      check: SetupStartPoseCheck.hollowCompression,
      passed: averageAngle <= thresholds.hollowCompressionMaximumAngleDegrees,
      observedValue: averageAngle,
      confidence: _average(values.map((value) => value.$2)),
    );
  }

  SetupStartPoseCheckResult _wallSitDepth(SetupStartPose pose) {
    final knees = _anglesForTriplets(pose, _kneeTriplets);
    final hips = _anglesForTriplets(pose, _hipTriplets);
    final torso = _axisCheck(
      check: SetupStartPoseCheck.uprightTorso,
      pose: pose,
      horizontal: false,
    );
    if (knees.isEmpty ||
        hips.isEmpty ||
        torso.outcome == SetupStartPoseCheckOutcome.unavailable) {
      return _unavailable(SetupStartPoseCheck.wallSitDepth);
    }
    final kneeAngle = _average(knees.map((value) => value.$1));
    final hipAngle = _average(hips.map((value) => value.$1));
    final passed =
        kneeAngle >= thresholds.wallSitKneeMinimumAngleDegrees &&
        kneeAngle <= thresholds.wallSitKneeMaximumAngleDegrees &&
        hipAngle >= thresholds.wallSitHipMinimumAngleDegrees &&
        hipAngle <= thresholds.wallSitHipMaximumAngleDegrees &&
        torso.outcome == SetupStartPoseCheckOutcome.passed;
    return _thresholdResult(
      check: SetupStartPoseCheck.wallSitDepth,
      passed: passed,
      observedValue: kneeAngle,
      confidence: _average(<double>[
        _average(knees.map((value) => value.$2)),
        _average(hips.map((value) => value.$2)),
        torso.confidence,
      ]),
    );
  }

  SetupStartPoseCheckResult _dipSupport(SetupStartPose pose) {
    final elbows = _anglesForTriplets(pose, _elbowTriplets);
    if (elbows.isEmpty) {
      return _unavailable(SetupStartPoseCheck.dipSupport);
    }
    final minimumAngle = elbows
        .map((value) => value.$1)
        .reduce((current, candidate) => math.min(current, candidate));
    return _thresholdResult(
      check: SetupStartPoseCheck.dipSupport,
      passed: minimumAngle >= thresholds.dipSupportMinimumElbowAngleDegrees,
      observedValue: minimumAngle,
      confidence: _average(elbows.map((value) => value.$2)),
    );
  }

  (SetupStartPosePoint, SetupStartPosePoint)? _torsoAxis(SetupStartPose pose) {
    final leftShoulder = _point(pose, SetupStartPoseJoint.leftShoulder);
    final rightShoulder = _point(pose, SetupStartPoseJoint.rightShoulder);
    final leftHip = _point(pose, SetupStartPoseJoint.leftHip);
    final rightHip = _point(pose, SetupStartPoseJoint.rightHip);

    final shoulder = _midpointOrSingle(leftShoulder, rightShoulder);
    final hip = _midpointOrSingle(leftHip, rightHip);
    if (shoulder == null || hip == null) {
      return null;
    }
    return (shoulder, hip);
  }

  double? _torsoLength(SetupStartPose pose) {
    final torso = _torsoAxis(pose);
    if (torso == null) {
      return null;
    }
    final length = _distance(torso.$1, torso.$2);
    return length <= 0 ? null : length;
  }

  SetupStartPosePoint? _midpointOrSingle(
    SetupStartPosePoint? first,
    SetupStartPosePoint? second,
  ) {
    if (first == null) {
      return second;
    }
    if (second == null) {
      return first;
    }
    return SetupStartPosePoint(
      x: (first.x + second.x) / 2,
      y: (first.y + second.y) / 2,
      z: (first.z + second.z) / 2,
      likelihood: math.min(first.likelihood, second.likelihood),
    );
  }

  SetupStartPosePoint? _point(SetupStartPose pose, SetupStartPoseJoint joint) {
    final point = pose.pointFor(joint);
    if (point == null ||
        !point.isConfident(thresholds.minimumLandmarkLikelihood)) {
      return null;
    }
    return point;
  }

  List<(double, double)> _anglesForTriplets(
    SetupStartPose pose,
    List<_JointTriplet> triplets,
  ) {
    final values = <(double, double)>[];
    for (final triplet in triplets) {
      final first = _point(pose, triplet.first);
      final middle = _point(pose, triplet.middle);
      final last = _point(pose, triplet.last);
      if (first == null || middle == null || last == null) {
        continue;
      }
      values.add((
        _angle(first, middle, last),
        _minimumLikelihood(<SetupStartPosePoint>[first, middle, last]),
      ));
    }
    return values;
  }

  SetupStartPoseCheckResult _thresholdResult({
    required SetupStartPoseCheck check,
    required bool passed,
    required double confidence,
    double? observedValue,
  }) {
    return SetupStartPoseCheckResult(
      check: check,
      outcome: passed
          ? SetupStartPoseCheckOutcome.passed
          : SetupStartPoseCheckOutcome.failed,
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
      observedValue: observedValue,
    );
  }

  SetupStartPoseCheckResult _unavailable(SetupStartPoseCheck check) {
    return SetupStartPoseCheckResult(
      check: check,
      outcome: SetupStartPoseCheckOutcome.unavailable,
      confidence: 0,
    );
  }

  double _angle(
    SetupStartPosePoint first,
    SetupStartPosePoint middle,
    SetupStartPosePoint last,
  ) {
    final radians =
        math.atan2(last.y - middle.y, last.x - middle.x) -
        math.atan2(first.y - middle.y, first.x - middle.x);
    var degrees = (radians * 180 / math.pi).abs();
    if (degrees > 180) {
      degrees = 360 - degrees;
    }
    return degrees;
  }

  double _vectorAngleDegrees(
    SetupStartPosePoint first,
    SetupStartPosePoint second,
  ) {
    return math.atan2(second.y - first.y, second.x - first.x) * 180 / math.pi;
  }

  double _distance(SetupStartPosePoint first, SetupStartPosePoint second) {
    return math.sqrt(
      math.pow(first.x - second.x, 2) + math.pow(first.y - second.y, 2),
    );
  }

  double _minimumLikelihood(Iterable<SetupStartPosePoint> points) {
    return points
        .map((point) => point.likelihood)
        .reduce((current, candidate) => math.min(current, candidate));
  }

  double _average(Iterable<double> values) {
    final list = values.toList(growable: false);
    return list.reduce((sum, value) => sum + value) / list.length;
  }

  static const List<_BodySide> _bodySides = <_BodySide>[
    _BodySide(
      shoulder: SetupStartPoseJoint.leftShoulder,
      elbow: SetupStartPoseJoint.leftElbow,
      wrist: SetupStartPoseJoint.leftWrist,
    ),
    _BodySide(
      shoulder: SetupStartPoseJoint.rightShoulder,
      elbow: SetupStartPoseJoint.rightElbow,
      wrist: SetupStartPoseJoint.rightWrist,
    ),
  ];

  static const List<_JointTriplet> _kneeTriplets = <_JointTriplet>[
    _JointTriplet(
      SetupStartPoseJoint.leftHip,
      SetupStartPoseJoint.leftKnee,
      SetupStartPoseJoint.leftAnkle,
    ),
    _JointTriplet(
      SetupStartPoseJoint.rightHip,
      SetupStartPoseJoint.rightKnee,
      SetupStartPoseJoint.rightAnkle,
    ),
  ];

  static const List<_JointTriplet> _elbowTriplets = <_JointTriplet>[
    _JointTriplet(
      SetupStartPoseJoint.leftShoulder,
      SetupStartPoseJoint.leftElbow,
      SetupStartPoseJoint.leftWrist,
    ),
    _JointTriplet(
      SetupStartPoseJoint.rightShoulder,
      SetupStartPoseJoint.rightElbow,
      SetupStartPoseJoint.rightWrist,
    ),
  ];

  static const List<_JointTriplet> _hipTriplets = <_JointTriplet>[
    _JointTriplet(
      SetupStartPoseJoint.leftShoulder,
      SetupStartPoseJoint.leftHip,
      SetupStartPoseJoint.leftKnee,
    ),
    _JointTriplet(
      SetupStartPoseJoint.rightShoulder,
      SetupStartPoseJoint.rightHip,
      SetupStartPoseJoint.rightKnee,
    ),
  ];

  static const List<_JointTriplet> _bodyLineTriplets = <_JointTriplet>[
    _JointTriplet(
      SetupStartPoseJoint.leftShoulder,
      SetupStartPoseJoint.leftHip,
      SetupStartPoseJoint.leftAnkle,
    ),
    _JointTriplet(
      SetupStartPoseJoint.rightShoulder,
      SetupStartPoseJoint.rightHip,
      SetupStartPoseJoint.rightAnkle,
    ),
  ];
}

class _JointTriplet {
  const _JointTriplet(this.first, this.middle, this.last);

  final SetupStartPoseJoint first;
  final SetupStartPoseJoint middle;
  final SetupStartPoseJoint last;
}

class _BodySide {
  const _BodySide({
    required this.shoulder,
    required this.elbow,
    required this.wrist,
  });

  final SetupStartPoseJoint shoulder;
  final SetupStartPoseJoint elbow;
  final SetupStartPoseJoint wrist;
}
