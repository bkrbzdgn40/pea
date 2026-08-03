import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../application/preparation_frame_assessment_evaluator.dart';
import '../../domain/models/setup_camera_view_orientation.dart';
import '../../domain/models/setup_framing_geometry.dart';
import '../../domain/models/setup_start_pose.dart';
import '../../infrastructure/converters/input_image_converter.dart';
import 'active_analysis_exercise_provider.dart';

class PreparationCameraState {
  PreparationCameraState({List<PoseLandmark> landmarks = const []})
    : landmarks = List<PoseLandmark>.unmodifiable(landmarks);

  final List<PoseLandmark> landmarks;

  bool get hasPose => landmarks.isNotEmpty;
}

typedef PreparationFrameAssessmentRequest = ({
  double imageWidth,
  double imageHeight,
  bool mirrorHorizontally,
});

typedef PreparationFramingRequest = PreparationFrameAssessmentRequest;
typedef PreparationCameraViewRequest = PreparationFrameAssessmentRequest;
typedef PreparationStartPoseRequest = PreparationFrameAssessmentRequest;

/// All exercise-aware diagnostics derived from the current preparation frame.
///
/// This is the only provider that adapts the landmark collection and resolves
/// exercise metadata. Compatibility providers below project individual fields
/// without repeating the preparation calculation pipeline.
final preparationFrameAssessmentProvider = Provider.autoDispose
    .family<PreparationFrameAssessment?, PreparationFrameAssessmentRequest>((
      ref,
      request,
    ) {
      final activeExercise = ref.watch(activeAnalysisExerciseProvider);
      if (activeExercise == null) {
        return null;
      }

      final landmarks = ref.watch(
        preparationCameraControllerProvider.select((state) => state.landmarks),
      );
      return const PreparationFrameAssessmentEvaluator().evaluate(
        exerciseType: activeExercise,
        landmarks: landmarks,
        imageWidth: request.imageWidth,
        imageHeight: request.imageHeight,
        mirrorHorizontally: request.mirrorHorizontally,
      );
    });

/// Exercise-aware start-pose diagnostics for the current preparation frame.
final preparationStartPoseAssessmentProvider = Provider.autoDispose
    .family<SetupStartPoseAssessment?, PreparationStartPoseRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(preparationFrameAssessmentProvider(request))
          ?.startPoseAssessment;
    });

/// Front/side advisory for the current preparation preview.
final preparationCameraViewAssessmentProvider = Provider.autoDispose
    .family<SetupCameraViewAssessment?, PreparationCameraViewRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(preparationFrameAssessmentProvider(request))
          ?.cameraViewAssessment;
    });

/// Framing diagnostics for the current preparation preview.
final preparationFramingAssessmentProvider = Provider.autoDispose
    .family<SetupFramingAssessment?, PreparationFramingRequest>((ref, request) {
      return ref
          .watch(preparationFrameAssessmentProvider(request))
          ?.framingAssessment;
    });

/// Owns the ML Kit detector used only by the preparation preview.
///
/// The live workout pipeline has a separate detector. Keeping these native
/// resources independent prevents an in-flight live-analysis request from
/// blocking or invalidating the preparation skeleton after route handoff.
final preparationPoseDetectorProvider = Provider.autoDispose<PoseDetector>((
  ref,
) {
  final detector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    ),
  );

  ref.onDispose(() {
    detector.close();
  });

  return detector;
});

final preparationCameraControllerProvider =
    AutoDisposeNotifierProvider<
      PreparationCameraController,
      PreparationCameraState
    >(PreparationCameraController.new);

/// Detects poses for the preparation preview without starting workout engines.
class PreparationCameraController
    extends AutoDisposeNotifier<PreparationCameraState> {
  static const Duration _analysisFrameInterval = Duration(milliseconds: 100);

  final InputImageConverter _inputImageConverter = const InputImageConverter();
  bool _isProcessing = false;
  DateTime? _lastAnalysisStartedAt;

  @override
  PreparationCameraState build() {
    ref.watch(preparationPoseDetectorProvider);
    return PreparationCameraState();
  }

  Future<void> processCameraImage(
    CameraImage image,
    int sensorOrientation, {
    DeviceOrientation? deviceOrientation,
    CameraLensDirection? lensDirection,
    DateTime? capturedAt,
  }) async {
    final now = capturedAt ?? DateTime.now();
    if (!_beginFrame(now)) {
      return;
    }

    try {
      final inputImage = _inputImageConverter.convert(
        image,
        sensorOrientation: sensorOrientation,
        deviceOrientation: deviceOrientation,
        lensDirection: lensDirection,
      );
      if (inputImage == null) {
        clear();
        return;
      }

      await _processInputImage(inputImage);
    } catch (_) {
      clear();
    } finally {
      _isProcessing = false;
    }
  }

  @visibleForTesting
  Future<void> processInputImageForPreview(
    InputImage inputImage, {
    DateTime? capturedAt,
  }) async {
    final now = capturedAt ?? DateTime.now();
    if (!_beginFrame(now)) {
      return;
    }

    try {
      await _processInputImage(inputImage);
    } catch (_) {
      clear();
    } finally {
      _isProcessing = false;
    }
  }

  bool _beginFrame(DateTime now) {
    if (_isProcessing ||
        (_lastAnalysisStartedAt != null &&
            now.difference(_lastAnalysisStartedAt!) < _analysisFrameInterval)) {
      return false;
    }

    _lastAnalysisStartedAt = now;
    _isProcessing = true;
    return true;
  }

  Future<void> _processInputImage(InputImage inputImage) async {
    final detector = ref.read(preparationPoseDetectorProvider);
    final poses = await detector.processImage(inputImage);
    final pose = selectPreparationPreviewPose(poses);
    if (pose == null) {
      clear();
      return;
    }

    state = PreparationCameraState(
      landmarks: pose.landmarks.values.toList(growable: false),
    );
  }

  void clear() {
    if (state.landmarks.isEmpty) {
      return;
    }
    state = PreparationCameraState();
  }
}

/// Chooses the most complete detected pose for a non-analytical preview.
Pose? selectPreparationPreviewPose(List<Pose> poses) {
  if (poses.isEmpty) {
    return null;
  }

  return poses.reduce((current, candidate) {
    if (candidate.landmarks.length > current.landmarks.length) {
      return candidate;
    }
    return current;
  });
}
