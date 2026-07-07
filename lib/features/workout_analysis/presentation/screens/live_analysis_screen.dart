import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../application/engine_kind.dart';
import '../../application/workout_state.dart';
import '../../domain/models/exercise_config.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/workout_session.dart';
import '../providers/active_analysis_exercise_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/completed_session_provider.dart';
import '../providers/exercise_config_provider.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/session_repository_provider.dart';
import '../providers/user_sessions_snapshot_provider.dart';
import '../providers/workout_controller.dart';
import '../widgets/analysis_selection_required_view.dart';
import '../widgets/pose_painter.dart';
import 'camera_permission_screen.dart';
import 'exercise_selection_screen.dart';
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
  ExerciseType? _activeSessionExercise;
  DateTime? _sessionStartedAt;
  int _lastObservedRepCount = 0;
  double _repScoreSum = 0;
  int _scoredRepCount = 0;
  double _bestScore = 0;
  int _formWarningCount = 0;
  bool _previousFormBad = false;
  double _lastObservedHoldSeconds = 0;
  double _totalHoldSeconds = 0;
  double _bestHoldSeconds = 0;
  int _formBreakCount = 0;
  bool _previousHoldFormBreak = false;
  bool _isFinishingSession = false;
  bool _isRecoveringCameraRefreshInFlight = false;
  bool _showCalibrationPanel = false;
  Timer? _recoveryTimer;
  ProviderSubscription<AsyncValue<ExerciseConfig>>? _exerciseConfigSubscription;
  ProviderSubscription<WorkoutState>? _workoutStateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_hasAnalysisSelection()) {
      _startSessionLifecycle();
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
    _recoveryTimer?.cancel();
    _exerciseConfigSubscription?.close();
    _workoutStateSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _attachWorkoutStateSubscription() {
    _workoutStateSubscription ??= ref.listenManual<WorkoutState>(
      workoutControllerProvider,
      _collectSessionMetrics,
    );
  }

  bool _hasAnalysisSelection() {
    final selectedExercise = ref.read(selectedExerciseProvider);
    final activeExercise = ref.read(activeAnalysisExerciseProvider);

    return selectedExercise != null && activeExercise != null;
  }

  void _startSessionLifecycle() {
    final activeExercise = ref.read(activeAnalysisExerciseProvider);
    if (activeExercise == null) {
      return;
    }

    _activeSessionExercise = activeExercise;
    _sessionStartedAt = DateTime.now();
    _lastObservedRepCount = 0;
    _repScoreSum = 0;
    _scoredRepCount = 0;
    _bestScore = 0;
    _formWarningCount = 0;
    _previousFormBad = false;
    _lastObservedHoldSeconds = 0;
    _totalHoldSeconds = 0;
    _bestHoldSeconds = 0;
    _formBreakCount = 0;
    _previousHoldFormBreak = false;
    _isFinishingSession = false;
    ref.read(completedSessionProvider.notifier).state = null;
  }

  void _collectSessionMetrics(WorkoutState? _, WorkoutState next) {
    // Collect from state transitions so save/summary does not depend on the final frame.
    final repDelta = next.repCount - _lastObservedRepCount;
    if (repDelta > 0) {
      _repScoreSum += next.lastRepScore * repDelta;
      _scoredRepCount += repDelta;

      if (next.lastRepScore > _bestScore) {
        _bestScore = next.lastRepScore;
      }
    }

    if (!_previousFormBad && next.isFormBad) {
      _formWarningCount += 1;
    }

    if (next.isHolding) {
      final holdDelta = next.currentHoldSeconds - _lastObservedHoldSeconds;
      if (holdDelta > 0) {
        _totalHoldSeconds += holdDelta;
      }
    }

    if (next.bestHoldSeconds > _bestHoldSeconds) {
      _bestHoldSeconds = next.bestHoldSeconds;
    }

    if (!_previousHoldFormBreak && next.hadHoldFormBreak) {
      _formBreakCount += 1;
    }

    _lastObservedRepCount = next.repCount;
    _previousFormBad = next.isFormBad;
    _lastObservedHoldSeconds = next.isHolding ? next.currentHoldSeconds : 0;
    _previousHoldFormBreak = next.hadHoldFormBreak;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isFinishingSession) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Hide preview before teardown so CameraPreview never builds a disposed controller.
      _markCameraRecovering();
      unawaited(_stopImageStreamIfNeeded());
      return;
    }

    if (state == AppLifecycleState.resumed) {
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
    if (_isFinishingSession || _isRecoveringCameraRefreshInFlight) return;
    if (_isRecoveringCamera && ref.read(cameraProvider).isLoading) return;
    if (!_hasAnalysisSelection()) {
      return;
    }

    _isRecoveringCameraRefreshInFlight = true;
    _markCameraRecovering();

    try {
      final status = await Permission.camera.status;
      if (!mounted || _isFinishingSession) return;

      if (!status.isGranted) {
        await _stopImageStreamIfNeeded();
        if (!mounted || _isFinishingSession) return;

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

  Future<void> _finishSession(WorkoutState workoutState) async {
    if (_isFinishingSession || !mounted) return;

    setState(() => _isFinishingSession = true);

    final repositoryUserId = ref.read(authRepositoryProvider).currentUserId;
    final providerUserId = ref.read(currentUserIdProvider);
    final ownerId = repositoryUserId ?? providerUserId;
    if (ownerId == null) {
      if (!mounted) return;

      setState(() => _isFinishingSession = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analiz oturumu hazırlanamadı. Lütfen tekrar dene.'),
        ),
      );
      return;
    }

    await _stopImageStreamIfNeeded();
    if (!mounted) return;

    _collectSessionMetrics(null, workoutState);

    final activeSessionExercise = _activeSessionExercise;
    if (activeSessionExercise == null) {
      setState(() => _isFinishingSession = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analiz icin once gecerli bir hareket secmelisin.'),
        ),
      );
      return;
    }

    final endedAt = DateTime.now();
    final startedAt = _sessionStartedAt ?? endedAt;
    final durationSec = endedAt.difference(startedAt).inSeconds;
    final isHoldAnalysis = workoutState.analysisKind == EngineKind.hold;
    final session = WorkoutSession(
      id: 'session_${endedAt.microsecondsSinceEpoch}',
      ownerId: ownerId,
      exerciseType: activeSessionExercise.id,
      analysisKind: workoutState.analysisKind.name,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSec: durationSec < 0 ? 0 : durationSec,
      totalReps: workoutState.repCount,
      averageScore: isHoldAnalysis
          ? 0
          : (_scoredRepCount == 0 ? 0 : _repScoreSum / _scoredRepCount),
      bestScore: isHoldAnalysis ? 0 : _bestScore,
      formWarningCount: isHoldAnalysis ? 0 : _formWarningCount,
      totalHoldSeconds: _totalHoldSeconds,
      bestHoldSeconds: _bestHoldSeconds,
      formBreakCount: _formBreakCount,
    );

    try {
      await ref.read(sessionRepositoryProvider).saveSession(session);
      // Shared Home/Goals/Achievements data is one-shot cached and must refetch.
      ref.invalidate(userSessionsSnapshotProvider);
    } catch (_) {
      if (!mounted) return;

      setState(() => _isFinishingSession = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oturum kaydedilemedi. Lütfen tekrar dene.'),
        ),
      );
      return;
    }

    ref.read(completedSessionProvider.notifier).state = session;
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WorkoutSummaryScreen()),
    );

    if (mounted) {
      setState(() => _isFinishingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedExercise = ref.watch(selectedExerciseProvider);
    final activeExercise = ref.watch(activeAnalysisExerciseProvider);

    if (selectedExercise == null || activeExercise == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: AnalysisSelectionRequiredView(
          title: 'Canli analize girmek icin hareket sec',
          message:
              'Canli analiz ekrani yalnizca gecerli bir hareket seciminden sonra acilabilir.',
          onSelectExercise: _goToExerciseSelectionScreen,
        ),
      );
    }

    if (_isFinishingSession) {
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

          if (!_isFinishingSession && !controllerValue.isStreamingImages) {
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
                  ),
                ),
              Positioned(
                top: topInset + 12,
                right: 14,
                child: TextButton.icon(
                  onPressed: _isFinishingSession
                      ? null
                      : () => unawaited(_finishSession(workoutState)),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Bitir'),
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
                            label: isHoldAnalysis ? 'HOLD' : 'TEKRAR',
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
                            label: isHoldAnalysis ? 'EN IYI' : 'SKOR',
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
              if (_showCalibrationPanel)
                Positioned(
                  top: topInset + 152,
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
                        workoutState.feedbackMessage.toUpperCase(),
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
                      'DURUM: ${workoutState.currentPhase} | ANALİZ FPS: ${workoutState.analysisFps.toStringAsFixed(0)}',
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

          return Center(child: Text('Hata: $error'));
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

class _ExerciseConfigLoadingView extends StatelessWidget {
  const _ExerciseConfigLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.greenAccent),
          SizedBox(height: 16),
          Text(
            'Analiz yapilandirmasi hazirlaniyor...',
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
            const Text(
              'Analiz yapilandirmasi yuklenemedi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Egzersiz ayarlari hazir olmadan canli analiz baslatilamaz.',
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
              label: const Text('Tekrar Dene'),
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
            'Kamera yeniden hazırlanıyor...',
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
            const Text(
              'Kamera izni gerekli',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Analize devam etmek için kamera iznini kontrol et.',
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
              label: const Text('İzni Kontrol Et'),
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
            if (isHoldAnalysis) ...[
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
              _DebugMetricRow(
                label: 'coverage',
                value: _formatHoldCoverage(metrics),
              ),
            ] else ...[
              _DebugMetricRow(
                label: 'knee/current',
                value: _formatAngle(workoutState.currentAngle),
              ),
              _DebugMetricRow(
                label: 'back-angle',
                value: _formatAngle(metrics.currentBackAngle),
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
              _DebugMetricRow(
                label: 'coverage',
                value: _formatRangeRepCoverage(metrics),
              ),
              _DebugMetricRow(
                label: 'side coverage',
                value: _formatRangeRepSideCoverage(metrics),
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
                label: 'invalid reason',
                value: metrics.rangeRepInvalidReason ?? '--',
              ),
            ],
            _DebugMetricRow(
              label: isHoldAnalysis ? 'body target' : 'threshold',
              value: _formatAngle(metrics.formThreshold),
            ),
            _DebugMetricRow(
              label: 'isFormBad',
              value: workoutState.isFormBad ? 'true' : 'false',
            ),
            if (isHoldAnalysis) ...[
              _DebugMetricRow(
                label: 'isHolding',
                value: workoutState.isHolding ? 'true' : 'false',
              ),
              _DebugMetricRow(
                label: 'hold break',
                value: workoutState.hadHoldFormBreak ? 'true' : 'false',
              ),
            ] else ...[
              _DebugMetricRow(
                label: 'rep worst back',
                value: _formatAngle(metrics.currentRepWorstBackAngle),
              ),
              _DebugMetricRow(
                label: 'rep violation',
                value: metrics.currentRepHadFormViolation ? 'true' : 'false',
              ),
            ],
            if (!isHoldAnalysis && metrics.hasLastRepBreakdown) ...[
              const Divider(color: Colors.white24, height: 14),
              Text(
                'last rep: score ${workoutState.lastRepScore.toStringAsFixed(1)} | '
                'rom ${metrics.lastRepRomScore.toStringAsFixed(1)} | '
                'desc ${metrics.lastRepDescentScore.toStringAsFixed(1)} | '
                'asc ${metrics.lastRepAscentScoreCandidate.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                'last form: worst ${_formatAngle(metrics.lastRepWorstBackAngle)} | '
                'violation ${metrics.lastRepHadFormViolation ? 'true' : 'false'}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
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

String _formatMilliseconds(int milliseconds) {
  return '${milliseconds}ms';
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
