import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/moving_average.dart';
import '../../application/analysis_engine_factory.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_metrics.dart';
import '../../application/exercise_metrics_extractor.dart';
import '../../application/workout_state.dart';
import '../../domain/analysis_engine.dart';
import '../../domain/models/exercise_config.dart';
import '../../infrastructure/converters/input_image_converter.dart';
import 'active_analysis_exercise_provider.dart';
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

  late final AnalysisEngine _engine;
  late final MovingAverageFilter _angleFilter;
  late final MovingAverageFilter _backFilter;
  late final ExerciseConfig _config;
  final AnalysisEngineFactory _engineFactory = const AnalysisEngineFactory();
  final ExerciseCatalog _exerciseCatalog = const ExerciseCatalog();
  final ExerciseMetricsExtractor _metricsExtractor =
      const ExerciseMetricsExtractor();
  final InputImageConverter _inputImageConverter = const InputImageConverter();

  @override
  WorkoutState build() {
    // Recreating this provider starts a fresh analysis session and filter state.
    ref.watch(poseDetectorProvider);

    final activeExercise = ref.watch(activeAnalysisExerciseProvider);
    final definition = _exerciseCatalog.definitionFor(activeExercise);
    _config = ref.watch(exerciseConfigProvider).requireValue;
    _engine = _engineFactory.create(
      engineKind: definition.engineKind,
      config: _config,
    );

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

      final metrics = poses.isNotEmpty
          ? _metricsExtractor.extract(poses.first, _config)
          : const ExerciseMetrics.noPose();

      if (metrics.hasPose) {
        // Smooth landmark jitter before feeding the scoring state machine.
        final smoothAngle = _angleFilter.process(metrics.primaryAngle);
        final smoothFormMetric = _backFilter.process(metrics.formMetric);

        _engine.update(smoothAngle, smoothFormMetric);

        state = WorkoutState(
          landmarks: metrics.landmarks,
          repCount: _engine.repCount,
          isFormBad: _engine.isFormBad,
          currentAngle: smoothAngle,
          lastRepScore: _engine.lastRepScore,
          lastRepROM: _engine.maxRom,
          feedbackMessage: _engine.feedback,
          currentPhase: _engine.phaseLabel,
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
          calibrationMetrics: _buildCalibrationMetrics(smoothFormMetric),
        );
      } else {
        // No-pose frames should not reset session counters or last rep results.
        state = WorkoutState(
          landmarks: metrics.landmarks,
          repCount: state.repCount,
          isFormBad: false,
          currentAngle: metrics.primaryAngle,
          lastRepScore: state.lastRepScore,
          lastRepROM: state.lastRepROM,
          feedbackMessage: "Vucut Bekleniyor...",
          currentPhase: "WAITING",
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
          calibrationMetrics: _buildCalibrationMetrics(metrics.formMetric),
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

  WorkoutCalibrationMetrics _buildCalibrationMetrics(double currentFormMetric) {
    final lastBreakdown = _engine.lastRepScoreBreakdown;

    // Calibration telemetry still shows the current squat form metric.
    return WorkoutCalibrationMetrics(
      currentBackAngle: currentFormMetric,
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
