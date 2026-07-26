import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';

import '../../application/exercise_catalog.dart';
import '../camera_image_stream_coordinator.dart';
import '../mappers/exercise_setup_ui_mapper.dart';
import '../mappers/setup_readiness_ui_mapper.dart';
import '../models/preparation_start_gate_state.dart';
import '../models/setup_readiness_view_data.dart';
import '../preparation_live_camera_handoff_coordinator.dart';
import '../providers/active_analysis_exercise_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/exercise_config_provider.dart';
import '../providers/preparation_camera_controller.dart';
import '../providers/preparation_countdown_feedback.dart';
import '../providers/preparation_readiness_controller.dart';
import '../providers/preparation_start_gate_controller.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/screen_awake_controller.dart';
import '../widgets/analysis_selection_required_view.dart';
import '../widgets/preparation_camera_surface.dart';
import '../widgets/preparation_start_gate_controls.dart';
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
  SetupReadinessRequest? _activeReadinessRequest;

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
  void dispose() {
    unawaited(_setPreparationScreenAwake(false));
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
        : _safeCameraValue(cameraController);
    return ref.read(exerciseConfigProvider).hasValue &&
        !_isRecoveringCamera &&
        cameraValue?.isInitialized == true &&
        cameraValue?.previewSize != null &&
        _cameraHandoffCoordinator.canUsePreparationCamera;
  }

  Future<void> _releasePreparationForAnalysis() async {
    await _setPreparationScreenAwake(false);
    await _imageStreamCoordinator.stop();
    if (_hasAnalysisSelection()) {
      ref.read(preparationCameraControllerProvider.notifier).clear();
    }
  }

  Future<void> _openLiveAnalysis() async {
    if (!mounted) {
      return;
    }

    final route = MaterialPageRoute<void>(
      builder:
          widget.analysisScreenBuilder ?? (_) => const LiveAnalysisScreen(),
    );
    await Navigator.push<void>(context, route);
    await route.completed;
  }

  Future<void> _resumePreparationAfterAnalysis() async {
    if (!mounted || !_isAppResumed || !_hasAnalysisSelection()) {
      return;
    }

    await _refreshPreparationScreenAwake();

    // Recreate the camera after live analysis releases it. Reusing the same
    // native controller can report a streaming state while no longer
    // delivering frames to the new callback on some devices.
    await _recoverCameraIfAllowed();
  }

  void _ensureImageStream(CameraController controller) {
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
        final cameraValue = _safeCameraValue(streamController);
        unawaited(
          ref
              .read(preparationCameraControllerProvider.notifier)
              .processCameraImage(
                image,
                streamController.description.sensorOrientation,
                deviceOrientation: cameraValue?.deviceOrientation,
                lensDirection: streamController.description.lensDirection,
              ),
        );
      },
      onError: (_, _) => _recoverCameraAfterStreamError(),
    );
  }

  void _recoverCameraAfterStreamError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_recoverCameraIfAllowed());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
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
        : _safeCameraValue(cameraController);
    final isCameraReady =
        !_isRecoveringCamera &&
        cameraValue?.isInitialized == true &&
        cameraValue?.previewSize != null;
    final previewSize = cameraValue?.previewSize;
    final isMirrored =
        cameraController?.description.lensDirection ==
        CameraLensDirection.front;
    final readinessRequest = previewSize == null
        ? null
        : (
            imageWidth: previewSize.height,
            imageHeight: previewSize.width,
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
        final countdownChanged =
            next.phase == PreparationStartGatePhase.countingDown &&
            (previous?.phase != PreparationStartGatePhase.countingDown ||
                previous?.countdownValue != next.countdownValue);
        if (countdownChanged) {
          unawaited(ref.read(preparationCountdownFeedbackProvider).tick());
        }

        if (previous?.phase == PreparationStartGatePhase.countingDown &&
            next.phase == PreparationStartGatePhase.approved) {
          unawaited(ref.read(preparationCountdownFeedbackProvider).complete());
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
    final title = localizations.preparationForExercise(activeExerciseTitle);
    final description = localizations.preparationSubtitle;
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(localizations.preparation),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  if (fallbackMessage != null) ...[
                    const SizedBox(height: 16),
                    _PreparationMessageCard(message: fallbackMessage),
                  ],
                  if (configState.hasError) ...[
                    const SizedBox(height: 16),
                    _PreparationConfigError(
                      onRetry: () => ref.invalidate(exerciseConfigProvider),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: PreparationCameraSurface(
                        cameraState: cameraState,
                        isRecovering: _isRecoveringCamera,
                        countdownValue: countdownValue,
                        onControllerReady: _ensureImageStream,
                        onRetry: () => unawaited(_recoverCameraIfAllowed()),
                        onCheckPermission: () =>
                            unawaited(_goToPermissionScreen()),
                      ),
                    ),
                  ),
                  if (isCameraReady && readinessRequest != null) ...[
                    const SizedBox(height: 18),
                    _PreparationReadinessCard(request: readinessRequest),
                  ],
                  const SizedBox(height: 18),
                  _PreparationGuidanceCard(
                    guidanceItems: setupViewData.orderedInstructions,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
              child: PreparationStartGateControls(
                phase: startGatePhase,
                countdownValue: countdownValue,
                isConfigReady: isConfigReady,
                isCameraReady: isCameraReady,
                isPreparing: isPreparing,
                onArm: canArmPreparation && startGateProvider != null
                    ? () => ref.read(startGateProvider.notifier).arm()
                    : null,
                onCancel:
                    (startGatePhase == PreparationStartGatePhase.monitoring ||
                            startGatePhase ==
                                PreparationStartGatePhase.overrideAvailable ||
                            startGatePhase ==
                                PreparationStartGatePhase.countingDown) &&
                        startGateProvider != null
                    ? () => ref.read(startGateProvider.notifier).reset()
                    : null,
                onOverride:
                    startGatePhase ==
                            PreparationStartGatePhase.overrideAvailable &&
                        isConfigReady &&
                        isCameraReady &&
                        _cameraHandoffCoordinator.canUsePreparationCamera &&
                        startGateProvider != null
                    ? () =>
                          ref.read(startGateProvider.notifier).approveOverride()
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreparationMessageCard extends StatelessWidget {
  const _PreparationMessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.35,
        ),
      ),
    );
  }
}

