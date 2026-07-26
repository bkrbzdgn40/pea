import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/camera_view_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_camera_view_orientation.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/setup_camera_view_orientation_evaluator.dart';

void main() {
  const evaluator = SetupCameraViewOrientationEvaluator();

  test('returns insufficient evidence without a bilateral torso pair', () {
    final assessment = evaluator.evaluate(
      cameraViewContract: _sidePreferredContract(),
      pose: SetupCameraViewPose(
        leftShoulder: _point(0.4, 0.2),
        leftHip: _point(0.42, 0.65),
      ),
    );

    expect(
      assessment.status,
      SetupCameraViewAdvisoryStatus.insufficientEvidence,
    );
    expect(assessment.detectedView, isNull);
    expect(assessment.recommendedView, CameraView.side);
    expect(assessment.confidence, 0);
  });

  test('classifies wide bilateral geometry as a front view', () {
    final assessment = evaluator.evaluate(
      cameraViewContract: _frontPreferredContract(),
      pose: _frontPose(),
    );

    expect(assessment.status, SetupCameraViewAdvisoryStatus.preferred);
    expect(assessment.detectedView, CameraView.front);
    expect(assessment.detectedViewSupport, CameraViewSupport.preferred);
    expect(assessment.matchesPreferredView, isTrue);
    expect(assessment.completeBilateralPairCount, 2);
    expect(assessment.evidenceLikelihood, 1);
    expect(assessment.frontScore, greaterThan(assessment.sideScore));
    expect(assessment.confidence, greaterThanOrEqualTo(0.9));
  });

  test('classifies overlapping bilateral geometry as a side view', () {
    final assessment = evaluator.evaluate(
      cameraViewContract: _sidePreferredContract(),
      pose: _sidePose(),
    );

    expect(assessment.status, SetupCameraViewAdvisoryStatus.preferred);
    expect(assessment.detectedView, CameraView.side);
    expect(assessment.detectedViewSupport, CameraViewSupport.preferred);
    expect(assessment.sideScore, greaterThan(assessment.frontScore));
    expect(assessment.averageDepthSeparationRatio, greaterThan(0.3));
  });

  test('reports an unsupported but conclusive camera view', () {
    final assessment = evaluator.evaluate(
      cameraViewContract: _sidePreferredContract(),
      pose: _frontPose(),
    );

    expect(assessment.status, SetupCameraViewAdvisoryStatus.unsupported);
    expect(assessment.detectedView, CameraView.front);
    expect(assessment.recommendedView, CameraView.side);
    expect(assessment.detectedViewSupport, CameraViewSupport.unsupported);
  });

  test('preserves supported as distinct from preferred', () {
    final assessment = evaluator.evaluate(
      cameraViewContract: CameraViewContract(
        views: const <CameraView, CameraViewSupport>{
          CameraView.front: CameraViewSupport.preferred,
          CameraView.side: CameraViewSupport.supported,
        },
      ),
      pose: _sidePose(),
    );

    expect(assessment.status, SetupCameraViewAdvisoryStatus.supported);
    expect(assessment.detectedView, CameraView.side);
    expect(assessment.recommendedView, CameraView.front);
  });

  test('keeps ambiguous geometry indeterminate', () {
    final assessment = evaluator.evaluate(
      cameraViewContract: _frontPreferredContract(),
      pose: _ambiguousPose(),
    );

    expect(assessment.status, SetupCameraViewAdvisoryStatus.indeterminate);
    expect(assessment.detectedView, isNull);
    expect(assessment.hasConclusiveView, isFalse);
    expect(
      (assessment.frontScore - assessment.sideScore).abs(),
      lessThan(0.16),
    );
  });

  test('uses one complete pair conservatively when torso evidence exists', () {
    final assessment = evaluator.evaluate(
      cameraViewContract: _frontPreferredContract(),
      pose: SetupCameraViewPose(
        leftShoulder: _point(0.2, 0.25),
        rightShoulder: _point(0.8, 0.25),
        leftHip: _point(0.3, 0.65),
      ),
    );

    expect(assessment.status, SetupCameraViewAdvisoryStatus.preferred);
    expect(assessment.detectedView, CameraView.front);
    expect(assessment.completeBilateralPairCount, 1);
    expect(assessment.confidence, lessThan(0.9));
  });

  test('keeps weak but usable landmark evidence indeterminate', () {
    final assessment = evaluator.evaluate(
      cameraViewContract: _frontPreferredContract(),
      pose: SetupCameraViewPose(
        leftShoulder: _point(0.22, 0.24, likelihood: 0.55),
        rightShoulder: _point(0.78, 0.24, likelihood: 0.55),
        leftHip: _point(0.34, 0.66, likelihood: 0.55),
        rightHip: _point(0.66, 0.66, likelihood: 0.55),
      ),
    );

    expect(assessment.status, SetupCameraViewAdvisoryStatus.indeterminate);
    expect(assessment.detectedView, isNull);
    expect(assessment.evidenceLikelihood, closeTo(0.55, 1e-9));
  });

  test('rejects low-likelihood bilateral landmarks as insufficient', () {
    final assessment = evaluator.evaluate(
      cameraViewContract: _frontPreferredContract(),
      pose: SetupCameraViewPose(
        leftShoulder: _point(0.2, 0.25),
        rightShoulder: _point(0.8, 0.25, likelihood: 0.2),
        leftHip: _point(0.3, 0.65),
        rightHip: _point(0.7, 0.65, likelihood: 0.2),
      ),
    );

    expect(
      assessment.status,
      SetupCameraViewAdvisoryStatus.insufficientEvidence,
    );
    expect(assessment.detectedView, isNull);
  });

  test(
    'all active catalog contracts accept their preferred synthetic view',
    () {
      const catalog = ExerciseCatalog();

      for (final exercise in ExerciseType.values) {
        final definition = catalog.definitionFor(exercise);
        expect(definition.isAnalysisSupported, isTrue, reason: exercise.id);
        final contract = definition.analysisCameraViewContract;
        final preferred = contract.preferredViews.single;
        final preferredAssessment = evaluator.evaluate(
          cameraViewContract: contract,
          pose: preferred == CameraView.front ? _frontPose() : _sidePose(),
        );
        final oppositeAssessment = evaluator.evaluate(
          cameraViewContract: contract,
          pose: preferred == CameraView.front ? _sidePose() : _frontPose(),
        );

        expect(
          preferredAssessment.status,
          SetupCameraViewAdvisoryStatus.preferred,
          reason: exercise.id,
        );
        expect(
          oppositeAssessment.status,
          SetupCameraViewAdvisoryStatus.unsupported,
          reason: exercise.id,
        );
      }
    },
  );

  test('setup camera-view point rejects invalid geometry', () {
    expect(
      () => SetupCameraViewPoint(x: double.nan, y: 0, z: 0, likelihood: 1),
      throwsArgumentError,
    );
    expect(
      () => SetupCameraViewPoint(x: 0, y: 0, z: 0, likelihood: 1.1),
      throwsArgumentError,
    );
  });
}

