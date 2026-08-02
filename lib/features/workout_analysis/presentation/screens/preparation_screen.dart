import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/layout/camera_layout_spec.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../core/orientation/app_display_orientation.dart';

import '../../application/exercise_catalog.dart';
import '../camera_image_stream_coordinator.dart';
import '../mappers/exercise_setup_ui_mapper.dart';
import '../models/preparation_camera_geometry.dart';
import '../models/preparation_start_gate_state.dart';
import '../models/setup_readiness_view_data.dart';
import '../preparation_live_camera_handoff_coordinator.dart';
import '../providers/active_analysis_exercise_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/exercise_config_provider.dart';
import '../providers/preparation_camera_controller.dart';
import '../providers/preparation_start_gate_controller.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/screen_awake_controller.dart';
import '../providers/settings_provider.dart';
import '../widgets/analysis_selection_required_view.dart';
import '../widgets/preparation_camera_surface.dart';
import '../widgets/preparation_guide_overlay.dart';
import '../widgets/preparation_readiness_panel.dart';
import '../widgets/preparation_start_gate_controls.dart';
import '../widgets/preparation_screen_sections.dart';
import 'camera_permission_screen.dart';
import 'exercise_selection_screen.dart';
import 'live_analysis_screen.dart';

class PreparationScreen extends ConsumerStatefulWidget {
  const PreparationScreen({
    super.key,
    this.analysisScreenBuilder,
    this.cameraHandoffCoordinator,
  });

  final WidgetBuilder? analysisScreenBuilder;
  final PreparationLiveCameraHandoffCoordinator? cameraHandoffCoordinator;

  @override
  ConsumerState<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends ConsumerState<PreparationScreen>
    with WidgetsBindingObserver {
  late final CameraImageStreamCoordinator _imageStreamCoordinator;
  late final ScreenAwakeController _screenAwakeController;
  late final PreparationLiveCameraHandoffCoordinator _cameraHandoffCoordinator;
  late final bool _ownsCameraHandoffCoordinator;
  bool _isAppResumed = true;
  bool _isRecoveringCamera = false;
  bool _isNavigatingToPermission = false;
  bool _holdsScreenAwake = false;
  CameraController? _observedCameraController;
  DeviceOrientation? _observedDeviceOrientation;
  DeviceOrientation _displayDeviceOrientation = DeviceOrientation.portraitUp;
  Size? _observedPreviewSize;
  SetupReadinessRequest? _activeReadinessRequest;
  SetupReadinessRequest? _automaticallyArmedRequest;
  bool _automaticArmScheduled = false;
  bool _leavePreparationAfterAnalysis = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _imageStreamCoordinator = CameraImageStreamCoordinator();
    _screenAwakeController = ref.read(screenAwakeControllerProvider);
    _cameraHandoffCoordinator =
        widget.cameraHandoffCoordinator ??
        PreparationLiveCameraHandoffCoordinator();
    _ownsCameraHandoffCoordinator = widget.cameraHandoffCoordinator == null;
    _cameraHandoffCoordinator.addListener(_handleCameraHandoffChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_refreshPreparationScreenAwake());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _displayDeviceOrientation = appDeviceOrientationFor(
      MediaQuery.orientationOf(context),
    );
  }

  @override
  void dispose() {
    unawaited(_setPreparationScreenAwake(false));
    _stopObservingCameraGeometry();
    WidgetsBinding.instance.removeObserver(this);
    _cameraHandoffCoordinator.removeListener(_handleCameraHandoffChanged);
    if (_ownsCameraHandoffCoordinator) {
      _cameraHandoffCoordinator.dispose();
    }
    unawaited(_imageStreamCoordinator.dispose());
    super.dispose();
  }

  void _handleCameraHandoffChanged() {
    if (mounted) {
      setState(() {});
      unawaited(_refreshPreparationScreenAwake());
    }
  }

  Future<void> _refreshPreparationScreenAwake() {
    final shouldKeepAwake =
        mounted &&
        _isAppResumed &&
        !_isNavigatingToPermission &&
        _cameraHandoffCoordinator.canRecoverPreparationCamera &&
        _hasAnalysisSelection();
    return _setPreparationScreenAwake(shouldKeepAwake);
  }

