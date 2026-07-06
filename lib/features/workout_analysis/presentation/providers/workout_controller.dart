import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/angle_calculator.dart';
import '../../../../core/utils/moving_average.dart';
import '../../application/workout_state.dart';
import '../../domain/exercise_engine.dart';
import '../../domain/models/exercise_config.dart';
import '../../infrastructure/converters/input_image_converter.dart';
import 'exercise_config_provider.dart';
import 'pose_provider.dart';

/// Exposes the live workout state produced from camera frames and pose results.
final workoutControllerProvider =
    AutoDisposeNotifierProvider<WorkoutController, WorkoutState>(() {
      return WorkoutController();
    });

/// Coordinates frame conversion, pose detection, smoothing, and rep state.
class WorkoutController extends AutoDisposeNotifier<WorkoutState> {
  static const Duration _analysisFrameInterval = Duration(milliseconds: 100);

  bool _isProcessing = false;
  DateTime? _lastAnalysisStartedAt;

  DateTime _lastFpsCalculationTime = DateTime.now();
  int _cameraFrameCount = 0;
  int _analysisFrameCount = 0;
  double _cameraFps = 0.0;
  double _analysisFps = 0.0;

  late final ExerciseEngine _engine;
  late final MovingAverageFilter _angleFilter;
  late final MovingAverageFilter _backFilter;
  late final ExerciseConfig _config;
  final InputImageConverter _inputImageConverter = const InputImageConverter();

  @override
  WorkoutState build() {
    // Recreating this provider starts a fresh analysis session and filter state.
    ref.watch(poseDetectorProvider);

    _config = ref.watch(exerciseConfigProvider).requireValue;
    _engine = ExerciseEngine(config: _config);

    _angleFilter = MovingAverageFilter(windowSize: 5);
    _backFilter = MovingAverageFilter(windowSize: 5);

    _lastFpsCalculationTime = DateTime.now();
    _cameraFrameCount = 0;
    _analysisFrameCount = 0;
    _cameraFps = 0.0;
    _analysisFps = 0.0;
    _lastAnalysisStartedAt = null;

    return WorkoutState();
  }

  /// Processes one camera frame and publishes the latest live telemetry.
  Future<void> processCameraImage(
    CameraImage image,
    int sensorOrientation,
  ) async {
    final now = DateTime.now();
    _cameraFrameCount++;
    _updateFpsIfNeeded();

    if (_isProcessing) return;
    // Keep ML Kit work below camera FPS so preview rendering stays responsive.
    if (_lastAnalysisStartedAt != null &&
        now.difference(_lastAnalysisStartedAt!) < _analysisFrameInterval) {
      return;
    }

    _lastAnalysisStartedAt = now;
    _isProcessing = true;

    try {
      final inputImage = _inputImageConverter.convert(image, sensorOrientation);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final detector = ref.read(poseDetectorProvider);
      final poses = await detector.processImage(inputImage);
      _analysisFrameCount++;
      _updateFpsIfNeeded();

      if (poses.isNotEmpty) {
        final pose = poses.first;

        final rawAngle = _calculatePrimaryAngle(pose);
        final rawBack = _calculateBackAngle(pose);

        // Smooth landmark jitter before feeding the scoring state machine.
        final smoothAngle = _angleFilter.process(rawAngle);
        final smoothBack = _backFilter.process(rawBack);

        _engine.update(smoothAngle, smoothBack);

        state = WorkoutState(
          landmarks: pose.landmarks.values.toList(),
          repCount: _engine.repCount,
          isFormBad: _engine.isFormBad,
          currentAngle: smoothAngle,
          lastRepScore: _engine.lastRepScore,
          lastRepROM: _engine.maxROM,
          feedbackMessage: _engine.feedback,
          currentPhase: _engine.state.name.toUpperCase(),
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
          calibrationMetrics: _buildCalibrationMetrics(smoothBack),
        );
      } else {
        // No-pose frames should not reset session counters or last rep results.
        state = WorkoutState(
          landmarks: [],
          repCount: state.repCount,
          isFormBad: false,
          currentAngle: 0.0,
          lastRepScore: state.lastRepScore,
          lastRepROM: state.lastRepROM,
          feedbackMessage: "Vücut Bekleniyor...",
          currentPhase: "WAITING",
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
          calibrationMetrics: _buildCalibrationMetrics(0),
        );
      }
    } catch (e) {
      debugPrint("ANALIZ HATASI: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void _updateFpsIfNeeded() {
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastFpsCalculationTime).inMilliseconds;

    if (elapsedMs < 1000) return;

    _cameraFps = _cameraFrameCount * 1000 / elapsedMs;
    _analysisFps = _analysisFrameCount * 1000 / elapsedMs;

    _cameraFrameCount = 0;
    _analysisFrameCount = 0;
    _lastFpsCalculationTime = now;

    state = state.copyWith(cameraFps: _cameraFps, analysisFps: _analysisFps);
  }

  double _calculatePrimaryAngle(Pose pose) {
    final p1 = pose.landmarks[_config.joint1];
    final mid = pose.landmarks[_config.primaryJoint];
    final p2 = pose.landmarks[_config.joint2];

    if (p1 != null && mid != null && p2 != null) {
      return AngleCalculator.calculate(
        math.Point(p1.x, p1.y),
        math.Point(mid.x, mid.y),
        math.Point(p2.x, p2.y),
      );
    }
    // Neutral fallback prevents a missing joint from being counted as movement.
    return 180.0;
  }

  double _calculateBackAngle(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];

    if (shoulder != null && hip != null && knee != null) {
      return AngleCalculator.calculate(
        math.Point(shoulder.x, shoulder.y),
        math.Point(hip.x, hip.y),
        math.Point(knee.x, knee.y),
      );
    }
    // Upright-ish fallback avoids false form violations from incomplete torso landmarks.
    return 90.0;
  }

  WorkoutCalibrationMetrics _buildCalibrationMetrics(double currentBackAngle) {
    final lastBreakdown = _engine.lastRepScoreBreakdown;

    // Debug-only telemetry for calibration; scoring still lives in ExerciseEngine.
    return WorkoutCalibrationMetrics(
      currentBackAngle: currentBackAngle,
      formThreshold: _config.formThreshold,
      currentRepWorstBackAngle: _engine.currentRepWorstBackAngle,
      currentRepHadFormViolation: _engine.currentRepHadFormViolation,
      hasLastRepBreakdown: lastBreakdown != null,
      lastRepRomScore: lastBreakdown?.romScore ?? 0,
      lastRepDescentScore: lastBreakdown?.descentScore ?? 0,
      lastRepAscentScoreCandidate: lastBreakdown?.ascentScoreCandidate ?? 0,
      lastRepWorstBackAngle: lastBreakdown?.worstBackAngle ?? 0,
      lastRepHadFormViolation: lastBreakdown?.hadFormViolation ?? false,
    );
  }
}
