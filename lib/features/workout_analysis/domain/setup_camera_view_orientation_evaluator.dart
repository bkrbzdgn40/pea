import 'dart:math' as math;

import 'models/camera_view_contract.dart';
import 'models/setup_camera_view_orientation.dart';

/// Infers front/side setup orientation from bilateral torso geometry.
///
/// The evaluator is deliberately advisory. Ambiguous or incomplete evidence
/// returns a non-conclusive status instead of inventing a definite camera view.
class SetupCameraViewOrientationEvaluator {
  const SetupCameraViewOrientationEvaluator({
    this.thresholds = SetupCameraViewThresholds.defaults,
  });

  final SetupCameraViewThresholds thresholds;

  SetupCameraViewAssessment evaluate({
    required CameraViewContract cameraViewContract,
    required SetupCameraViewPose pose,
  }) {
    final leftShoulder = _confident(pose.leftShoulder);
    final rightShoulder = _confident(pose.rightShoulder);
    final leftHip = _confident(pose.leftHip);
    final rightHip = _confident(pose.rightHip);
    final torsoLength = _resolveTorsoLength(
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      leftHip: leftHip,
      rightHip: rightHip,
    );
    final preferredView = _recommendedView(cameraViewContract);

    if (torsoLength == null ||
        torsoLength < thresholds.minimumTorsoLengthRatio) {
      return _assessment(
        status: SetupCameraViewAdvisoryStatus.insufficientEvidence,
        recommendedView: preferredView,
        torsoLength: torsoLength,
      );
    }

    final widthRatios = <double>[];
    final depthRatios = <double>[];
    final pairLikelihoods = <double>[];
    _collectPairEvidence(
      first: leftShoulder,
      second: rightShoulder,
      torsoLength: torsoLength,
      widthRatios: widthRatios,
      depthRatios: depthRatios,
      pairLikelihoods: pairLikelihoods,
    );
    _collectPairEvidence(
      first: leftHip,
      second: rightHip,
      torsoLength: torsoLength,
      widthRatios: widthRatios,
      depthRatios: depthRatios,
      pairLikelihoods: pairLikelihoods,
    );

    if (widthRatios.isEmpty) {
      return _assessment(
        status: SetupCameraViewAdvisoryStatus.insufficientEvidence,
        recommendedView: preferredView,
        torsoLength: torsoLength,
      );
    }

    final averageWidthRatio = _average(widthRatios);
    final averageDepthRatio = depthRatios.isEmpty
        ? null
        : _average(depthRatios);
    final widthFrontEvidence = _normalizeBetween(
      averageWidthRatio,
      thresholds.sidePairWidthRatio,
      thresholds.frontPairWidthRatio,
    );
    final widthSideEvidence = 1 - widthFrontEvidence;

    final depthSideEvidence = averageDepthRatio == null
        ? null
        : _normalizeBetween(
            averageDepthRatio,
            thresholds.frontDepthSeparationRatio,
            thresholds.sideDepthSeparationRatio,
          );
    final depthFrontEvidence = depthSideEvidence == null
        ? null
        : 1 - depthSideEvidence;
    final depthWeight = depthSideEvidence == null
        ? 0.0
        : thresholds.depthEvidenceWeight;
    final widthWeight = 1 - depthWeight;
    final pairCoverageFactor = widthRatios.length == 1
        ? thresholds.singlePairEvidenceFactor
        : 1.0;
    final evidenceLikelihood = _average(pairLikelihoods);
    final evidenceFactor = pairCoverageFactor * evidenceLikelihood;
    final frontScore =
        ((widthFrontEvidence * widthWeight) +
            ((depthFrontEvidence ?? 0.0) * depthWeight)) *
        evidenceFactor;
    final sideScore =
        ((widthSideEvidence * widthWeight) +
            ((depthSideEvidence ?? 0.0) * depthWeight)) *
        evidenceFactor;
    final confidence = math
        .max(frontScore, sideScore)
        .clamp(0.0, 1.0)
        .toDouble();
    final scoreSeparation = (frontScore - sideScore).abs();

    if (confidence < thresholds.minimumClassificationConfidence ||
        scoreSeparation < thresholds.minimumScoreSeparation) {
      return _assessment(
        status: SetupCameraViewAdvisoryStatus.indeterminate,
        recommendedView: preferredView,
        confidence: confidence,
        frontScore: frontScore,
        sideScore: sideScore,
        completePairCount: widthRatios.length,
        evidenceLikelihood: evidenceLikelihood,
        torsoLength: torsoLength,
        averageWidthRatio: averageWidthRatio,
        averageDepthRatio: averageDepthRatio,
      );
    }

    final detectedView = frontScore > sideScore
        ? CameraView.front
        : CameraView.side;
    final support = cameraViewContract.supportFor(detectedView);
    final status = switch (support) {
      CameraViewSupport.preferred => SetupCameraViewAdvisoryStatus.preferred,
      CameraViewSupport.supported => SetupCameraViewAdvisoryStatus.supported,
      CameraViewSupport.unsupported =>
        SetupCameraViewAdvisoryStatus.unsupported,
    };

    return _assessment(
      status: status,
      detectedView: detectedView,
      recommendedView: preferredView,
      detectedViewSupport: support,
      confidence: confidence,
      frontScore: frontScore,
      sideScore: sideScore,
      completePairCount: widthRatios.length,
      evidenceLikelihood: evidenceLikelihood,
      torsoLength: torsoLength,
      averageWidthRatio: averageWidthRatio,
      averageDepthRatio: averageDepthRatio,
    );
  }

