import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/exercise_type.dart';
import '../domain/models/setup_camera_view_orientation.dart';
import '../domain/models/setup_framing_geometry.dart';
import '../domain/models/setup_readiness_state.dart';
import '../domain/models/setup_start_pose.dart';
import '../domain/setup_camera_view_orientation_evaluator.dart';
import '../domain/setup_framing_geometry_evaluator.dart';
import '../domain/setup_start_pose_evaluator.dart';
import 'exercise_catalog.dart';
import 'setup_camera_view_pose_adapter.dart';
import 'setup_framing_pose_adapter.dart';
import 'setup_start_pose_adapter.dart';

/// Synchronized preparation diagnostics derived from one detected camera frame.
class PreparationFrameAssessment {
  const PreparationFrameAssessment({
    required this.framingAssessment,
    required this.cameraViewAssessment,
    required this.startPoseAssessment,
  });

  final SetupFramingAssessment framingAssessment;
  final SetupCameraViewAssessment cameraViewAssessment;
  final SetupStartPoseAssessment startPoseAssessment;

  SetupReadinessEvidence get readinessEvidence => SetupReadinessEvidence(
    framingAssessment: framingAssessment,
    cameraViewAssessment: cameraViewAssessment,
    startPoseAssessment: startPoseAssessment,
  );
}

/// Evaluates all preparation diagnostics from one shared landmark index.
///
/// The adapters intentionally keep their domain-specific normalized geometry,
/// but the ML Kit landmark lookup and exercise-catalog resolution happen only
/// once for each preparation frame.
class PreparationFrameAssessmentEvaluator {
  const PreparationFrameAssessmentEvaluator({
    this.catalog = const ExerciseCatalog(),
    this.framingPoseAdapter = const SetupFramingPoseAdapter(),
    this.cameraViewPoseAdapter = const SetupCameraViewPoseAdapter(),
    this.startPoseAdapter = const SetupStartPoseAdapter(),
    this.framingEvaluator = const SetupFramingGeometryEvaluator(),
    this.cameraViewEvaluator = const SetupCameraViewOrientationEvaluator(),
    this.startPoseContractResolver = const SetupStartPoseContractResolver(),
    this.startPoseEvaluator = const SetupStartPoseEvaluator(),
  });

  final ExerciseCatalog catalog;
  final SetupFramingPoseAdapter framingPoseAdapter;
  final SetupCameraViewPoseAdapter cameraViewPoseAdapter;
  final SetupStartPoseAdapter startPoseAdapter;
  final SetupFramingGeometryEvaluator framingEvaluator;
  final SetupCameraViewOrientationEvaluator cameraViewEvaluator;
  final SetupStartPoseContractResolver startPoseContractResolver;
  final SetupStartPoseEvaluator startPoseEvaluator;

  PreparationFrameAssessment evaluate({
    required ExerciseType exerciseType,
    required Iterable<PoseLandmark> landmarks,
    required double imageWidth,
    required double imageHeight,
    required bool mirrorHorizontally,
  }) {
    final landmarksByType = <PoseLandmarkType, PoseLandmark>{
      for (final landmark in landmarks) landmark.type: landmark,
    };
    final definition = catalog.definitionFor(exerciseType);
    final setupContract = definition.analysisSetupContract;

    final framingPose = framingPoseAdapter.fromLandmarksByType(
      landmarksByType: landmarksByType,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      mirrorHorizontally: mirrorHorizontally,
    );
    final cameraViewPose = cameraViewPoseAdapter.fromLandmarksByType(
      landmarksByType: landmarksByType,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      mirrorHorizontally: mirrorHorizontally,
    );
    final startPose = startPoseAdapter.fromLandmarksByType(
      landmarksByType: landmarksByType,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      mirrorHorizontally: mirrorHorizontally,
    );
    final startPoseContract = startPoseContractResolver.resolve(
      exerciseType: exerciseType,
      setupContract: setupContract,
    );

    return PreparationFrameAssessment(
      framingAssessment: framingEvaluator.evaluate(
        setupContract: setupContract,
        pose: framingPose,
      ),
      cameraViewAssessment: cameraViewEvaluator.evaluate(
        cameraViewContract: definition.analysisCameraViewContract,
        pose: cameraViewPose,
      ),
      startPoseAssessment: startPoseEvaluator.evaluate(
        contract: startPoseContract,
        pose: startPose,
      ),
    );
  }
}
