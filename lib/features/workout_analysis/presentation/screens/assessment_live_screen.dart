import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void dispose() {
    final controller = _streamController;
    if (controller != null && controller.value.isStreamingImages) {
      unawaited(controller.stopImageStream());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(selectedAssessmentProvider);
    if (selection == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Önce bir değerlendirme seçmelisin.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final liveState = ref.watch(assessmentLiveControllerProvider);
    final cameraState = ref.watch(cameraProvider);

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

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              if (liveState.landmarks != null &&
                  liveState.landmarks!.isNotEmpty)
                CustomPaint(
                  painter: PosePainter(
                    liveState.landmarks!,
                    imageSize,
                    isFormBad: false,
                    isMirrored:
                        controller.description.lensDirection ==
                        CameraLensDirection.front,
                  ),
                ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                left: 14,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 16,
                left: 72,
                right: 72,
                child: Text(
                  _assessmentTitle(selection.type),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 70,
                left: 20,
                right: 20,
                child: _AssessmentStatusCard(
                  sampleCount: liveState.snapshot.sampleCount,
                  feedback: liveState.feedbackMessage,
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 28,
                child: liveState.snapshot.isCompleted
                    ? _AssessmentResultCard(
                        result: liveState.snapshot.result!,
                        onClose: () => Navigator.pop(context),
                      )
                    : ElevatedButton.icon(
                        onPressed: () async {
                          await _stopImageStream();
                          ref
                              .read(assessmentLiveControllerProvider.notifier)
                              .complete();
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Değerlendirmeyi Bitir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(54),
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Kamera açılamadı: $error',
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
        controller.value.isStreamingImages ||
        ref.read(assessmentLiveControllerProvider).snapshot.isCompleted) {
      return;
    }
    _startingStream = true;
    _streamController = controller;
    unawaited(
      controller
          .startImageStream((image) {
            unawaited(
              ref
                  .read(assessmentLiveControllerProvider.notifier)
                  .processCameraImage(
                    image,
                    controller.description.sensorOrientation,
                  ),
            );
          })
          .whenComplete(() {
            _startingStream = false;
          }),
    );
  }

  Future<void> _stopImageStream() async {
    final controller = _streamController;
    if (controller == null || !controller.value.isStreamingImages) {
      return;
    }
    try {
      await controller.stopImageStream();
    } catch (_) {
      // Keep assessment completion usable during camera teardown races.
    }
  }
}

class _AssessmentStatusCard extends StatelessWidget {
  const _AssessmentStatusCard({
    required this.sampleCount,
    required this.feedback,
  });

  final int sampleCount;
  final String feedback;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 6),
          Text(
            'Geçerli örnek: $sampleCount',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AssessmentResultCard extends StatelessWidget {
  const _AssessmentResultCard({required this.result, required this.onClose});

  final AssessmentResult result;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final values = _resultValues(result);
    return Container(
      constraints: const BoxConstraints(maxHeight: 360),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xEE111111),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.hasSufficientData
                ? 'Değerlendirme sonucu'
                : 'Yetersiz ölçüm',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
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
          ElevatedButton(onPressed: onClose, child: const Text('Kapat')),
        ],
      ),
    );
  }
}

String _assessmentTitle(AssessmentType type) {
  return switch (type) {
    AssessmentType.squat => 'Squat Değerlendirmesi',
    AssessmentType.balance => 'Denge Değerlendirmesi',
    AssessmentType.shoulderMobility => 'Omuz Mobilitesi',
  };
}

List<MapEntry<String, String>> _resultValues(AssessmentResult result) {
  switch (result) {
    case SquatAssessmentResult squat:
      return <MapEntry<String, String>>[
        MapEntry('Sol diz fleksiyonu', _degrees(squat.leftKneeFlexionDegrees)),
        MapEntry('Sağ diz fleksiyonu', _degrees(squat.rightKneeFlexionDegrees)),
        MapEntry('Diz farkı', _degrees(squat.kneeFlexionAsymmetryDegrees)),
        MapEntry(
          'Kalça derinlik oranı',
          squat.deepestHipDepthRatio?.toStringAsFixed(3) ?? '—',
        ),
        MapEntry(
          'Kalça diz seviyesine indi',
          switch (squat.reachedHipAtOrBelowKneeHeight) {
            true => 'Evet',
            false => 'Hayır',
            null => '—',
          },
        ),
        MapEntry(
          'Gövde eğimi',
          _degrees(squat.torsoInclinationAtDeepestDegrees),
        ),
      ];
    case BalanceAssessmentResult balance:
      return <MapEntry<String, String>>[
        MapEntry('Stabilite skoru', _score(balance.stabilityScore)),
        MapEntry(
          'Ortalama sway',
          balance.averageSwayStandardDeviation?.toStringAsFixed(3) ?? '—',
        ),
        MapEntry('Geçerli örnek', balance.sampleCount.toString()),
        MapEntry('Reddedilen örnek', balance.rejectedSampleCount.toString()),
        MapEntry(
          'Gözlem süresi',
          _assessmentDuration(balance.observedDuration),
        ),
      ];
    case ShoulderMobilityAssessmentResult shoulder:
      return <MapEntry<String, String>>[
        MapEntry(
          'Sol maksimum',
          _degrees(shoulder.leftMaximumElevationDegrees),
        ),
        MapEntry(
          'Sağ maksimum',
          _degrees(shoulder.rightMaximumElevationDegrees),
        ),
        MapEntry('Sağ-sol farkı', _degrees(shoulder.sideDifferenceDegrees)),
        MapEntry(
          'Sol maksimumda gövde eğimi',
          _degrees(shoulder.torsoInclinationAtLeftMaximumDegrees),
        ),
        MapEntry(
          'Sağ maksimumda gövde eğimi',
          _degrees(shoulder.torsoInclinationAtRightMaximumDegrees),
        ),
      ];
  }
}

String _degrees(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(1)}°';
String _score(double? value) => value == null ? '—' : value.toStringAsFixed(0);

String _assessmentDuration(Duration duration) {
  final seconds = duration.inMilliseconds / 1000;
  return '${seconds.toStringAsFixed(1)} sn';
}