class _PreparationConfigError extends StatelessWidget {
  const _PreparationConfigError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppLocalizations.of(context).analysisConfigLoadFailed,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
    );
  }
}

class _PreparationReadinessCard extends ConsumerWidget {
  const _PreparationReadinessCard({required this.request});

  final SetupReadinessRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final viewData = mapSetupReadinessToViewData(
      localizations: localizations,
      readinessSnapshot: ref.watch(preparationReadinessStateProvider(request)),
    );
    final statusColor = _readinessColor(viewData.visualState);

    return Container(
      key: const ValueKey<String>('preparation-readiness-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _readinessIcon(viewData.visualState),
                color: statusColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  localizations.preparationReadinessTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                viewData.statusLabel,
                key: const ValueKey<String>('preparation-readiness-status'),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...viewData.checks.map(_PreparationReadinessCheckRow.new),
        ],
      ),
    );
  }
}

class _PreparationReadinessCheckRow extends StatelessWidget {
  const _PreparationReadinessCheckRow(this.item);

  final SetupReadinessCheckItem item;

  @override
  Widget build(BuildContext context) {
    final color = _checkColor(item.state);
    return Padding(
      key: ValueKey<String>('preparation-check-${item.type.name}'),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(_checkIcon(item.state), color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                color: item.state == SetupReadinessCheckState.pending
                    ? Colors.white54
                    : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _readinessColor(SetupReadinessVisualState state) {
  return switch (state) {
    SetupReadinessVisualState.checking => Colors.amberAccent,
    SetupReadinessVisualState.needsAdjustment => Colors.orangeAccent,
    SetupReadinessVisualState.ready => Colors.greenAccent,
  };
}

IconData _readinessIcon(SetupReadinessVisualState state) {
  return switch (state) {
    SetupReadinessVisualState.checking => Icons.manage_search_rounded,
    SetupReadinessVisualState.needsAdjustment => Icons.tune_rounded,
    SetupReadinessVisualState.ready => Icons.check_circle_rounded,
  };
}

Color _checkColor(SetupReadinessCheckState state) {
  return switch (state) {
    SetupReadinessCheckState.pending => Colors.white38,
    SetupReadinessCheckState.needsAdjustment => Colors.orangeAccent,
    SetupReadinessCheckState.complete => Colors.greenAccent,
  };
}

IconData _checkIcon(SetupReadinessCheckState state) {
  return switch (state) {
    SetupReadinessCheckState.pending => Icons.radio_button_unchecked_rounded,
    SetupReadinessCheckState.needsAdjustment => Icons.tune_rounded,
    SetupReadinessCheckState.complete => Icons.check_circle_rounded,
  };
}

class _PreparationGuidanceCard extends StatelessWidget {
  const _PreparationGuidanceCard({required this.guidanceItems});

  final List<String> guidanceItems;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: guidanceItems
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.greenAccent,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

CameraValue? _safeCameraValue(CameraController controller) {
  try {
    return controller.value;
  } catch (_) {
    return null;
  }
}
