import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../infrastructure/converters/input_image_converter.dart';

class PreparationCameraState {
  PreparationCameraState({List<PoseLandmark> landmarks = const []})
    : landmarks = List<PoseLandmark>.unmodifiable(landmarks);

  final List<PoseLandmark> landmarks;

  bool get hasPose => landmarks.isNotEmpty;
}

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
