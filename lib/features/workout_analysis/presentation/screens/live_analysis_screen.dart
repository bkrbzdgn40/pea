import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/layout/camera_layout_spec.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../core/orientation/app_display_orientation.dart';
import '../../application/workout_developer_ui_config.dart';
import '../../application/workout_session_lifecycle_controller.dart';
import '../../application/workout_state.dart';
import '../../domain/models/exercise_config.dart';
import '../controllers/live_camera_session_controller.dart';
import '../controllers/live_session_flow_controller.dart';
import '../controllers/planned_workout_flow_controller.dart';
import '../errors/workout_camera_error_presentation.dart';
import '../models/live_pause_state.dart';
import '../models/live_tracking_state.dart';
import '../models/preparation_camera_geometry.dart';
import '../models/setup_readiness_view_data.dart';
import '../providers/active_analysis_exercise_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/exercise_config_provider.dart';
import '../providers/live_pause_controller.dart';
import '../providers/live_tracking_controller.dart';
import '../providers/preparation_camera_controller.dart';
import '../providers/preparation_readiness_controller.dart';
import '../providers/screen_awake_controller.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/workout_analysis_health_controller.dart';
import '../providers/workout_controller.dart';
import '../providers/workout_plan_session_provider.dart';
import '../providers/workout_session_lifecycle_controller_provider.dart';
import '../widgets/analysis_selection_required_view.dart';
import '../widgets/live_analysis/live_analysis_error_views.dart';
import '../widgets/live_analysis/live_analysis_feedback.dart';
import '../widgets/live_analysis/live_analysis_pause_overlay.dart';
import '../widgets/live_analysis/live_analysis_pose_overlays.dart';
import '../widgets/live_analysis/live_analysis_side_panel.dart';
import '../widgets/live_analysis/live_analysis_stage_effects.dart';
import '../widgets/live_analysis/live_analysis_top_bar.dart';
import '../widgets/live_analysis/live_hud_visibility_policy.dart';
import '../widgets/live_analysis/workout_analysis_failure_overlay.dart';
import '../widgets/planned_workout_live_hud.dart';
import '../widgets/workout_diagnostics_panel.dart';
import 'camera_permission_screen.dart';
import 'exercise_selection_screen.dart';

enum LiveAnalysisExitDisposition { stayInPreparation, leavePreparation }

/// Runs the live camera analysis session and delegates route orchestration.
class LiveAnalysisScreen extends ConsumerStatefulWidget {
  const LiveAnalysisScreen({super.key});

  @override
  ConsumerState<LiveAnalysisScreen> createState() => _LiveAnalysisScreenState();
}

