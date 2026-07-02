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
import 'pose_provider.dart';

// Controller state'ini sağlar.
final workoutControllerProvider =
    AutoDisposeNotifierProvider<WorkoutController, WorkoutState>(() {
      return WorkoutController();
    });

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
  // Analiz motorunu ve filtreleri kurar.
  WorkoutState build() {
    ref.watch(poseDetectorProvider);

    _config = ExerciseConfig.squat();
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

  // Kamera karesini analiz edip UI state'ini günceller.
  Future<void> processCameraImage(
    CameraImage image,
    int sensorOrientation,
  ) async {
    final now = DateTime.now();
    _cameraFrameCount++;
    _updateFpsIfNeeded();

    if (_isProcessing) return;
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

  // FPS sayaçlarını saniyelik yeniler.
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

  /// Konfigürasyona göre ana eklem açısını dinamik olarak hesaplar
  // Ana eklem açısını hesaplar.
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
    return 180.0;
  }

  // Sırt açısını hesaplar.
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
    return 90.0;
  }

  WorkoutCalibrationMetrics _buildCalibrationMetrics(double currentBackAngle) {
    final lastBreakdown = _engine.lastRepScoreBreakdown;

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
