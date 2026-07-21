import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../app/localization/app_localizations.dart';

import '../../application/engine_kind.dart';
import '../../application/exercise_metric_registry.dart';
import '../../application/workout_engine.dart';
import '../../application/workout_live_metrics.dart';
import '../../application/workout_session_lifecycle_controller.dart';
import '../../application/workout_state.dart';
import '../../domain/models/exercise_config.dart';
import '../providers/active_analysis_exercise_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/completed_session_metrics_provider.dart';
import '../providers/exercise_config_provider.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/workout_controller.dart';
import '../providers/workout_plan_session_provider.dart';
import '../providers/workout_session_lifecycle_controller_provider.dart';
import '../widgets/analysis_selection_required_view.dart';
import '../widgets/pose_painter.dart';
import '../widgets/workout_diagnostics_panel.dart';
import 'camera_permission_screen.dart';
import 'exercise_selection_screen.dart';
import 'workout_plan_summary_screen.dart';
import 'workout_summary_screen.dart';

/// Runs the live camera analysis session and handles camera lifecycle recovery.
class LiveAnalysisScreen extends ConsumerStatefulWidget {
  const LiveAnalysisScreen({super.key});

  @override
  ConsumerState<LiveAnalysisScreen> createState() => _LiveAnalysisScreenState();
}