  SetupCameraViewPoint? _confident(SetupCameraViewPoint? point) {
    if (point == null ||
        !point.isConfident(thresholds.minimumLandmarkLikelihood)) {
      return null;
    }
    return point;
  }

  double? _resolveTorsoLength({
    required SetupCameraViewPoint? leftShoulder,
    required SetupCameraViewPoint? rightShoulder,
    required SetupCameraViewPoint? leftHip,
    required SetupCameraViewPoint? rightHip,
  }) {
    if (leftShoulder != null &&
        rightShoulder != null &&
        leftHip != null &&
        rightHip != null) {
      final shoulderMidpoint = _midpoint(leftShoulder, rightShoulder);
      final hipMidpoint = _midpoint(leftHip, rightHip);
      return _distance2d(shoulderMidpoint, hipMidpoint);
    }

    final lengths = <double>[];
    if (leftShoulder != null && leftHip != null) {
      lengths.add(_distance2d(leftShoulder, leftHip));
    }
    if (rightShoulder != null && rightHip != null) {
      lengths.add(_distance2d(rightShoulder, rightHip));
    }
    return lengths.isEmpty ? null : _average(lengths);
  }

  void _collectPairEvidence({
    required SetupCameraViewPoint? first,
    required SetupCameraViewPoint? second,
    required double torsoLength,
    required List<double> widthRatios,
    required List<double> depthRatios,
    required List<double> pairLikelihoods,
  }) {
    if (first == null || second == null) {
      return;
    }

    widthRatios.add(_distance2d(first, second) / torsoLength);
    depthRatios.add((first.z - second.z).abs() / torsoLength);
    pairLikelihoods.add(math.min(first.likelihood, second.likelihood));
  }

  CameraView? _recommendedView(CameraViewContract contract) {
    for (final view in CameraView.values) {
      if (contract.supportFor(view) == CameraViewSupport.preferred) {
        return view;
      }
    }
    for (final view in CameraView.values) {
      if (contract.supportFor(view) == CameraViewSupport.supported) {
        return view;
      }
    }
    return null;
  }

  SetupCameraViewAssessment _assessment({
    required SetupCameraViewAdvisoryStatus status,
    required CameraView? recommendedView,
    CameraView? detectedView,
    CameraViewSupport? detectedViewSupport,
    double confidence = 0,
    double frontScore = 0,
    double sideScore = 0,
    int completePairCount = 0,
    double evidenceLikelihood = 0,
    double? torsoLength,
    double? averageWidthRatio,
    double? averageDepthRatio,
  }) {
    return SetupCameraViewAssessment(
      status: status,
      detectedView: detectedView,
      recommendedView: recommendedView,
      detectedViewSupport: detectedViewSupport,
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
      frontScore: frontScore.clamp(0.0, 1.0).toDouble(),
      sideScore: sideScore.clamp(0.0, 1.0).toDouble(),
      completeBilateralPairCount: completePairCount,
      evidenceLikelihood: evidenceLikelihood.clamp(0.0, 1.0).toDouble(),
      torsoLengthRatio: torsoLength,
      averagePairWidthRatio: averageWidthRatio,
      averageDepthSeparationRatio: averageDepthRatio,
    );
  }

  SetupCameraViewPoint _midpoint(
    SetupCameraViewPoint first,
    SetupCameraViewPoint second,
  ) {
    return SetupCameraViewPoint(
      x: (first.x + second.x) / 2,
      y: (first.y + second.y) / 2,
      z: (first.z + second.z) / 2,
      likelihood: math.min(first.likelihood, second.likelihood),
    );
  }

  double _distance2d(SetupCameraViewPoint first, SetupCameraViewPoint second) {
    return math.sqrt(
      math.pow(first.x - second.x, 2) + math.pow(first.y - second.y, 2),
    );
  }

  double _normalizeBetween(double value, double lower, double upper) {
    return ((value - lower) / (upper - lower)).clamp(0.0, 1.0).toDouble();
  }

  double _average(List<double> values) {
    return values.reduce((sum, value) => sum + value) / values.length;
  }
}
