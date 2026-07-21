import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../application/assessment_engine.dart';
import '../../application/assessment_measurement_extractor.dart';
import '../../domain/models/assessment_models.dart';
import '../../infrastructure/converters/input_image_converter.dart';
import 'pose_provider.dart';
import 'selected_assessment_provider.dart';

class AssessmentLiveState {
  const AssessmentLiveState({
    required this.snapshot,
    required this.feedbackMessage,
    this.landmarks,
  });

  final AssessmentSnapshot snapshot;
  final String feedbackMessage;
  final List<PoseLandmark>? landmarks;

  AssessmentLiveState copyWith({
    AssessmentSnapshot? snapshot,
    String? feedbackMessage,
    List<PoseLandmark>? landmarks,
  }) {
    return AssessmentLiveState(
      snapshot: snapshot ?? this.snapshot,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      landmarks: landmarks ?? this.landmarks,
    );
  }
}

final assessmentLiveControllerProvider =
    AutoDisposeNotifierProvider<AssessmentLiveController, AssessmentLiveState>(
      AssessmentLiveController.new,
    );

class AssessmentLiveController
    extends AutoDisposeNotifier<AssessmentLiveState> {
  final AssessmentMeasurementExtractor _extractor =
      const AssessmentMeasurementExtractor();
  final InputImageConverter _inputImageConverter = const InputImageConverter();

  late AssessmentSelection _selection;
  late AssessmentEngine _engine;
  bool _isProcessing = false;
  DateTime? _lastAnalysisAt;

  @override
  AssessmentLiveState build() {
    final selection = ref.watch(selectedAssessmentProvider);
    if (selection == null) {
      throw StateError('Assessment mode requires a selected assessment.');
    }
    _selection = selection;
    _engine = AssessmentEngine(type: selection.type);
    final snapshot = _engine.start(balanceSide: selection.balanceSide);
    _isProcessing = false;
    _lastAnalysisAt = null;
    return AssessmentLiveState(
      snapshot: snapshot,
      feedbackMessage: _instructionFor(selection),
    );
  }

  Future<void> processCameraImage(
    CameraImage image,
    int sensorOrientation, {
    DateTime? capturedAt,
  }) async {
    final now = capturedAt ?? DateTime.now();
    if (_isProcessing || state.snapshot.isCompleted) {
      return;
    }
    final lastAnalysisAt = _lastAnalysisAt;
    if (lastAnalysisAt != null &&
        now.difference(lastAnalysisAt) < const Duration(milliseconds: 100)) {
      return;
    }

    _isProcessing = true;
    _lastAnalysisAt = now;
    try {
      final inputImage = _inputImageConverter.convert(image, sensorOrientation);
      if (inputImage == null) {
        return;
      }
      final detector = ref.read(poseDetectorProvider);
      final poses = await detector.processImage(inputImage);
      if (poses.isEmpty) {
        state = AssessmentLiveState(
          snapshot: state.snapshot,
          feedbackMessage: 'Vücudunu kadraja al.',
        );
        return;
      }

      final pose = poses.reduce(
        (current, candidate) =>
            candidate.landmarks.length > current.landmarks.length
            ? candidate
            : current,
      );
      final observation = _observationFor(pose, capturedAt: now);
      final snapshot = _engine.observe(observation);
      state = AssessmentLiveState(
        snapshot: snapshot,
        feedbackMessage: _instructionFor(_selection),
        landmarks: pose.landmarks.values.toList(growable: false),
      );
    } catch (_) {
      state = AssessmentLiveState(
        snapshot: state.snapshot,
        feedbackMessage: 'Kare analiz edilemedi. Pozisyonunu koru.',
      );
    } finally {
      _isProcessing = false;
    }
  }

  AssessmentResult complete() {
    if (state.snapshot.isCompleted) {
      return state.snapshot.result!;
    }
    final result = _engine.complete();
    state = state.copyWith(
      snapshot: _engine.snapshot,
      feedbackMessage: result.hasSufficientData
          ? 'Değerlendirme tamamlandı.'
          : 'Sonuç için yeterli ölçüm toplanamadı.',
    );
    return result;
  }

  AssessmentObservation _observationFor(
    Pose pose, {
    required DateTime capturedAt,
  }) {
    return switch (_selection.type) {
      AssessmentType.squat => _extractor.extractSquat(pose),
      AssessmentType.balance => _extractor.extractBalance(
        pose,
        side: _selection.balanceSide!,
        capturedAt: capturedAt,
      ),
      AssessmentType.shoulderMobility => _extractor.extractShoulderMobility(
        pose,
      ),
    };
  }

  String _instructionFor(AssessmentSelection selection) {
    return switch (selection.type) {
      AssessmentType.squat => 'Kontrollü çömel ve tekrar ayağa kalk.',
      AssessmentType.balance => 'Seçilen ayağın üzerinde sabit kal.',
      AssessmentType.shoulderMobility =>
        'Kollarını kontrollü biçimde mümkün olduğunca yukarı kaldır.',
    };
  }
}