class _LiveAnalysisScreenState extends ConsumerState<LiveAnalysisScreen>
    with WidgetsBindingObserver {
  bool _isNavigatingToPermission = false;
  bool _isRecoveringCamera = false;
  bool _isRecoveringCameraRefreshInFlight = false;
  bool _showCalibrationPanel = false;
  WorkoutSessionLifecycleOwner? _sessionLifecycle;
  ProviderSubscription<WorkoutSessionLifecycleOwner>?
  _sessionLifecycleSubscription;
  Timer? _recoveryTimer;
  ProviderSubscription<AsyncValue<ExerciseConfig>>? _exerciseConfigSubscription;
  ProviderSubscription<WorkoutState>? _workoutStateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_hasAnalysisSelection()) {
      _sessionLifecycleSubscription = ref
          .listenManual<WorkoutSessionLifecycleOwner>(
            workoutSessionLifecycleControllerProvider,
            (previous, next) {
              _sessionLifecycle = next;
            },
            fireImmediately: true,
          );
      _sessionLifecycle = ref.read(workoutSessionLifecycleControllerProvider);
      unawaited(_setLiveAnalysisScreenAwake(true));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_hasAnalysisSelection()) {
          return;
        }
        _startSessionLifecycle();
      });
      if (ref.read(exerciseConfigProvider).hasValue) {
        _attachWorkoutStateSubscription();
      }
      _exerciseConfigSubscription = ref
          .listenManual<AsyncValue<ExerciseConfig>>(exerciseConfigProvider, (
            _,
            next,
          ) {
            if (next.hasValue) {
              _attachWorkoutStateSubscription();
            }
          });
    }
  }

  @override
  void dispose() {
    unawaited(_setLiveAnalysisScreenAwake(false));
    _recoveryTimer?.cancel();
    _sessionLifecycleSubscription?.close();
    _exerciseConfigSubscription?.close();
    _workoutStateSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _attachWorkoutStateSubscription() {
    final sessionLifecycle = _sessionLifecycle;
    if (sessionLifecycle == null) {
      return;
    }

    _workoutStateSubscription ??= ref.listenManual<WorkoutState>(
      workoutControllerProvider,
      (_, next) {
        sessionLifecycle.collect(next);
        final activeExercise = ref.read(activeAnalysisExerciseProvider);
        if (activeExercise != null) {
          ref
              .read(workoutPlanSessionProvider.notifier)
              .observe(exercise: activeExercise, workoutState: next);
        }
      },
    );
  }

  bool _hasAnalysisSelection() {
    final selectedExercise = ref.read(selectedExerciseProvider);
    final activeExercise = ref.read(activeAnalysisExerciseProvider);

    return selectedExercise != null && activeExercise != null;
  }

  void _startSessionLifecycle() {
    final activeExercise = ref.read(activeAnalysisExerciseProvider);
    final sessionLifecycle = _sessionLifecycle;
    if (activeExercise == null || sessionLifecycle == null) {
      return;
    }

    ref.read(completedSessionMetricsProvider.notifier).state = null;
    sessionLifecycle.startSession(exercise: activeExercise);
  }

  Future<void> _setLiveAnalysisScreenAwake(bool enable) async {
    try {
      await WakelockPlus.toggle(enable: enable);
    } catch (_) {
      // Keep the analysis flow running even if wakelock is unavailable.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_sessionLifecycle?.isFinishing ?? false) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref
          .read(workoutControllerProvider.notifier)
          .handleLifecycleInterruption(reason: 'app lifecycle pause');
      unawaited(_setLiveAnalysisScreenAwake(false));
      // Hide preview before teardown so CameraPreview never builds a disposed controller.
      _markCameraRecovering();
      unawaited(_stopImageStreamIfNeeded());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_hasAnalysisSelection()) {
        unawaited(_setLiveAnalysisScreenAwake(true));
      }
      unawaited(_recoverCameraIfAllowed());
    }
  }

  Future<void> _stopImageStreamIfNeeded() async {
    final controller = ref
        .read(cameraProvider)
        .maybeWhen(data: (controller) => controller, orElse: () => null);
    final controllerValue = controller == null
        ? null
        : _safeControllerValue(controller);

    if (controller == null ||
        controllerValue == null ||
        !controllerValue.isInitialized ||
        !controllerValue.isStreamingImages) {
      return;
    }

    try {
      await controller.stopImageStream();
    } catch (_) {
      // The camera plugin can already be tearing down during lifecycle changes.
    }
  }

  Future<void> _recoverCameraIfAllowed() async {
    final sessionLifecycle = _sessionLifecycle;
    if ((sessionLifecycle?.isFinishing ?? false) ||
        _isRecoveringCameraRefreshInFlight) {
      return;
    }
    if (_isRecoveringCamera && ref.read(cameraProvider).isLoading) return;
    if (!_hasAnalysisSelection()) {
      return;
    }

    _isRecoveringCameraRefreshInFlight = true;
    _markCameraRecovering();

    try {
      final status = await Permission.camera.status;
      if (!mounted || (sessionLifecycle?.isFinishing ?? false)) {
        return;
      }

      if (!status.isGranted) {
        await _stopImageStreamIfNeeded();
        if (!mounted || (sessionLifecycle?.isFinishing ?? false)) {
          return;
        }

        ref.invalidate(cameraProvider);
        _goToPermissionScreen();
        return;
      }

      ref.invalidate(cameraProvider);
    } finally {
      _isRecoveringCameraRefreshInFlight = false;
    }
  }

  void _markCameraRecovering() {
    if (!mounted) return;

    if (!_isRecoveringCamera) {
      setState(() => _isRecoveringCamera = true);
    }

    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isRecoveringCamera) {
        setState(() => _isRecoveringCamera = false);
      }
    });
  }

  void _goToPermissionScreen() {
    if (_isNavigatingToPermission || !mounted) return;

    _isNavigatingToPermission = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CameraPermissionScreen()),
    );
  }

  void _goToExerciseSelectionScreen() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseSelectionScreen()),
    );
  }

  Future<bool> _discardCompletedSessionForRetry() async {
    final sessionLifecycle = _sessionLifecycle;
    if (!mounted || sessionLifecycle == null) {
      return false;
    }

    final result = await sessionLifecycle.discardSavedSession();
    if (!mounted) {
      return false;
    }

    switch (result.failure) {
      case DiscardWorkoutSessionFailure.noSavedSession:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).noCompletedSessionToDelete,
            ),
          ),
        );
        return false;
      case DiscardWorkoutSessionFailure.persistenceFailure:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).previousSessionDeleteFailed,
            ),
          ),
        );
        return false;
      case null:
        return true;
    }
  }

  Future<void> _finishSession(WorkoutState workoutState) async {
    final sessionLifecycle = _sessionLifecycle;
    if (!mounted ||
        sessionLifecycle == null ||
        !sessionLifecycle.beginFinish()) {
      return;
    }

    setState(() {});

    final completedMetrics = ref
        .read(workoutControllerProvider.notifier)
        .liveMetricsSnapshot();

    await _stopImageStreamIfNeeded();
    if (!mounted) return;

    final result = await sessionLifecycle.finishSession(
      finalState: workoutState,
    );
    if (!mounted) return;

    setState(() {});

    switch (result.failure) {
      case FinishWorkoutSessionFailure.missingOwner:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).analysisSessionPreparationFailed,
            ),
          ),
        );
        return;
      case FinishWorkoutSessionFailure.missingExercise:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).selectValidExerciseBeforeAnalysis,
            ),
          ),
        );
        return;
      case FinishWorkoutSessionFailure.persistenceFailure:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sessionSaveFailed),
          ),
        );
        return;
      case FinishWorkoutSessionFailure.alreadyFinishing:
      case FinishWorkoutSessionFailure.alreadySaved:
        return;
      case null:
        break;
    }

    if (ref.read(workoutPlanSessionProvider).hasPlan) {
      ref.read(workoutPlanSessionProvider.notifier).reset();
    }
    ref.read(completedSessionMetricsProvider.notifier).state = completedMetrics;

    await _setLiveAnalysisScreenAwake(false);
    if (!mounted) return;
    final retryRequested = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          onRetryRequested: _discardCompletedSessionForRetry,
        ),
      ),
    );

    if (!mounted) return;

    sessionLifecycle.completeFinishFlow();

    if (retryRequested == true && _hasAnalysisSelection()) {
      // Only an explicit retry starts a fresh analysis session. A normal
      // summary dismiss keeps the completed-session guard intact.
      _startSessionLifecycle();
      ref.invalidate(workoutControllerProvider);
      unawaited(_setLiveAnalysisScreenAwake(true));
    }

    setState(() {});
  }

  Future<bool> _finishPlannedExerciseSession(WorkoutState workoutState) async {
    final sessionLifecycle = _sessionLifecycle;
    if (sessionLifecycle == null || !sessionLifecycle.beginFinish()) {
      return false;
    }

    setState(() {});
    final result = await sessionLifecycle.finishSession(
      finalState: workoutState,
    );
    if (!mounted) {
      return false;
    }
    setState(() {});

    switch (result.failure) {
      case FinishWorkoutSessionFailure.missingOwner:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).plannedStepMissingUser),
          ),
        );
        return false;
      case FinishWorkoutSessionFailure.missingExercise:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).plannedStepMissingExercise,
            ),
          ),
        );
        return false;
      case FinishWorkoutSessionFailure.persistenceFailure:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).plannedStepSaveFailed),
          ),
        );
        return false;
      case FinishWorkoutSessionFailure.alreadyFinishing:
      case FinishWorkoutSessionFailure.alreadySaved:
        return false;
      case null:
        return true;
    }
  }

  Future<void> _advancePlannedWorkout(WorkoutState workoutState) async {
    final planState = ref.read(workoutPlanSessionProvider);
    if (!planState.isSetCompleted) {
      return;
    }

    final activeExercise = ref.read(activeAnalysisExerciseProvider);
    final planController = ref.read(workoutPlanSessionProvider.notifier);
    final nextExercise = planController.nextExerciseAfterCompletedSet;
    final changesExercise =
        nextExercise == null || nextExercise != activeExercise;

    if (changesExercise) {
      await _stopImageStreamIfNeeded();
      if (!mounted) {
        return;
      }
      final saved = await _finishPlannedExerciseSession(workoutState);
      if (!saved || !mounted) {
        return;
      }
      _sessionLifecycle?.completeFinishFlow();
    }

    final nextSnapshot = planController.advance();
    if (nextSnapshot.isWorkoutCompleted) {
      await _setLiveAnalysisScreenAwake(false);
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WorkoutPlanSummaryScreen()),
      );
      return;
    }

    if (changesExercise && nextExercise != null) {
      ref.read(completedSessionMetricsProvider.notifier).state = null;
      ref.read(selectedExerciseProvider.notifier).state = nextExercise;
      _sessionLifecycle?.startSession(exercise: nextExercise);
    }
  }

  void _showDiagnosticsPanel() {
    if (!workoutDiagnosticsUiEnabled) {
      return;
    }
    final controller = ref.read(workoutControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => WorkoutDiagnosticsPanel(
        snapshotReader: controller.diagnosticsSnapshot,
        onReset: controller.resetDiagnostics,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final selectedExercise = ref.watch(selectedExerciseProvider);
    final activeExercise = ref.watch(activeAnalysisExerciseProvider);

    if (selectedExercise == null || activeExercise == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: AnalysisSelectionRequiredView(
          title: localizations.liveAnalysisSelectionTitle,
          message: localizations.liveAnalysisSelectionMessage,
          onSelectExercise: _goToExerciseSelectionScreen,
        ),
      );
    }

    final sessionLifecycle = _sessionLifecycle;
    if (sessionLifecycle == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: _CameraRecoveryView(),
      );
    }

    if (sessionLifecycle.isFinishing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: _CameraRecoveryView(),
      );
    }

    final configState = ref.watch(exerciseConfigProvider);
    if (configState.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: _ExerciseConfigLoadingView(),
      );
    }
    if (configState.hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _ExerciseConfigErrorView(
          onRetry: () => ref.invalidate(exerciseConfigProvider),
        ),
      );
    }

    final cameraState = ref.watch(cameraProvider);
    final workoutState = ref.watch(workoutControllerProvider);
    final liveMetrics = ref.watch(workoutLiveMetricsProvider);
    final workoutPlanState = ref.watch(workoutPlanSessionProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: cameraState.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        data: (controller) {
          // Riverpod can keep the previous controller during refresh; hide the
          // preview while recovery is active so a disposing controller is not used.
          if (_isRecoveringCamera || cameraState.isLoading) {
            return const _CameraRecoveryView();
          }

          final controllerValue = _safeControllerValue(controller);
          final previewSize = controllerValue?.previewSize;

          if (controllerValue == null ||
              !controllerValue.isInitialized ||
              previewSize == null) {
            return const _CameraRecoveryView();
          }

          if (!sessionLifecycle.isFinishing &&
              !controllerValue.isStreamingImages) {
            _startImageStream(controller);
          }

          final imageSize = Size(previewSize.height, previewSize.width);

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              if (workoutState.landmarks != null &&
                  workoutState.landmarks!.isNotEmpty)
                CustomPaint(
                  painter: PosePainter(
                    workoutState.landmarks!,
                    imageSize,
                    isFormBad: workoutState.isFormBad,
                    isMirrored:
                        controller.description.lensDirection ==
                        CameraLensDirection.front,
                    showDebugLandmarks: _showCalibrationPanel,
                  ),
                ),
              Positioned(
                top: topInset + 12,
                right: 14,
                child: TextButton.icon(
                  onPressed: sessionLifecycle.isFinishing
                      ? null
                      : () => unawaited(_finishSession(workoutState)),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: Text(
                    workoutPlanState.hasPlan
                        ? localizations.endWorkout
                        : localizations.finish,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black54,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (workoutDiagnosticsUiEnabled)
                Positioned(
                  top: topInset + 12,
                  left: 14,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Beta Diagnostics',
                      onPressed: sessionLifecycle.isFinishing
                          ? null
                          : _showDiagnosticsPanel,
                      color: Colors.white,
                      icon: const Icon(Icons.bug_report_outlined),
                    ),
                  ),
                ),
              Positioned(
                top: topInset + 72,
                left: 20,
                right: 20,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 8.0;
                    final cardWidth = (constraints.maxWidth - spacing * 2) / 3;
                    final isHoldAnalysis =
                        workoutState.analysisKind == EngineKind.hold;
                    String formatHoldSeconds(double seconds) {
                      final duration = Duration(
                        milliseconds: (seconds * 1000).round(),
                      );
                      final minutes = duration.inMinutes;
                      final remainingSeconds = duration.inSeconds
                          .remainder(60)
                          .toString()
                          .padLeft(2, '0');

                      return '$minutes:$remainingSeconds';
                    }

                    return Row(
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _MetricCard(
                            label: isHoldAnalysis
                                ? localizations.holdMetric
                                : localizations.repMetric,
                            value: isHoldAnalysis
                                ? formatHoldSeconds(
                                    workoutState.currentHoldSeconds,
                                  )
                                : workoutState.repCount.toString(),
                          ),
                        ),
                        const SizedBox(width: spacing),
                        SizedBox(
                          width: cardWidth,
                          child: _MetricCard(
                            label: 'FPS',
                            value: workoutState.cameraFps.toStringAsFixed(0),
                            color: Colors.cyanAccent,
                            onLongPress: () {
                              setState(
                                () => _showCalibrationPanel =
                                    !_showCalibrationPanel,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: spacing),
                        SizedBox(
                          width: cardWidth,
                          child: _MetricCard(
                            label: isHoldAnalysis
                                ? localizations.bestMetric
                                : localizations.scoreMetric,
                            value: isHoldAnalysis
                                ? formatHoldSeconds(
                                    workoutState.bestHoldSeconds,
                                  )
                                : workoutState.lastRepScore.toInt().toString(),
                            color: Colors.greenAccent,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                top: topInset + 152,
                left: 20,
                right: 20,
                child: _LiveCanonicalMetricsBar(metrics: liveMetrics),
              ),
              if (workoutPlanState.snapshot != null &&
                  !workoutPlanState.isWorkoutCompleted)
                Positioned(
                  top: topInset + 208,
                  left: 20,
                  right: 20,
                  child: _PlannedWorkoutProgressBar(
                    snapshot: workoutPlanState.snapshot!,
                  ),
                ),
              if (_showCalibrationPanel)
                Positioned(
                  top: topInset + (workoutPlanState.hasPlan ? 280 : 208),
                  left: 20,
                  right: 20,
                  child: _CalibrationDebugPanel(
                    workoutState: workoutState,
                    onClose: () {
                      setState(() => _showCalibrationPanel = false);
                    },
                  ),
                ),
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    if (workoutPlanState.isSetCompleted) ...[
                      _WorkoutSetCompletedCard(
                        snapshot: workoutPlanState.snapshot!,
                        onAdvance: () =>
                            unawaited(_advancePlannedWorkout(workoutState)),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: workoutState.isFormBad
                            ? Colors.red.withValues(alpha: 0.8)
                            : Colors.black54,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: workoutState.isFormBad
                              ? Colors.white
                              : Colors.greenAccent,
                        ),
                      ),
                      child: Text(
                        workoutState.feedbackMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      localizations.liveStatusLine(
                        workoutState.currentPhase,
                        workoutState.analysisFps.toStringAsFixed(0),
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const _CameraRecoveryView(),
        error: (error, _) {
          if (error is CameraException && error.code == 'cameraPermission') {
            return _CameraPermissionFallback(onPressed: _goToPermissionScreen);
          }

          if (_isRecoveringCamera && _isTransientCameraLifecycleError(error)) {
            return const _CameraRecoveryView();
          }

          return Center(child: Text(localizations.cameraOpenFailed(error)));
        },
      ),
    );
  }

  bool _isTransientCameraLifecycleError(Object error) {
    final message = error.toString().toLowerCase();

    return message.contains('dispose') ||
        message.contains('disposed') ||
        message.contains('controller') ||
        message.contains('initialize') ||
        message.contains('camera is closed') ||
        message.contains('camera closed');
  }

  CameraValue? _safeControllerValue(CameraController controller) {
    try {
      return controller.value;
    } catch (_) {
      return null;
    }
  }

  void _startImageStream(CameraController controller) {
    try {
      unawaited(
        controller
            .startImageStream((image) {
              ref
                  .read(workoutControllerProvider.notifier)
                  .processCameraImage(
                    image,
                    controller.description.sensorOrientation,
                  );
            })
            .catchError((_) {
              _markCameraRecoveringAfterFrame();
            }),
      );
    } catch (_) {
      _markCameraRecoveringAfterFrame();
    }
  }

  void _markCameraRecoveringAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markCameraRecovering();
    });
  }
}

class _PlannedWorkoutProgressBar extends StatelessWidget {
  const _PlannedWorkoutProgressBar({required this.snapshot});

  final WorkoutEngineSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final target = snapshot.targetRepetitions != null
        ? localizations.repetitionProgress(
            snapshot.currentRepetitions,
            snapshot.targetRepetitions!,
          )
        : '${_formatPlanDuration(snapshot.currentHoldDuration)} / ${_formatPlanDuration(snapshot.targetHoldDuration ?? Duration.zero)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.plannedWorkoutProgress(
                    round: snapshot.roundNumber,
                    totalRounds: snapshot.totalRounds,
                    set: snapshot.setNumber,
                    totalSets: snapshot.setsInCurrentExercise,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                target,
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: snapshot.progress,
            minHeight: 5,
            backgroundColor: Colors.white12,
          ),
        ],
      ),
    );
  }
}