CameraViewContract _frontPreferredContract() {
  return CameraViewContract(
    views: const <CameraView, CameraViewSupport>{
      CameraView.front: CameraViewSupport.preferred,
      CameraView.side: CameraViewSupport.unsupported,
    },
  );
}

CameraViewContract _sidePreferredContract() {
  return CameraViewContract(
    views: const <CameraView, CameraViewSupport>{
      CameraView.front: CameraViewSupport.unsupported,
      CameraView.side: CameraViewSupport.preferred,
    },
  );
}

SetupCameraViewPose _frontPose() {
  return SetupCameraViewPose(
    leftShoulder: _point(0.22, 0.24, z: 0),
    rightShoulder: _point(0.78, 0.24, z: 0.01),
    leftHip: _point(0.34, 0.66, z: 0),
    rightHip: _point(0.66, 0.66, z: 0.01),
  );
}

SetupCameraViewPose _sidePose() {
  return SetupCameraViewPose(
    leftShoulder: _point(0.47, 0.24, z: -0.13),
    rightShoulder: _point(0.53, 0.24, z: 0.13),
    leftHip: _point(0.485, 0.66, z: -0.11),
    rightHip: _point(0.515, 0.66, z: 0.11),
  );
}

SetupCameraViewPose _ambiguousPose() {
  return SetupCameraViewPose(
    leftShoulder: _point(0.42, 0.24, z: -0.045),
    rightShoulder: _point(0.58, 0.24, z: 0.045),
    leftHip: _point(0.42, 0.64, z: -0.045),
    rightHip: _point(0.58, 0.64, z: 0.045),
  );
}

SetupCameraViewPoint _point(
  double x,
  double y, {
  double z = 0,
  double likelihood = 1,
}) {
  return SetupCameraViewPoint(x: x, y: y, z: z, likelihood: likelihood);
}
