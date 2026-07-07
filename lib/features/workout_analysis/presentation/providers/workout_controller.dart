import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/moving_average.dart';
import '../../application/analysis_engine_factory.dart';
import '../../application/engine_kind.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_metrics.dart';
import '../../application/exercise_metrics_extractor.dart';
import '../../application/workout_state.dart';
import '../../domain/analysis_engine.dart';
import '../../domain/hold_diagnostics.dart';
import '../../domain/models/exercise_config.dart';
import '../../domain/range_rep_diagnostics.dart';
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
  late final EngineKind _engineKind;
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
    _engineKind = definition.engineKind;
    _config = ref.watch(exerciseConfigProvider).requireValue;
    _engine = _engineFactory.create(
      engineKind: _engineKind,
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

    return WorkoutState(analysisKind: _engineKind);
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
          ? _metricsExtractor.extract(
              poses.first,
              _config,
              engineKind: _engineKind,
            )
          : const ExerciseMetrics.noPose();

      if (metrics.hasPose) {
        // Smooth landmark jitter before feeding the scoring state machine.
        final hasCompleteHoldMetrics =
            metrics.bodyLineAngle != null && metrics.armSupportAngle != null;
        final primaryMetric = _engineKind == EngineKind.hold
            ? hasCompleteHoldMetrics
                  ? metrics.bodyLineAngle!
                  : 0.0
            : metrics.primaryAngle;
        final formMetric = _engineKind == EngineKind.hold
            // Hold analysis depends on body line + arm support together.
            // If either signal is missing, fail closed for this frame instead
            // of falling back to the legacy squat-style metrics.
            ? hasCompleteHoldMetrics
                  ? metrics.armSupportAngle!
                  : 0.0
            : metrics.formMetric;
        final smoothAngle = _angleFilter.process(primaryMetric);
        final smoothFormMetric = _backFilter.process(formMetric);

        _engine.update(smoothAngle, smoothFormMetric);
        final holdDiagnostics = _holdDiagnosticsSnapshot();

        state = WorkoutState(
          landmarks: metrics.landmarks,
          analysisKind: _engineKind,
          repCount: _engine.repCount,
          isFormBad: _engine.isFormBad,
          currentAngle: smoothAngle,
          lastRepScore: _engine.lastRepScore,
          lastRepROM: _engine.maxRom,
          currentHoldSeconds: holdDiagnostics.currentHoldSeconds,
          bestHoldSeconds: holdDiagnostics.bestHoldSeconds,
          isHolding: holdDiagnostics.isHolding,
          hadHoldFormBreak: holdDiagnostics.hadFormBreak,
          feedbackMessage: _engine.feedback,
          currentPhase: _engine.phaseLabel,
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
          calibrationMetrics: _buildCalibrationMetrics(
            currentFormMetric: smoothFormMetric,
            thresholdValue: _engineKind == EngineKind.hold
                ? _config.thresholdActive
                : _config.formThreshold,
            currentBodyLineAngle: metrics.bodyLineAngle != null
                ? smoothAngle
                : null,
            currentArmSupportAngle: metrics.armSupportAngle != null
                ? smoothFormMetric
                : null,
            hasBodyLineAngle: metrics.bodyLineAngle != null,
            hasArmSupportAngle: metrics.armSupportAngle != null,
          ),
        );
      } else {
        // No-pose frames should not reset session counters or last rep results.
        state = WorkoutState(
          landmarks: metrics.landmarks,
          analysisKind: _engineKind,
          repCount: state.repCount,
          isFormBad: false,
          currentAngle: metrics.primaryAngle,
          lastRepScore: state.lastRepScore,
          lastRepROM: state.lastRepROM,
          currentHoldSeconds: 0,
          bestHoldSeconds: state.bestHoldSeconds,
          isHolding: false,
          hadHoldFormBreak: state.hadHoldFormBreak,
          feedbackMessage: "Vucut Bekleniyor...",
          currentPhase: "WAITING",
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
          calibrationMetrics: _buildCalibrationMetrics(
            currentFormMetric: metrics.formMetric,
            thresholdValue: _engineKind == EngineKind.hold
                ? _config.thresholdActive
                : _config.formThreshold,
          ),
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

  WorkoutCalibrationMetrics _buildCalibrationMetrics({
    required double currentFormMetric,
    required double thresholdValue,
    double? currentBodyLineAngle,
    double? currentArmSupportAngle,
    bool hasBodyLineAngle = false,
    bool hasArmSupportAngle = false,
  }) {
    final diagnostics = _rangeRepDiagnosticsSnapshot();
    final lastBreakdown = diagnostics.lastRepScoreBreakdown;

    // Calibration telemetry surfaces the active engine's current secondary metric.
    return WorkoutCalibrationMetrics(
      currentBackAngle: currentFormMetric,
      formThreshold: thresholdValue,
      currentBodyLineAngle: currentBodyLineAngle,
      currentArmSupportAngle: currentArmSupportAngle,
      hasBodyLineAngle: hasBodyLineAngle,
      hasArmSupportAngle: hasArmSupportAngle,
      currentRepWorstBackAngle: diagnostics.currentRepWorstBackAngle,
      currentRepHadFormViolation: diagnostics.currentRepHadFormViolation,
      hasLastRepBreakdown: lastBreakdown != null,
      lastRepRomScore: lastBreakdown?.romScore ?? 0,
      lastRepDescentScore: lastBreakdown?.descentScore ?? 0,
      lastRepAscentScoreCandidate: lastBreakdown?.ascentScoreCandidate ?? 0,
      lastRepWorstBackAngle: lastBreakdown?.worstBackAngle ?? 0,
      lastRepHadFormViolation: lastBreakdown?.hadFormViolation ?? false,
    );
  }

  RangeRepDiagnosticsSnapshot _rangeRepDiagnosticsSnapshot() {
    if (_engine is RangeRepDiagnostics) {
      return (_engine as RangeRepDiagnostics).diagnosticsSnapshot;
    }

    return const RangeRepDiagnosticsSnapshot();
  }

  HoldDiagnosticsSnapshot _holdDiagnosticsSnapshot() {
    if (_engine is HoldDiagnostics) {
      return (_engine as HoldDiagnostics).diagnosticsSnapshot;
    }

    return const HoldDiagnosticsSnapshot();
  }
}