class _WorkoutSetCompletedCard extends StatelessWidget {
  const _WorkoutSetCompletedCard({
    required this.snapshot,
    required this.onAdvance,
  });

  final WorkoutEngineSnapshot snapshot;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isFinalSet = snapshot.completedSets >= snapshot.totalSets;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xE6112A20),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.greenAccent),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isFinalSet
                  ? localizations.finalSetCompleted
                  : localizations.setCompletedContinue,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onAdvance,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            child: Text(
              isFinalSet ? localizations.finish : localizations.continueLabel,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPlanDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _ExerciseConfigLoadingView extends StatelessWidget {
  const _ExerciseConfigLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.greenAccent),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).analysisConfigLoading,
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _ExerciseConfigErrorView extends StatelessWidget {
  const _ExerciseConfigErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune_rounded, color: Colors.greenAccent, size: 42),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).analysisConfigLoadFailed,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context).analysisConfigRequiredMessage,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 15,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context).retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraRecoveryView extends StatelessWidget {
  const _CameraRecoveryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.greenAccent),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).cameraRecovering,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPermissionFallback extends StatelessWidget {
  const _CameraPermissionFallback({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_camera_outlined,
              color: Colors.greenAccent,
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).cameraPermissionRequired,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context).cameraPermissionFallbackBody,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 15,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(AppLocalizations.of(context).checkPermission),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onLongPress;

  const _MetricCard({
    required this.label,
    required this.value,
    this.color = Colors.white,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveCanonicalMetricsBar extends StatelessWidget {
  const _LiveCanonicalMetricsBar({required this.metrics});

  final WorkoutLiveMetricsSnapshot metrics;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final items = <MapEntry<String, String>>[];
    final session = metrics.sessionMetrics;
    final frame = metrics.frameMetrics;

    final primary = frame.valueFor(ExerciseMetricRegistry.primaryMovement);
    if (primary != null) {
      items.add(
        MapEntry<String, String>(
          localizations.angleMetric,
          '${primary.toStringAsFixed(0)}°',
        ),
      );
    }

    final tempo = session.valueFor(ExerciseMetricRegistry.tempo);
    if (tempo != null) {
      items.add(
        MapEntry<String, String>(
          localizations.tempoMetric,
          _formatMetricDuration(localizations, tempo),
        ),
      );
    }

    final stability =
        frame.valueFor(ExerciseMetricRegistry.stability) ??
        session.valueFor(ExerciseMetricRegistry.stability);
    if (stability != null) {
      items.add(
        MapEntry<String, String>(
          localizations.stabilityMetric,
          stability.toStringAsFixed(0),
        ),
      );
    }

    final asymmetry = session.valueFor(ExerciseMetricRegistry.asymmetryScore);
    if (asymmetry != null) {
      items.add(
        MapEntry<String, String>(
          localizations.asymmetryMetric,
          asymmetry.toStringAsFixed(0),
        ),
      );
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          for (var index = 0; index < items.take(3).length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    items[index].key,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[index].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatMetricDuration(
  AppLocalizations localizations,
  Duration duration,
) {
  if (duration.inMilliseconds < 1000) {
    return '${duration.inMilliseconds} ms';
  }
  return localizations.secondsValue(duration.inMilliseconds / 1000);
}

class _CalibrationDebugPanel extends StatelessWidget {
  const _CalibrationDebugPanel({
    required this.workoutState,
    required this.onClose,
  });

  final WorkoutState workoutState;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final metrics = workoutState.calibrationMetrics;
    final isHoldAnalysis = workoutState.analysisKind == EngineKind.hold;
    final scrollMaxHeight = MediaQuery.of(context).size.height * 0.42;

    final holdRows = <Widget>[
      _DebugMetricRow(
        label: 'body line',
        value: _formatOptionalAngle(
          metrics.currentBodyLineAngle,
          isAvailable: metrics.hasBodyLineAngle,
        ),
      ),
      _DebugMetricRow(
        label: 'arm support',
        value: _formatOptionalAngle(
          metrics.currentArmSupportAngle,
          isAvailable: metrics.hasArmSupportAngle,
        ),
      ),
      _DebugMetricRow(
        label: 'leg extension',
        value: _formatOptionalAngle(
          metrics.currentLegExtensionAngle,
          isAvailable: metrics.hasLegExtensionAngle,
        ),
      ),
      _DebugMetricRow(label: 'coverage', value: _formatHoldCoverage(metrics)),
      _DebugMetricRow(
        label: 'body target',
        value: _formatAngle(metrics.formThreshold),
      ),
      _DebugMetricRow(
        label: 'isFormBad',
        value: workoutState.isFormBad ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'isHolding',
        value: workoutState.isHolding ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'hold break',
        value: workoutState.hadHoldFormBreak ? 'true' : 'false',
      ),
    ];

    final rangeRepCoreRows = <Widget>[
      _DebugMetricRow(
        label: 'primary/current',
        value: _formatAngle(workoutState.currentAngle),
      ),
      _DebugMetricRow(
        label: 'form/current',
        value: _formatAngle(metrics.currentBackAngle),
      ),
      _DebugMetricRow(
        label: 'threshold',
        value: _formatAngle(metrics.formThreshold),
      ),
      _DebugMetricRow(
        label: 'isFormBad',
        value: workoutState.isFormBad ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'frame valid',
        value: metrics.isRangeRepFrameValid ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'selected side',
        value: metrics.selectedRangeRepSide ?? '--',
      ),
      _DebugMetricRow(
        label: 'side reason',
        value: metrics.rangeRepSideSelectionReason ?? '--',
      ),
      if (metrics.rangeRepSideHysteresisStatus != null)
        _DebugMetricRow(
          label: 'SideHys',
          value: metrics.rangeRepSideHysteresisStatus!,
        ),
      if (metrics.rangeRepSideConsistencyStatus != null)
        _DebugMetricRow(
          label: 'SideRep',
          value: metrics.rangeRepSideConsistencyStatus!,
        ),
      _DebugMetricRow(
        label: 'invalid reason',
        value: metrics.rangeRepInvalidReason ?? '--',
      ),
      _DebugMetricRow(
        label: 'visibility',
        value: metrics.rangeRepVisibilityStatus,
      ),
      _DebugMetricRow(
        label: 'invalid streak',
        value: metrics.rangeRepInvalidFrameStreak.toString(),
      ),
      _DebugMetricRow(
        label: 'invalid duration',
        value: _formatMilliseconds(metrics.rangeRepInvalidDurationMs),
      ),
      _DebugMetricRow(
        label: 'resync triggered',
        value: metrics.rangeRepResyncTriggered ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'resync reason',
        value: metrics.rangeRepResyncReason ?? '--',
      ),
      _DebugMetricRow(
        label: 'phase gate',
        value: metrics.rangeRepPhaseGateStatus,
      ),
      _DebugMetricRow(
        label: 'pending transition',
        value: metrics.rangeRepPendingTransition ?? '--',
      ),
      _DebugMetricRow(
        label: 'last transition',
        value: metrics.rangeRepLastConfirmedTransition ?? '--',
      ),
      _DebugMetricRow(
        label: 'coverage',
        value: _formatRangeRepCoverage(metrics),
      ),
      _DebugMetricRow(
        label: 'side coverage',
        value: _formatRangeRepSideCoverage(metrics),
      ),
      if (metrics.leftRangeRepSideConfidence != null)
        _DebugMetricRow(
          label: 'L Conf',
          value: _formatTelemetryValue(metrics.leftRangeRepSideConfidence!),
        ),
      if (metrics.rightRangeRepSideConfidence != null)
        _DebugMetricRow(
          label: 'R Conf',
          value: _formatTelemetryValue(metrics.rightRangeRepSideConfidence!),
        ),
    ];

    final signalRows = <Widget>[
      if (metrics.currentTorsoAngle != null)
        _DebugMetricRow(
          label: 'Torso',
          value: _formatTelemetryValue(metrics.currentTorsoAngle!),
        ),
      if (metrics.currentDepthMetric != null)
        _DebugMetricRow(
          label: 'Depth',
          value: _formatTelemetryValue(metrics.currentDepthMetric!),
        ),
      if (metrics.currentAlignmentMetric != null)
        _DebugMetricRow(
          label: 'Align',
          value: _formatTelemetryValue(metrics.currentAlignmentMetric!),
        ),
      if (metrics.currentStabilityMetric != null)
        _DebugMetricRow(
          label: 'Stability',
          value: _formatTelemetryValue(metrics.currentStabilityMetric!),
        ),
      if (metrics.currentLockoutMetric != null)
        _DebugMetricRow(
          label: 'Lockout',
          value: _formatTelemetryValue(metrics.currentLockoutMetric!),
        ),
      if (metrics.currentBottomControlMetric != null)
        _DebugMetricRow(
          label: 'BottomCtrl',
          value: _formatTelemetryValue(metrics.currentBottomControlMetric!),
        ),
    ];

    final thresholdRows = <Widget>[
      _DebugMetricRow(
        label: 'Current',
        value: _formatThresholdCurrent(metrics),
      ),
      _DebugMetricRow(
        label: 'Decision',
        value: _formatThresholdDecisionMeta(metrics),
      ),
      _DebugMetricRow(
        label: 'Session',
        value: _formatThresholdDecisionSummary(metrics),
      ),
    ];

    final validationRows = <Widget>[
      _DebugMetricRow(
        label: 'ValidCount',
        value: metrics.rangeRepValidatedCount.toString(),
      ),
      _DebugMetricRow(
        label: 'LowConfCount',
        value: metrics.rangeRepLowConfidenceCount.toString(),
      ),
      _DebugMetricRow(
        label: 'InvalidCount',
        value: metrics.rangeRepInvalidCount.toString(),
      ),
      if (metrics.hasLastRangeRepValidation) ...[
        _DebugMetricRow(
          label: 'Validation',
          value: metrics.lastRangeRepValidationStatus ?? '--',
        ),
        if (metrics.lastRangeRepValidatedRepIndex != null)
          _DebugMetricRow(
            label: 'Rep',
            value: metrics.lastRangeRepValidatedRepIndex.toString(),
          ),
        if (metrics.lastRangeRepValidationReasons.isNotEmpty)
          _DebugMetricRow(
            label: 'Reasons',
            value: metrics.lastRangeRepValidationReasons.join(', '),
          ),
      ],
    ];

    final phaseRows = <Widget>[
      if (metrics.descendingPhaseDurationMs != null)
        _DebugMetricRow(
          label: 'DescMs',
          value: metrics.descendingPhaseDurationMs.toString(),
        ),
      if (metrics.peakPhaseDurationMs != null)
        _DebugMetricRow(
          label: 'PeakMs',
          value: metrics.peakPhaseDurationMs.toString(),
        ),
      if (metrics.ascendingPhaseDurationMs != null)
        _DebugMetricRow(
          label: 'AscMs',
          value: metrics.ascendingPhaseDurationMs.toString(),
        ),
      if (metrics.descendingPhaseWorstFormMetric != null)
        _DebugMetricRow(
          label: 'DescForm',
          value: _formatPhaseFormTelemetry(
            metrics.descendingPhaseWorstFormMetric,
            metrics.descendingPhaseHadFormViolation,
          ),
        ),
      if (metrics.peakPhaseWorstFormMetric != null)
        _DebugMetricRow(
          label: 'PeakForm',
          value: _formatPhaseFormTelemetry(
            metrics.peakPhaseWorstFormMetric,
            metrics.peakPhaseHadFormViolation,
          ),
        ),
      if (metrics.ascendingPhaseWorstFormMetric != null)
        _DebugMetricRow(
          label: 'AscForm',
          value: _formatPhaseFormTelemetry(
            metrics.ascendingPhaseWorstFormMetric,
            metrics.ascendingPhaseHadFormViolation,
          ),
        ),
      _DebugMetricRow(label: 'DescQ', value: metrics.descendingPhaseStatus),
      if (metrics.descendingPhaseIssues.isNotEmpty)
        _DebugMetricRow(
          label: 'DescIssues',
          value: metrics.descendingPhaseIssues.join(', '),
        ),
      _DebugMetricRow(label: 'PeakQ', value: metrics.peakPhaseStatus),
      if (metrics.peakPhaseIssues.isNotEmpty)
        _DebugMetricRow(
          label: 'PeakIssues',
          value: metrics.peakPhaseIssues.join(', '),
        ),
      _DebugMetricRow(label: 'AscQ', value: metrics.ascendingPhaseStatus),
      if (metrics.ascendingPhaseIssues.isNotEmpty)
        _DebugMetricRow(
          label: 'AscIssues',
          value: metrics.ascendingPhaseIssues.join(', '),
        ),
      if (metrics.phaseQualityPenalty != null)
        _DebugMetricRow(
          label: 'PhasePenalty',
          value: _formatTelemetryValue(metrics.phaseQualityPenalty!),
        ),
      if (metrics.phaseAdjustedScore != null)
        _DebugMetricRow(
          label: 'PhaseScore',
          value: _formatTelemetryValue(metrics.phaseAdjustedScore!),
        ),
      if (metrics.phaseFeedbackCandidate != null)
        _DebugMetricRow(
          label: 'PhaseCue',
          value: metrics.phaseFeedbackCandidate!,
        ),
    ];

    final lastRepRows = <Widget>[
      if (metrics.hasLastRangeRepSummary) ...[
        if (metrics.lastRangeRepSummaryMinAngle != null)
          _DebugMetricRow(
            label: 'MinAngle',
            value: _formatTelemetryValue(metrics.lastRangeRepSummaryMinAngle!),
          ),
        if (metrics.lastRangeRepSummaryWorstFormMetric != null)
          _DebugMetricRow(
            label: 'WorstForm',
            value: _formatTelemetryValue(
              metrics.lastRangeRepSummaryWorstFormMetric!,
            ),
          ),
        if (metrics.lastRangeRepSummaryDescentMillis != null)
          _DebugMetricRow(
            label: 'DescentMs',
            value: metrics.lastRangeRepSummaryDescentMillis.toString(),
          ),
        if (metrics.lastRangeRepSummaryAscentMillis != null)
          _DebugMetricRow(
            label: 'AscentMs',
            value: metrics.lastRangeRepSummaryAscentMillis.toString(),
          ),
        _DebugMetricRow(
          label: 'FormBreak',
          value: metrics.lastRangeRepSummaryHadFormViolation ? 'true' : 'false',
        ),
        _DebugMetricRow(
          label: 'CoverageDrop',
          value: metrics.lastRangeRepSummaryHadCoverageDrop ? 'true' : 'false',
        ),
        _DebugMetricRow(
          label: 'SideSwitch',
          value: metrics.lastRangeRepSummarySwitchedSideDuringRep
              ? 'true'
              : 'false',
        ),
        _DebugMetricRow(
          label: 'FullPhase',
          value: metrics.lastRangeRepSummaryCompletedPhaseSequence
              ? 'true'
              : 'false',
        ),
        _DebugMetricRow(
          label: 'Side',
          value: metrics.lastRangeRepSummarySelectedSideLabel ?? '--',
        ),
      ],
      _DebugMetricRow(
        label: 'rep worst back',
        value: _formatAngle(metrics.currentRepWorstBackAngle),
      ),
      _DebugMetricRow(
        label: 'rep violation',
        value: metrics.currentRepHadFormViolation ? 'true' : 'false',
      ),
      if (metrics.hasLastRepBreakdown) ...[
        const Divider(color: Colors.white24, height: 14),
        Text(
          'last rep: score ${workoutState.lastRepScore.toStringAsFixed(1)} | '
          'rom ${metrics.lastRepRomScore.toStringAsFixed(1)} | '
          'desc ${metrics.lastRepDescentScore.toStringAsFixed(1)} | '
          'asc ${metrics.lastRepAscentScore.toStringAsFixed(1)}',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          'last form: worst ${_formatAngle(metrics.lastRepWorstBackAngle)} | '
          'violation ${metrics.lastRepHadFormViolation ? 'true' : 'false'}',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.45)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white70, fontSize: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Calibration',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: scrollMaxHeight),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isHoldAnalysis)
                        _DebugSection(title: 'Hold', children: holdRows)
                      else ...[
                        _DebugSection(
                          title: 'Core',
                          children: rangeRepCoreRows,
                        ),
                        if (signalRows.isNotEmpty)
                          _DebugSection(title: 'Signals', children: signalRows),
                        _DebugSection(
                          title: 'Validation',
                          children: validationRows,
                        ),
                        _DebugSection(
                          title: 'Threshold',
                          children: thresholdRows,
                        ),
                        _DebugSection(title: 'Phase', children: phaseRows),
                        _DebugSection(title: 'Last Rep', children: lastRepRows),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatOptionalAngle(double? value, {required bool isAvailable}) {
  if (!isAvailable || value == null) {
    return '--';
  }

  return _formatAngle(value);
}

String _formatTelemetryValue(double value) {
  return value.toStringAsFixed(1);
}

String _formatHoldCoverage(WorkoutCalibrationMetrics metrics) {
  final bodyCoverage = metrics.hasBodyLineAngle ? 'body ok' : 'body missing';
  final armCoverage = metrics.hasArmSupportAngle ? 'arm ok' : 'arm missing';
  final legCoverage = metrics.hasLegExtensionAngle ? 'leg ok' : 'leg missing';

  return '$bodyCoverage / $armCoverage / $legCoverage';
}

String _formatRangeRepCoverage(WorkoutCalibrationMetrics metrics) {
  final primaryCoverage = metrics.hasPrimaryAngle
      ? 'primary ok'
      : 'primary missing';
  final formCoverage = metrics.hasFormMetric ? 'form ok' : 'form missing';

  return '$primaryCoverage / $formCoverage';
}

String _formatRangeRepSideCoverage(WorkoutCalibrationMetrics metrics) {
  return 'L ${metrics.leftRangeRepCoverage}/2 / '
      'R ${metrics.rightRangeRepCoverage}/2';
}

String _formatThresholdCurrent(WorkoutCalibrationMetrics metrics) {
  final baseThreshold = metrics.baseFormThreshold ?? metrics.formThreshold;
  final effectiveThreshold =
      metrics.effectiveFormThreshold ?? metrics.formThreshold;
  final parts = <String>[
    'base ${_formatAngle(baseThreshold)}',
    'eff ${_formatAngle(effectiveThreshold)}',
  ];

  if (metrics.calibrationThresholdOffsetCandidate != null) {
    final offset = metrics.calibrationThresholdOffsetCandidate!;
    final sign = offset >= 0 ? '+' : '';
    parts.add('off $sign${_formatTelemetryValue(offset)}');
  }

  return parts.join(' | ');
}

String _formatThresholdDecisionMeta(WorkoutCalibrationMetrics metrics) {
  final parts = <String>[
    metrics.calibrationThresholdOffsetFallbackReason ?? '--',
  ];

  if (metrics.calibrationThresholdOffsetSampleCount != null) {
    parts.add('n ${metrics.calibrationThresholdOffsetSampleCount}');
  }
  if (metrics.calibrationThresholdOffsetBaselineSideLabel != null) {
    parts.add('side ${metrics.calibrationThresholdOffsetBaselineSideLabel}');
  }

  return parts.join(' | ');
}

String _formatThresholdDecisionSummary(WorkoutCalibrationMetrics metrics) {
  return 'all ${metrics.calibrationThresholdDecisionCount} | '
      'ap ${metrics.calibrationThresholdAppliedCount} | '
      'nb ${metrics.calibrationThresholdNoBaselineCount} | '
      'ins ${metrics.calibrationThresholdInsufficientSamplesCount} | '
      'miss ${metrics.calibrationThresholdMissingFormBaselineCount} | '
      'side ${metrics.calibrationThresholdSideMismatchCount} | '
      'small ${metrics.calibrationThresholdOffsetTooSmallCount}';
}

String _formatMilliseconds(int milliseconds) {
  return '${milliseconds}ms';
}

String _formatPhaseFormTelemetry(
  double? worstFormMetric,
  bool hadFormViolation,
) {
  final worstValue = worstFormMetric == null
      ? '--'
      : _formatTelemetryValue(worstFormMetric);

  return '$worstValue / ${hadFormViolation ? 'true' : 'false'}';
}

class _DebugSection extends StatelessWidget {
  const _DebugSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _DebugMetricRow extends StatelessWidget {
  const _DebugMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAngle(double value) {
  return '${value.toStringAsFixed(1)}°';
}