class _LiveAnalysisScreenState extends ConsumerState<LiveAnalysisScreen>
    with WidgetsBindingObserver {
  bool _isNavigatingToPermission = false;
  bool _showCalibrationPanel = false;
  bool _showDetailedHud = false;
  late final LiveCameraSessionController _cameraSessionController;
  late final LiveSessionFlowController _sessionFlowController;
  late final PlannedWorkoutFlowController _plannedWorkoutFlowController;
  WorkoutSessionLifecycleOwner? _sessionLifecycle;
  ProviderSubscription<WorkoutSessionLifecycleOwner>?
  _sessionLifecycleSubscription;
  ProviderSubscription<AsyncValue<ExerciseConfig>>? _exerciseConfigSubscription;
  ProviderSubscription<WorkoutState>? _workoutStateSubscription;
  ProviderSubscription<LivePauseState>? _livePauseSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cameraSessionController.updateDisplayDeviceOrientation(
      appDeviceOrientationFor(MediaQuery.orientationOf(context)),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final hasAnalysisSelection = _hasAnalysisSelection();
    if (hasAnalysisSelection) {
      _sessionLifecycle = ref.read(workoutSessionLifecycleControllerProvider);
    }

    final screenAwakeController = ref.read(screenAwakeControllerProvider);
    Future<void> setScreenAwake(bool enable) {
      return enable
          ? screenAwakeController.acquire(ScreenAwakeOwner.liveAnalysis)
          : screenAwakeController.release(ScreenAwakeOwner.liveAnalysis);
    }

    late final PlannedWorkoutFlowController plannedWorkoutFlowController;
    _cameraSessionController = LiveCameraSessionController(
      ref: ref,
      isMounted: () => mounted,
      notifyStateChanged: _notifyStateChanged,
      hasAnalysisSelection: _hasAnalysisSelection,
      isPlanTransitionLocked: () =>
          plannedWorkoutFlowController.isTransitionLocked,
      sessionLifecycle: () => _sessionLifecycle,
      setScreenAwake: setScreenAwake,
      onPermissionRequired: _goToPermissionScreen,
    );
    _sessionFlowController = LiveSessionFlowController(
      ref: ref,
      context: () => context,
      isMounted: () => mounted,
      notifyStateChanged: _notifyStateChanged,
      hasAnalysisSelection: _hasAnalysisSelection,
      sessionLifecycle: () => _sessionLifecycle,
      cameraSession: _cameraSessionController,
      setScreenAwake: setScreenAwake,
      resolveExitDisposition: (leavePreparation) => leavePreparation
          ? LiveAnalysisExitDisposition.leavePreparation
          : LiveAnalysisExitDisposition.stayInPreparation,
    );
    plannedWorkoutFlowController = PlannedWorkoutFlowController(
      ref: ref,
      context: () => context,
      isMounted: () => mounted,
      notifyStateChanged: _notifyStateChanged,
      sessionLifecycle: () => _sessionLifecycle,
      cameraSession: _cameraSessionController,
      setScreenAwake: setScreenAwake,
      finishPlannedExerciseSession:
          _sessionFlowController.finishPlannedExerciseSession,
    );
    _plannedWorkoutFlowController = plannedWorkoutFlowController;

    if (!hasAnalysisSelection) {
      return;
    }

    _sessionLifecycleSubscription = ref
        .listenManual<WorkoutSessionLifecycleOwner>(
          workoutSessionLifecycleControllerProvider,
          (previous, next) {
            _sessionLifecycle = next;
            _cameraSessionController.onSessionLifecycleChanged();
          },
          fireImmediately: true,
        );
    unawaited(setScreenAwake(true));
    _cameraSessionController.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasAnalysisSelection()) {
        return;
      }
      _sessionFlowController.startSessionLifecycle();
    });
    if (ref.read(exerciseConfigProvider).hasValue) {
      _attachWorkoutStateSubscription();
    }
    _exerciseConfigSubscription = ref.listenManual<AsyncValue<ExerciseConfig>>(
      exerciseConfigProvider,
      (_, next) {
        if (next.hasValue) {
          _attachWorkoutStateSubscription();
        }
      },
    );
    _livePauseSubscription = ref.listenManual<LivePauseState>(
      livePauseControllerProvider,
      (previous, next) {
        if (previous?.isCountingDown == true && next.isActive) {
          ref.read(preparationCameraControllerProvider.notifier).clear();
          ref.read(workoutControllerProvider.notifier).handleManualResume();
        }
      },
    );
  }

  @override
  void dispose() {
    _plannedWorkoutFlowController.dispose();
    _sessionLifecycleSubscription?.close();
    _exerciseConfigSubscription?.close();
    _workoutStateSubscription?.close();
    _livePauseSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cameraSessionController.dispose());
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
        if (activeExercise == null) {
          return;
        }
        _plannedWorkoutFlowController.observe(
          activeExercise: activeExercise,
          workoutState: next,
        );
      },
    );
  }

  void _toggleHudDetails() {
    if (mounted) {
      setState(() => _showDetailedHud = !_showDetailedHud);
    }
  }

  void _notifyStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_cameraSessionController.handleAppLifecycleState(state));
  }

  bool _hasAnalysisSelection() {
    final selectedExercise = ref.read(selectedExerciseProvider);
    final activeExercise = ref.read(activeAnalysisExerciseProvider);

    return selectedExercise != null && activeExercise != null;
  }

  void _pauseAnalysis(SetupReadinessRequest readinessRequest) {
    final sessionLifecycle = _sessionLifecycle;
    if (sessionLifecycle == null || sessionLifecycle.isFinishing) {
      return;
    }

    final readiness = ref.read(
      preparationReadinessStateProvider(readinessRequest),
    );
    ref
        .read(livePauseControllerProvider.notifier)
        .pause(readinessSnapshot: readiness);
    ref.read(workoutControllerProvider.notifier).handleManualPause();
    ref.read(preparationCameraControllerProvider.notifier).clear();
  }

  void _requestResume(SetupReadinessRequest readinessRequest) {
    final readiness = ref.read(
      preparationReadinessStateProvider(readinessRequest),
    );
    ref
        .read(livePauseControllerProvider.notifier)
        .requestResume(readinessSnapshot: readiness);
  }

  void _cancelResume() {
    ref.read(livePauseControllerProvider.notifier).cancelResume();
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

  void _showDiagnosticsPanel() {
    if (!workoutDeveloperUiEnabled) {
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
    final pauseState = ref.watch(livePauseControllerProvider);
    final selectedExercise = ref.watch(selectedExerciseProvider);
    final activeExercise = ref.watch(activeAnalysisExerciseProvider);

    if (selectedExercise == null || activeExercise == null) {
      return _sessionFlowController.buildExitGuard(
        Scaffold(
          backgroundColor: Colors.black,
          body: AnalysisSelectionRequiredView(
            title: localizations.liveAnalysisSelectionTitle,
            message: localizations.liveAnalysisSelectionMessage,
            onSelectExercise: _goToExerciseSelectionScreen,
          ),
        ),
      );
    }

    final sessionLifecycle = _sessionLifecycle;
    if (sessionLifecycle == null) {
      return _sessionFlowController.buildExitGuard(
        const Scaffold(
          backgroundColor: Colors.black,
          body: CameraRecoveryView(),
        ),
      );
    }

    if (sessionLifecycle.isFinishing) {
      return _sessionFlowController.buildExitGuard(
        const Scaffold(
          backgroundColor: Colors.black,
          body: CameraRecoveryView(),
        ),
      );
    }

    final configState = ref.watch(exerciseConfigProvider);
    if (configState.isLoading) {
      return _sessionFlowController.buildExitGuard(
        const Scaffold(
          backgroundColor: Colors.black,
          body: ExerciseConfigLoadingView(),
        ),
      );
    }
    if (configState.hasError) {
      return _sessionFlowController.buildExitGuard(
        Scaffold(
          backgroundColor: Colors.black,
          body: ExerciseConfigErrorView(
            onRetry: () => ref.invalidate(exerciseConfigProvider),
          ),
        ),
      );
    }

    final cameraState = ref.watch(cameraProvider);
    final hasWorkoutPlan = ref.watch(
      workoutPlanSessionProvider.select((state) => state.hasPlan),
    );
    final trackingPhase = ref.watch(
      liveTrackingControllerProvider.select((state) => state.phase),
    );
    final analysisHealth = ref.watch(workoutAnalysisHealthControllerProvider);
    final hudPolicy = LiveHudVisibilityPolicy(
      mode: _showDetailedHud ? LiveHudMode.detailed : LiveHudMode.minimal,
      isPaused: pauseState.isPaused,
      hasCriticalWarning:
          trackingPhase != LiveTrackingPhase.tracking ||
          !analysisHealth.isHealthy,
    );
    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top;
    final viewportOrientation = mediaQuery.orientation;

    return _sessionFlowController.buildExitGuard(
      Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final layout = AppLayout.of(context, constraints: constraints);
            final cameraLayout = AppCameraLayoutSpec.resolve(
              layout: layout,
              constraints: constraints,
            );

            return cameraState.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              data: (controller) {
                // Riverpod can keep the previous controller during refresh;
                // hide the preview while recovery is active so a disposing
                // controller is not used.
                if (_cameraSessionController.isRecovering ||
                    cameraState.isLoading) {
                  return const CameraRecoveryView();
                }

                final controllerValue = _cameraSessionController
                    .safeControllerValue(controller);
                final cameraGeometry = const PreparationCameraGeometryResolver()
                    .resolve(
                      previewSize: controllerValue?.previewSize,
                      deviceOrientation:
                          _cameraSessionController.displayDeviceOrientation,
                      viewportOrientation: viewportOrientation,
                    );

                if (controllerValue == null ||
                    !controllerValue.isInitialized ||
                    cameraGeometry == null) {
                  return const CameraRecoveryView();
                }

                final imageSize = cameraGeometry.imageSize;
                final isMirrored =
                    controller.description.lensDirection ==
                    CameraLensDirection.front;
                final readinessRequest = (
                  imageWidth: imageSize.width,
                  imageHeight: imageSize.height,
                  mirrorHorizontally: isMirrored,
                );

                void toggleCalibration() {
                  setState(
                    () => _showCalibrationPanel = !_showCalibrationPanel,
                  );
                }

                final cameraStage = Stack(
                  key: const ValueKey<String>('live-camera-stage'),
                  fit: StackFit.expand,
                  children: <Widget>[
                    CameraPreview(controller),
                    const _LiveHudMetricsRetention(),
                    LiveCameraStageEffects(compact: layout.isLandscape),
                    if (pauseState.isActive)
                      WorkoutPoseOverlay(
                        imageSize: imageSize,
                        isMirrored: isMirrored,
                        showDebugLandmarks:
                            workoutDeveloperUiEnabled && _showCalibrationPanel,
                      )
                    else
                      PausedPoseOverlay(
                        imageSize: imageSize,
                        isMirrored: isMirrored,
                      ),
                    if (pauseState.isPaused)
                      LivePauseOverlay(
                        readinessRequest: readinessRequest,
                        onResume: () => _requestResume(readinessRequest),
                        onCancelResume: _cancelResume,
                        isFinishing: sessionLifecycle.isFinishing,
                        onFinish: () => unawaited(
                          _sessionFlowController.requestSessionExit(),
                        ),
                      ),
                    if (workoutDeveloperUiEnabled && pauseState.isActive)
                      Positioned(
                        top: topInset + (layout.isLandscape ? 8 : 12),
                        left: layout.isLandscape ? 10 : 14,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            key: const ValueKey<String>(
                              'live-diagnostics-button',
                            ),
                            tooltip: 'Beta Diagnostics',
                            onPressed: sessionLifecycle.isFinishing
                                ? null
                                : _showDiagnosticsPanel,
                            color: Colors.white,
                            iconSize: layout.isLandscape ? 18 : 24,
                            visualDensity: layout.isLandscape
                                ? VisualDensity.compact
                                : VisualDensity.standard,
                            constraints: BoxConstraints.tightFor(
                              width: layout.isLandscape ? 40 : 48,
                              height: layout.isLandscape ? 40 : 48,
                            ),
                            icon: const Icon(Icons.bug_report_outlined),
                          ),
                        ),
                      ),
                    if (workoutDeveloperUiEnabled &&
                        _showCalibrationPanel &&
                        pauseState.isActive)
                      CalibrationPanelOverlay(
                        topInset: topInset,
                        compact: layout.isLandscape,
                        onClose: () {
                          setState(() => _showCalibrationPanel = false);
                        },
                      ),
                  ],
                );

                final useSidePanel =
                    pauseState.isActive && cameraLayout.usesSidePanel;
                if (useSidePanel) {
                  final panelWidth = cameraLayout.sidePanelWidth!;
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Row(
                        key: const ValueKey<String>('live-side-panel-layout'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(child: cameraStage),
                          SizedBox(
                            width: panelWidth,
                            child: !hudPolicy.showActiveHud
                                ? const ColoredBox(color: Colors.black)
                                : hasWorkoutPlan
                                ? PlannedWorkoutLiveHud(
                                    topInset: 0,
                                    compact: true,
                                    sidePanel: true,
                                    isFinishing: sessionLifecycle.isFinishing,
                                    showDetails: hudPolicy.showDetailedContent,
                                    showFinishAction:
                                        hudPolicy.showFinishAction,
                                    onToggleDetails: _toggleHudDetails,
                                    onPause: () =>
                                        _pauseAnalysis(readinessRequest),
                                    onFinish: () => unawaited(
                                      _sessionFlowController
                                          .requestSessionExit(),
                                    ),
                                  )
                                : LiveAnalysisSidePanel(
                                    isFinishing: sessionLifecycle.isFinishing,
                                    showDetails: hudPolicy.showDetailedContent,
                                    showFinishAction:
                                        hudPolicy.showFinishAction,
                                    onToggleDetails: _toggleHudDetails,
                                    onPause: () =>
                                        _pauseAnalysis(readinessRequest),
                                    onFinish: () => unawaited(
                                      _sessionFlowController
                                          .requestSessionExit(),
                                    ),
                                    onToggleCalibration:
                                        workoutDeveloperUiEnabled
                                        ? toggleCalibration
                                        : null,
                                    showNonFinalSet:
                                        _plannedWorkoutFlowController
                                            .advanceFailed,
                                    onAdvance: () => unawaited(
                                      _plannedWorkoutFlowController
                                          .retryAdvance(),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      if (hudPolicy.showActiveHud && hasWorkoutPlan)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: panelWidth + 12,
                          child: WorkoutSetCompletedSection(
                            compact: true,
                            showNonFinal:
                                _plannedWorkoutFlowController.advanceFailed,
                            onAdvance: () => unawaited(
                              _plannedWorkoutFlowController.retryAdvance(),
                            ),
                          ),
                        ),
                      if (_plannedWorkoutFlowController.resumeCountdownValue !=
                          null)
                        PlannedResumeCountdownOverlay(
                          value: _plannedWorkoutFlowController
                              .resumeCountdownValue!,
                          nextExerciseName:
                              _plannedWorkoutFlowController.resumeExercise ==
                                  null
                              ? null
                              : localizations.exerciseTitle(
                                  _plannedWorkoutFlowController
                                      .resumeExercise!
                                      .id,
                                ),
                          nextSetNumber:
                              _plannedWorkoutFlowController.resumeSetNumber,
                        ),
                      if (pauseState.isActive)
                        const LiveTrackingRecoveryOverlay(),
                      if (pauseState.isActive)
                        const WorkoutAnalysisFailureOverlay(),
                    ],
                  );
                }

                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    cameraStage,
                    if (hudPolicy.showActiveHud && !hasWorkoutPlan)
                      LiveWorkoutTopBarOverlay(
                        topInset: topInset,
                        compact: layout.isLandscape,
                        reserveLeadingDeveloperControl:
                            workoutDeveloperUiEnabled,
                        isFinishing: sessionLifecycle.isFinishing,
                        showDetails: hudPolicy.showDetailedContent,
                        showFinishAction: hudPolicy.showFinishAction,
                        onToggleDetails: _toggleHudDetails,
                        onPause: () => _pauseAnalysis(readinessRequest),
                        onFinish: () => unawaited(
                          _sessionFlowController.requestSessionExit(),
                        ),
                      ),
                    if (hudPolicy.showActiveHud && hasWorkoutPlan)
                      Positioned.fill(
                        child: PlannedWorkoutLiveHud(
                          topInset: topInset,
                          compact: layout.isLandscape,
                          isFinishing: sessionLifecycle.isFinishing,
                          showDetails: hudPolicy.showDetailedContent,
                          showFinishAction: hudPolicy.showFinishAction,
                          onToggleDetails: _toggleHudDetails,
                          reserveLeadingDeveloperControl:
                              workoutDeveloperUiEnabled,
                          onPause: () => _pauseAnalysis(readinessRequest),
                          onFinish: () => unawaited(
                            _sessionFlowController.requestSessionExit(),
                          ),
                        ),
                      ),
                    if (hudPolicy.showActiveHud && !hasWorkoutPlan)
                      if (layout.isLandscape)
                        LandscapeWorkoutMetricsOverlay(
                          topInset: topInset,
                          showDetails: hudPolicy.showTechnicalMetrics,
                          onToggleCalibration: workoutDeveloperUiEnabled
                              ? toggleCalibration
                              : null,
                        )
                      else
                        PrimaryWorkoutMetricsOverlay(
                          topInset: topInset,
                          showDetails: hudPolicy.showTechnicalMetrics,
                          onToggleCalibration: workoutDeveloperUiEnabled
                              ? toggleCalibration
                              : null,
                        ),
                    if (hudPolicy.showActiveHud && !hasWorkoutPlan)
                      Positioned(
                        bottom: layout.isLandscape ? 12 : 40,
                        left: layout.isLandscape ? 12 : 20,
                        right: layout.isLandscape ? 12 : 20,
                        child: FractionallySizedBox(
                          widthFactor: layout.isLandscape ? 0.76 : 1,
                          child: Column(
                            children: <Widget>[
                              WorkoutSetCompletedSection(
                                compact: layout.isLandscape,
                                showNonFinal:
                                    _plannedWorkoutFlowController.advanceFailed,
                                onAdvance: () => unawaited(
                                  _plannedWorkoutFlowController.retryAdvance(),
                                ),
                              ),
                              if (hudPolicy.showDetailedContent)
                                RangeRepSideTrackingIndicator(
                                  compact: layout.isLandscape,
                                ),
                              WorkoutFeedbackStatus(
                                compact: layout.isLandscape,
                                showMeasurementConfidence:
                                    hudPolicy.showDetailedContent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (hudPolicy.showActiveHud && hasWorkoutPlan)
                      Positioned(
                        bottom: layout.isLandscape ? 122 : 232,
                        left: layout.isLandscape ? 12 : 20,
                        right: layout.isLandscape ? 12 : 20,
                        child: WorkoutSetCompletedSection(
                          compact: layout.isLandscape,
                          showNonFinal:
                              _plannedWorkoutFlowController.advanceFailed,
                          onAdvance: () => unawaited(
                            _plannedWorkoutFlowController.retryAdvance(),
                          ),
                        ),
                      ),
                    if (_plannedWorkoutFlowController.resumeCountdownValue !=
                        null)
                      PlannedResumeCountdownOverlay(
                        value:
                            _plannedWorkoutFlowController.resumeCountdownValue!,
                        nextExerciseName:
                            _plannedWorkoutFlowController.resumeExercise == null
                            ? null
                            : localizations.exerciseTitle(
                                _plannedWorkoutFlowController
                                    .resumeExercise!
                                    .id,
                              ),
                        nextSetNumber:
                            _plannedWorkoutFlowController.resumeSetNumber,
                      ),
                    if (pauseState.isActive)
                      const LiveTrackingRecoveryOverlay(),
                    if (pauseState.isActive)
                      const WorkoutAnalysisFailureOverlay(),
                  ],
                );
              },
              loading: () => const CameraRecoveryView(),
              error: (error, _) {
                final failure = presentWorkoutCameraError(
                  error: error,
                  localizations: localizations,
                );
                if (failure.requiresPermissionAction) {
                  return CameraPermissionFallback(
                    onPressed: _goToPermissionScreen,
                  );
                }

                if (_cameraSessionController.isRecovering &&
                    isTransientWorkoutCameraLifecycleError(error)) {
                  return const CameraRecoveryView();
                }

                return LiveCameraFailureView(
                  message: failure.message,
                  actionLabel: failure.actionLabel,
                  onRetry: () =>
                      unawaited(_cameraSessionController.recoverIfAllowed()),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LiveHudMetricsRetention extends ConsumerWidget {
  const _LiveHudMetricsRetention();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Minimal HUD intentionally hides technical metrics, but the latest
    // projection must remain available when the user opens the detailed HUD.
    ref.watch(workoutLiveMetricsProvider);
    return const SizedBox.shrink();
  }
}
