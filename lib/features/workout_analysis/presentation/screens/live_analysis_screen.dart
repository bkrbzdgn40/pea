import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../application/workout_state.dart';
import '../../domain/models/workout_session.dart';
import '../providers/camera_provider.dart';
import '../providers/completed_session_provider.dart';
import '../providers/session_repository_provider.dart';
import '../providers/user_sessions_snapshot_provider.dart';
import '../providers/workout_controller.dart';
import '../widgets/pose_painter.dart';
import 'camera_permission_screen.dart';
import 'workout_summary_screen.dart';

class LiveAnalysisScreen extends ConsumerStatefulWidget {
  const LiveAnalysisScreen({super.key});

  @override
  ConsumerState<LiveAnalysisScreen> createState() => _LiveAnalysisScreenState();
}

class _LiveAnalysisScreenState extends ConsumerState<LiveAnalysisScreen>
    with WidgetsBindingObserver {
  bool _isNavigatingToPermission = false;
  bool _isRecoveringCamera = false;
  DateTime? _sessionStartedAt;
  int _lastObservedRepCount = 0;
  double _repScoreSum = 0;
  int _scoredRepCount = 0;
  double _bestScore = 0;
  int _formWarningCount = 0;
  bool _previousFormBad = false;
  bool _isFinishingSession = false;
  bool _isRecoveringCameraRefreshInFlight = false;
  bool _showCalibrationPanel = false;
  Timer? _recoveryTimer;
  ProviderSubscription<WorkoutState>? _workoutStateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSessionLifecycle();
    _workoutStateSubscription = ref.listenManual<WorkoutState>(
      workoutControllerProvider,
      _collectSessionMetrics,
    );
  }

  @override
  void dispose() {
    _recoveryTimer?.cancel();
    _workoutStateSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startSessionLifecycle() {
    _sessionStartedAt = DateTime.now();
    _lastObservedRepCount = 0;
    _repScoreSum = 0;
    _scoredRepCount = 0;
    _bestScore = 0;
    _formWarningCount = 0;
    _previousFormBad = false;
    _isFinishingSession = false;
    ref.read(completedSessionProvider.notifier).state = null;
  }

  void _collectSessionMetrics(WorkoutState? _, WorkoutState next) {
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

    _lastObservedRepCount = next.repCount;
    _previousFormBad = next.isFormBad;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isFinishingSession) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
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

    final endedAt = DateTime.now();
    final startedAt = _sessionStartedAt ?? endedAt;
    final durationSec = endedAt.difference(startedAt).inSeconds;
    final session = WorkoutSession(
      id: 'session_${endedAt.microsecondsSinceEpoch}',
      ownerId: ownerId,
      exerciseType: 'squat',
      startedAt: startedAt,
      endedAt: endedAt,
      durationSec: durationSec < 0 ? 0 : durationSec,
      totalReps: workoutState.repCount,
      averageScore: _scoredRepCount == 0 ? 0 : _repScoreSum / _scoredRepCount,
      bestScore: _bestScore,
      formWarningCount: _formWarningCount,
    );

    try {
      await ref.read(sessionRepositoryProvider).saveSession(session);
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
  // Kamera önizlemesini ve analiz katmanını çizer.
  Widget build(BuildContext context) {
    if (_isFinishingSession) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: _CameraRecoveryView(),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetricCard(
                      label: 'TEKRAR',
                      value: workoutState.repCount.toString(),
                    ),
                    _MetricCard(
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
                    _MetricCard(
                      label: 'SKOR',
                      value: workoutState.lastRepScore.toInt().toString(),
                      color: Colors.greenAccent,
                    ),
                  ],
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
  // Tek bir metrik kartını çizer.
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.w900,
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
            _DebugMetricRow(
              label: 'knee/current',
              value: _formatAngle(workoutState.currentAngle),
            ),
            _DebugMetricRow(
              label: 'back-angle',
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
