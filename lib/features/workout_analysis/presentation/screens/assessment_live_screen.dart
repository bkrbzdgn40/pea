import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';

import '../../domain/models/assessment_models.dart';
import '../providers/assessment_live_controller.dart';
import '../providers/camera_provider.dart';
import '../providers/selected_assessment_provider.dart';
import '../widgets/pose_painter.dart';

class AssessmentLiveScreen extends ConsumerStatefulWidget {
  const AssessmentLiveScreen({super.key});

  @override
  ConsumerState<AssessmentLiveScreen> createState() =>
      _AssessmentLiveScreenState();
}

class _AssessmentLiveScreenState extends ConsumerState<AssessmentLiveScreen> {
  CameraController? _streamController;
  bool _startingStream = false;
  bool _ownsImageStream = false;

  @override
  void dispose() {
    final controller = _streamController;
    if (_ownsImageStream &&
        controller != null &&
        controller.value.isStreamingImages) {
      unawaited(controller.stopImageStream());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final selection = ref.watch(selectedAssessmentProvider);
    if (selection == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            localizations.chooseAssessmentFirst,
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final cameraState = ref.watch(cameraProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: cameraState.when(
        data: (controller) {
          if (!controller.value.isInitialized ||
              controller.value.previewSize == null) {
            return const Center(child: CircularProgressIndicator());
          }
          _ensureImageStream(controller);
          final previewSize = controller.value.previewSize!;
          final imageSize = Size(previewSize.height, previewSize.width);
          final isMirrored =
              controller.description.lensDirection == CameraLensDirection.front;

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              _AssessmentPoseOverlay(
                imageSize: imageSize,
                isMirrored: isMirrored,
              ),
              Positioned(
                top: topInset + 12,
                left: 14,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Positioned(
                top: topInset + 16,
                left: 72,
                right: 72,
                child: Text(
                  _assessmentTitle(localizations, selection.type),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                  ),
                ),
              ),
              _AssessmentStatusOverlay(topInset: topInset),
              _AssessmentActionOverlay(
                onRetry: () {
                  ref.read(assessmentLiveControllerProvider.notifier).retry();
                },
                onClose: () => Navigator.pop(context),
                onComplete: () async {
                  await _stopImageStream();
                  ref
                      .read(assessmentLiveControllerProvider.notifier)
                      .complete();
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              localizations.cameraOpenFailed(error),
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  void _ensureImageStream(CameraController controller) {
    if (_startingStream ||
        ref.read(assessmentLiveControllerProvider).snapshot.isCompleted) {
      return;
    }
    if (_ownsImageStream &&
        identical(_streamController, controller) &&
        controller.value.isStreamingImages) {
      return;
    }

    _startingStream = true;
    _streamController = controller;
    unawaited(_claimImageStream(controller));
  }

  Future<void> _claimImageStream(CameraController controller) async {
    try {
      // CameraController supports a single image-stream callback. A controller
      // can survive route transitions while still streaming to the previous
      // screen, which leaves assessment preview visible but starves this
      // controller of frames. Take explicit ownership before attaching the
      // assessment callback.
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      if (!mounted ||
          ref.read(assessmentLiveControllerProvider).snapshot.isCompleted) {
        return;
      }

      await controller.startImageStream((image) {
        unawaited(
          ref
              .read(assessmentLiveControllerProvider.notifier)
              .processCameraImage(
                image,
                controller.description.sensorOrientation,
              ),
        );
      });
      _ownsImageStream = true;
    } catch (_) {
      _ownsImageStream = false;
    } finally {
      _startingStream = false;
    }
  }

  Future<void> _stopImageStream() async {
    final controller = _streamController;
    if (!_ownsImageStream ||
        controller == null ||
        !controller.value.isStreamingImages) {
      return;
    }
    try {
      await controller.stopImageStream();
      _ownsImageStream = false;
    } catch (_) {
      // Keep assessment completion usable during camera teardown races.
    }
  }
}

class _AssessmentPoseOverlay extends ConsumerWidget {
  const _AssessmentPoseOverlay({
    required this.imageSize,
    required this.isMirrored,
  });

  final Size imageSize;
  final bool isMirrored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landmarks = ref.watch(
      assessmentLiveControllerProvider.select((state) => state.landmarks),
    );
    if (landmarks == null || landmarks.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: PosePainter(
        landmarks,
        imageSize,
        isFormBad: false,
        isMirrored: isMirrored,
      ),
    );
  }
}

class _AssessmentStatusOverlay extends ConsumerWidget {
  const _AssessmentStatusOverlay({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      assessmentLiveControllerProvider.select(
        (state) => (
          sampleCount: state.snapshot.sampleCount,
          feedback: state.feedbackMessage,
          progressMessage: state.progressMessage,
          progress: state.snapshot.readinessProgress,
        ),
      ),
    );

    return Positioned(
      top: topInset + 70,
      left: 20,
      right: 20,
      child: _AssessmentStatusCard(
        sampleCount: status.sampleCount,
        feedback: status.feedback,
        progressMessage: status.progressMessage,
        progress: status.progress,
      ),
    );
  }
}

class _AssessmentActionOverlay extends ConsumerWidget {
  const _AssessmentActionOverlay({
    required this.onRetry,
    required this.onClose,
    required this.onComplete,
  });

  final VoidCallback onRetry;
  final VoidCallback onClose;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(
      assessmentLiveControllerProvider.select(
        (state) => (
          isCompleted: state.snapshot.isCompleted,
          isReadyToComplete: state.snapshot.isReadyToComplete,
          result: state.snapshot.result,
        ),
      ),
    );
    final localizations = AppLocalizations.of(context);
    final result = action.result;

    return Positioned(
      left: 20,
      right: 20,
      bottom: 28,
      child: action.isCompleted && result != null
          ? _AssessmentResultCard(
              result: result,
              onRetry: onRetry,
              onClose: onClose,
              localizations: localizations,
            )
          : ElevatedButton.icon(
              onPressed: action.isReadyToComplete
                  ? () => unawaited(onComplete())
                  : null,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(localizations.viewResult),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(54),
              ),
            ),
    );
  }
}

class _AssessmentStatusCard extends StatelessWidget {
  const _AssessmentStatusCard({
    required this.sampleCount,
    required this.feedback,
    required this.progressMessage,
    required this.progress,
  });

  final int sampleCount;
  final String feedback;
  final String progressMessage;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(
            feedback,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            minHeight: 5,
            backgroundColor: Colors.white12,
          ),
          const SizedBox(height: 8),
          Text(
            progressMessage,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            localizations.validSamples(sampleCount),
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AssessmentResultCard extends StatelessWidget {
  const _AssessmentResultCard({
    required this.result,
    required this.onRetry,
    required this.onClose,
    required this.localizations,
  });

  final AssessmentResult result;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    final hasSufficientData = result.hasSufficientData;
    final values = hasSufficientData
        ? _resultValues(localizations, result)
        : const <MapEntry<String, String>>[];
    return Container(
      constraints: const BoxConstraints(maxHeight: 380),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xEE111111),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasSufficientData
              ? Colors.greenAccent.withValues(alpha: 0.5)
              : Colors.orangeAccent.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hasSufficientData
                ? localizations.assessmentResult
                : localizations.insufficientMeasurement,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (!hasSufficientData)
            Text(
              localizations.insufficientMeasurementDescription,
              style: TextStyle(color: Colors.white70, height: 1.4),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(color: Colors.white60),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            entry.value,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (!hasSufficientData) ...[
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(localizations.retry),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton(onPressed: onClose, child: Text(localizations.close)),
        ],
      ),
    );
  }
}

String _assessmentTitle(AppLocalizations localizations, AssessmentType type) {
  return localizations.assessmentTitle(type.name);
}

List<MapEntry<String, String>> _resultValues(
  AppLocalizations localizations,
  AssessmentResult result,
) {
  switch (result) {
    case SquatAssessmentResult squat:
      return <MapEntry<String, String>>[
        MapEntry(
          localizations.kneeFlexion,
          _degrees(
            _averageAvailable(
              squat.leftKneeFlexionDegrees,
              squat.rightKneeFlexionDegrees,
            ),
          ),
        ),
        MapEntry(
          localizations.hipReachedKneeHeight,
          switch (squat.reachedHipAtOrBelowKneeHeight) {
            true => localizations.yes,
            false => localizations.no,
            null => '—',
          },
        ),
        MapEntry(
          localizations.torsoInclination,
          _degrees(squat.torsoInclinationAtDeepestDegrees),
        ),
      ];
    case BalanceAssessmentResult balance:
      return <MapEntry<String, String>>[
        MapEntry(localizations.stabilityScore, _score(balance.stabilityScore)),
        MapEntry(
          localizations.continuousStanceDuration,
          _assessmentDuration(localizations, balance.observedDuration),
        ),
      ];
    case ShoulderMobilityAssessmentResult shoulder:
      return <MapEntry<String, String>>[
        MapEntry(
          localizations.leftMaximumElevation,
          _degrees(shoulder.leftMaximumElevationDegrees),
        ),
        MapEntry(
          localizations.rightMaximumElevation,
          _degrees(shoulder.rightMaximumElevationDegrees),
        ),
        MapEntry(
          localizations.leftRightDifference,
          _degrees(shoulder.sideDifferenceDegrees),
        ),
        MapEntry(
          localizations.leftMaximumLateralTorsoInclination,
          _degrees(shoulder.torsoInclinationAtLeftMaximumDegrees),
        ),
        MapEntry(
          localizations.rightMaximumLateralTorsoInclination,
          _degrees(shoulder.torsoInclinationAtRightMaximumDegrees),
        ),
      ];
  }
}

double? _averageAvailable(double? left, double? right) {
  if (left != null && right != null) {
    return (left + right) / 2.0;
  }
  return left ?? right;
}

String _degrees(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(1)}°';
String _score(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(0)} / 100';

String _assessmentDuration(AppLocalizations localizations, Duration duration) {
  final seconds = duration.inMilliseconds / 1000;
  return localizations.secondsValue(seconds);
}