  Future<void> _setPreparationScreenAwake(bool enable) {
    if (_holdsScreenAwake == enable) {
      return Future<void>.value();
    }
    _holdsScreenAwake = enable;
    return enable
        ? _screenAwakeController.acquire(ScreenAwakeOwner.preparation)
        : _screenAwakeController.release(ScreenAwakeOwner.preparation);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _isAppResumed = false;
      unawaited(_setPreparationScreenAwake(false));
      if (_hasAnalysisSelection()) {
        ref.read(preparationCameraControllerProvider.notifier).clear();
      }
      final readinessRequest = _activeReadinessRequest;
      if (readinessRequest != null) {
        ref.invalidate(preparationStartGateProvider(readinessRequest));
      }
      unawaited(_imageStreamCoordinator.stop());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _isAppResumed = true;
      unawaited(_refreshPreparationScreenAwake());
      unawaited(_recoverCameraIfAllowed());
    }
  }

  bool _hasAnalysisSelection() {
    return ref.read(selectedExerciseProvider) != null &&
        ref.read(activeAnalysisExerciseProvider) != null;
  }

  Future<void> _recoverCameraIfAllowed() async {
    if (!_isAppResumed ||
        _isRecoveringCamera ||
        !_cameraHandoffCoordinator.canRecoverPreparationCamera ||
        !_hasAnalysisSelection()) {
      return;
    }

    if (mounted) {
      setState(() => _isRecoveringCamera = true);
    }

    try {
      await _imageStreamCoordinator.stop();
      ref.read(preparationCameraControllerProvider.notifier).clear();

      if (!mounted || !_isAppResumed) {
        return;
      }

      _stopObservingCameraGeometry();
      _automaticallyArmedRequest = null;
      ref.invalidate(cameraProvider);
      await ref.read(cameraProvider.future);
    } catch (_) {
      // The camera provider exposes recovery failures through the screen state.
    } finally {
      if (mounted) {
        setState(() => _isRecoveringCamera = false);
      }
    }
  }

  Future<void> _goToPermissionScreen() async {
    if (_isNavigatingToPermission || !mounted) {
      return;
    }

    _isNavigatingToPermission = true;
    await _setPreparationScreenAwake(false);
    await _imageStreamCoordinator.stop();
    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CameraPermissionScreen()),
    );
  }

  Future<void> _startAnalysis() {
    _leavePreparationAfterAnalysis = false;
    return _cameraHandoffCoordinator.run(
      releasePreparation: _releasePreparationForAnalysis,
      runLiveAnalysis: _openLiveAnalysis,
      reclaimPreparation: _resumePreparationAfterAnalysis,
    );
  }

  Future<void> _launchApprovedAnalysis(SetupReadinessRequest request) async {
    final gateProvider = preparationStartGateProvider(request);
    final gateController = ref.read(gateProvider.notifier);
    if (!_canLaunchApprovedAnalysis()) {
      gateController.reset();
      return;
    }
    if (!gateController.beginLaunch()) {
      return;
    }

    try {
      await _startAnalysis();
    } finally {
      if (mounted) {
        ref.invalidate(gateProvider);
      }
    }
  }

  bool _canLaunchApprovedAnalysis() {
    final cameraController = ref.read(cameraProvider).asData?.value;
    final cameraValue = cameraController == null
        ? null
        : safeCameraValue(cameraController);
    return ref.read(exerciseConfigProvider).hasValue &&
        !_isRecoveringCamera &&
        cameraValue?.isInitialized == true &&
        cameraValue?.previewSize != null &&
        _cameraHandoffCoordinator.canUsePreparationCamera;
  }

  void _scheduleAutomaticPreparationArm({
    required SetupReadinessRequest? request,
    required bool canArm,
  }) {
    if (!canArm ||
        request == null ||
        _automaticallyArmedRequest == request ||
        _automaticArmScheduled) {
      return;
    }

    _automaticArmScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _automaticArmScheduled = false;
      if (!mounted ||
          _activeReadinessRequest != request ||
          !_canLaunchApprovedAnalysis()) {
        return;
      }

      final gateProvider = preparationStartGateProvider(request);
      final gateState = ref.read(gateProvider);
      if (gateState.phase == PreparationStartGatePhase.idle) {
        ref.read(gateProvider.notifier).arm();
      }
      _automaticallyArmedRequest = request;
    });
  }

  void _cancelPreparationGate(SetupReadinessRequest request) {
    _automaticallyArmedRequest = request;
    ref.read(preparationStartGateProvider(request).notifier).reset();
  }

  Future<void> _releasePreparationForAnalysis() async {
    await _setPreparationScreenAwake(false);
    _stopObservingCameraGeometry();
    await _imageStreamCoordinator.stop();
    if (_hasAnalysisSelection()) {
      ref.read(preparationCameraControllerProvider.notifier).clear();
    }
  }

  Future<void> _openLiveAnalysis() async {
    if (!mounted) {
      return;
    }

    final route = MaterialPageRoute<LiveAnalysisExitDisposition>(
      builder:
          widget.analysisScreenBuilder ?? (_) => const LiveAnalysisScreen(),
    );
    final disposition = await Navigator.push<LiveAnalysisExitDisposition>(
      context,
      route,
    );
    _leavePreparationAfterAnalysis =
        disposition == LiveAnalysisExitDisposition.leavePreparation;
    await route.completed;
  }

  Future<void> _resumePreparationAfterAnalysis() async {
    if (!mounted) {
      return;
    }
    if (_leavePreparationAfterAnalysis) {
      _leavePreparationAfterAnalysis = false;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    if (!_isAppResumed || !_hasAnalysisSelection()) {
      return;
    }

    await _refreshPreparationScreenAwake();
    _automaticallyArmedRequest = null;

    // Recreate the camera after live analysis releases it. Reusing the same
    // native controller can report a streaming state while no longer
    // delivering frames to the new callback on some devices.
    await _recoverCameraIfAllowed();
  }

  void _ensureImageStream(CameraController controller) {
    _observeCameraGeometry(controller);
    _imageStreamCoordinator.ensureStarted(
      controller: controller,
      shouldStart: () =>
          mounted &&
          _isAppResumed &&
          !_isRecoveringCamera &&
          _cameraHandoffCoordinator.canUsePreparationCamera &&
          _hasAnalysisSelection(),
      onFrame: (image, streamController) {
        if (!mounted) {
          return;
        }
        unawaited(
          ref
              .read(preparationCameraControllerProvider.notifier)
              .processCameraImage(
                image,
                streamController.description.sensorOrientation,
                deviceOrientation: _displayDeviceOrientation,
                lensDirection: streamController.description.lensDirection,
              ),
        );
      },
      onError: (_, _) => _recoverCameraAfterStreamError(),
    );
  }

  void _observeCameraGeometry(CameraController controller) {
    if (identical(_observedCameraController, controller)) {
      return;
    }

    _stopObservingCameraGeometry();
    _observedCameraController = controller;
    final value = safeCameraValue(controller);
    _observedDeviceOrientation = value?.deviceOrientation;
    _observedPreviewSize = value?.previewSize;
    controller.addListener(_handleObservedCameraGeometryChanged);
  }

  void _handleObservedCameraGeometryChanged() {
    final controller = _observedCameraController;
    if (!mounted || controller == null) {
      return;
    }

    final value = safeCameraValue(controller);
    final nextOrientation = value?.deviceOrientation;
    final nextPreviewSize = value?.previewSize;
    if (_observedDeviceOrientation == nextOrientation &&
        _observedPreviewSize == nextPreviewSize) {
      return;
    }

    _observedDeviceOrientation = nextOrientation;
    _observedPreviewSize = nextPreviewSize;
    setState(() {});
  }

  void _stopObservingCameraGeometry() {
    _observedCameraController?.removeListener(
      _handleObservedCameraGeometryChanged,
    );
    _observedCameraController = null;
    _observedDeviceOrientation = null;
    _observedPreviewSize = null;
  }

  void _recoverCameraAfterStreamError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_recoverCameraIfAllowed());
      }
    });
  }

  Future<void> _showPreparationGuide({
    required String exerciseName,
    required String startPoseTitle,
    required String startPoseHint,
    required List<String> instructions,
    required bool voiceCoachEnabled,
  }) {
    final localizations = AppLocalizations.of(context);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: localizations.close,
      barrierColor: Colors.black.withValues(alpha: 0.76),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, _) {
        return PreparationGuideOverlay(
          exerciseName: exerciseName,
          startPoseTitle: startPoseTitle,
          startPoseHint: startPoseHint,
          instructions: instructions,
          voiceCoachEnabled: voiceCoachEnabled,
          onClose: () => Navigator.of(dialogContext).pop(),
        );
      },
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final viewportOrientation = MediaQuery.orientationOf(context);
    final viewportLayout = AppLayout.of(context);
    final selectedExercise = ref.watch(selectedExerciseProvider);
    final activeExercise = ref.watch(activeAnalysisExerciseProvider);

    if (selectedExercise == null || activeExercise == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(localizations.preparation),
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        body: AnalysisSelectionRequiredView(
          title: localizations.selectExerciseBeforePreparationTitle,
          message: localizations.selectExerciseBeforePreparationMessage,
          onSelectExercise: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const ExerciseSelectionScreen(),
              ),
            );
          },
        ),
      );
    }

    final settings = ref.watch(runtimeWorkoutSettingsProvider);
    final configState = ref.watch(exerciseConfigProvider);
    final cameraState = ref.watch(cameraProvider);
    final definition = const ExerciseCatalog().definitionFor(activeExercise);
    final setupViewData = mapExerciseSetupToViewData(
      definition: definition,
      localizations: localizations,
    );
    final isFallback = selectedExercise != activeExercise;
    final isConfigReady = configState.hasValue;
    final cameraController = cameraState.asData?.value;
    final cameraValue = cameraController == null
        ? null
        : safeCameraValue(cameraController);
    final cameraGeometry = const PreparationCameraGeometryResolver().resolve(
      previewSize: cameraValue?.previewSize,
      deviceOrientation: _displayDeviceOrientation,
      viewportOrientation: viewportOrientation,
    );
    final isCameraReady =
        !_isRecoveringCamera &&
        cameraValue?.isInitialized == true &&
        cameraGeometry != null;
    final isMirrored =
        cameraController?.description.lensDirection ==
        CameraLensDirection.front;
    final readinessRequest = cameraGeometry == null
        ? null
        : (
            imageWidth: cameraGeometry.imageSize.width,
            imageHeight: cameraGeometry.imageSize.height,
            mirrorHorizontally: isMirrored,
          );
    _activeReadinessRequest = readinessRequest;
    final startGateProvider = readinessRequest == null
        ? null
        : preparationStartGateProvider(readinessRequest);
    if (readinessRequest != null && startGateProvider != null) {
      ref.listen<PreparationStartGateState>(startGateProvider, (
        previous,
        next,
      ) {
        if (previous?.phase == PreparationStartGatePhase.countingDown &&
            next.phase == PreparationStartGatePhase.approved) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(_launchApprovedAnalysis(readinessRequest));
            }
          });
        }
      });
    }
    final startGateView = startGateProvider == null
        ? null
        : ref.watch(
            startGateProvider.select(
              (state) =>
                  (phase: state.phase, countdownValue: state.countdownValue),
            ),
          );
    final startGatePhase = startGateView?.phase;
    final countdownValue =
        startGatePhase == PreparationStartGatePhase.countingDown
        ? startGateView?.countdownValue
        : null;
    final activeExerciseTitle = localizations.exerciseTitle(activeExercise.id);
    final selectedExerciseTitle = localizations.exerciseTitle(
      selectedExercise.id,
    );
    final fallbackMessage = isFallback
        ? localizations.unsupportedExerciseFallback(
            selectedExerciseTitle,
            activeExerciseTitle,
          )
        : null;
    final canArmPreparation =
        isConfigReady &&
        isCameraReady &&
        startGatePhase == PreparationStartGatePhase.idle &&
        _cameraHandoffCoordinator.canUsePreparationCamera;
    final isPreparing =
        configState.isLoading || cameraState.isLoading || _isRecoveringCamera;

    _scheduleAutomaticPreparationArm(
      request: readinessRequest,
      canArm: canArmPreparation,
    );

    final cameraSurface = PreparationCameraSurface(
      cameraState: cameraState,
      geometry: cameraGeometry,
      viewportOrientation: viewportOrientation,
      isRecovering: _isRecoveringCamera,
      startPoseTemplate: setupViewData.startPoseTemplate,
      startPoseGuideTitle: setupViewData.startPoseGuideTitle,
      countdownValue: countdownValue,
      onControllerReady: _ensureImageStream,
      onRetry: () => unawaited(_recoverCameraIfAllowed()),
      onCheckPermission: () => unawaited(_goToPermissionScreen()),
    );
    final compactSummary =
        '${setupViewData.cameraViewLabel} • ${setupViewData.setupPositionLabel}';
    void openGuide() {
      unawaited(
        _showPreparationGuide(
          exerciseName: activeExerciseTitle,
          startPoseTitle: setupViewData.startPoseGuideTitle,
          startPoseHint: setupViewData.startPoseGuideHint,
          instructions: setupViewData.orderedInstructions,
          voiceCoachEnabled: settings.voiceCoachEnabled,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: viewportLayout.isLandscape
          ? null
          : AppBar(
              title: Text(localizations.preparation),
              backgroundColor: Colors.black,
              elevation: 0,
              actions: [
                PreparationGuideAction(
                  compact:
                      viewportLayout.isCompact || viewportLayout.hasLargeText,
                  onPressed: openGuide,
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = AppLayout.of(context, constraints: constraints);
            final cameraLayout = AppCameraLayoutSpec.resolve(
              layout: layout,
              constraints: constraints,
            );
            final compactPanel =
                layout.isCompact ||
                layout.hasLargeText ||
                cameraLayout.usesSidePanel;
            final header = PreparationHeader(
              exerciseName: activeExerciseTitle,
              summary: compactSummary,
              compact: compactPanel,
            );
            final notices = PreparationNotices(
              fallbackMessage: fallbackMessage,
              hasConfigError: configState.hasError,
              onRetryConfig: () => ref.invalidate(exerciseConfigProvider),
            );
            final cameraStage = PreparationCameraStage(
              aspectRatio:
                  cameraGeometry?.aspectRatio ??
                  (layout.isLandscape ? 4 / 3 : 3 / 4),
              child: cameraSurface,
            );
            final readinessPanel = readinessRequest == null
                ? const SizedBox.shrink()
                : PreparationReadinessPanel(
                    request: readinessRequest,
                    compact: compactPanel,
                  );
            final startControls = PreparationStartGateControls(
              phase: startGatePhase,
              countdownValue: countdownValue,
              isConfigReady: isConfigReady,
              isCameraReady: isCameraReady,
              isPreparing: isPreparing,
              compact: compactPanel,
              onArm: canArmPreparation && startGateProvider != null
                  ? () => ref.read(startGateProvider.notifier).arm()
                  : null,
              onCancel:
                  (startGatePhase == PreparationStartGatePhase.monitoring ||
                          startGatePhase ==
                              PreparationStartGatePhase.overrideAvailable ||
                          startGatePhase ==
                              PreparationStartGatePhase.countingDown) &&
                      readinessRequest != null
                  ? () => _cancelPreparationGate(readinessRequest)
                  : null,
              onOverride:
                  startGatePhase ==
                          PreparationStartGatePhase.overrideAvailable &&
                      isConfigReady &&
                      isCameraReady &&
                      _cameraHandoffCoordinator.canUsePreparationCamera &&
                      startGateProvider != null
                  ? () => ref.read(startGateProvider.notifier).approveOverride()
                  : null,
            );

            if (cameraLayout.usesSidePanel) {
              return Padding(
                key: const ValueKey<String>('preparation-side-panel-layout'),
                padding: cameraLayout.outerPadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cameraStage),
                    SizedBox(width: cameraLayout.gap),
                    SizedBox(
                      width: cameraLayout.sidePanelWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PreparationLandscapeToolbar(
                            title: localizations.preparation,
                            onBack: () => Navigator.of(context).maybePop(),
                            onGuide: openGuide,
                          ),
                          SizedBox(height: layout.sectionGap),
                          Expanded(
                            child: SingleChildScrollView(
                              key: const ValueKey<String>(
                                'preparation-side-panel-scroll',
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  header,
                                  notices,
                                  SizedBox(height: layout.sectionGap),
                                  readinessPanel,
                                  SizedBox(height: layout.sectionGap),
                                  startControls,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            final cameraHeight =
                (constraints.maxHeight * (layout.hasLargeText ? 0.44 : 0.52))
                    .clamp(layout.isCompact ? 220.0 : 260.0, 560.0)
                    .toDouble();
            return SingleChildScrollView(
              key: const ValueKey<String>('preparation-stacked-layout'),
              padding: cameraLayout.outerPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  notices,
                  SizedBox(height: layout.sectionGap),
                  SizedBox(height: cameraHeight, child: cameraStage),
                  SizedBox(height: layout.sectionGap),
                  readinessPanel,
                  SizedBox(height: layout.sectionGap),
                  startControls,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
