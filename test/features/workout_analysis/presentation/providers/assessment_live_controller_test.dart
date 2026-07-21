import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/assessment_models.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/assessment_live_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_assessment_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/settings_provider.dart';

void main() {
  group('AssessmentLiveController', () {
    test('keeps the pose detector owned by the live assessment session', () {
      var detectorCreateCount = 0;
      final container = ProviderContainer(
        overrides: <Override>[
          selectedAssessmentProvider.overrideWith(
            (ref) => const AssessmentSelection(type: AssessmentType.squat),
          ),
          poseDetectorProvider.overrideWith((ref) {
            detectorCreateCount += 1;
            return _FakePoseDetector();
          }),
        ],
      );
      addTearDown(container.dispose);

      container.read(assessmentLiveControllerProvider);

      expect(detectorCreateCount, 1);
    });

    test('starts with capture guidance and incomplete readiness', () {
      final container = ProviderContainer(
        overrides: <Override>[
          selectedAssessmentProvider.overrideWith(
            (ref) => const AssessmentSelection(type: AssessmentType.squat),
          ),
          poseDetectorProvider.overrideWith((ref) => _FakePoseDetector()),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(assessmentLiveControllerProvider);

      expect(state.snapshot.isActive, isTrue);
      expect(state.snapshot.isReadyToComplete, isFalse);
      expect(state.snapshot.readinessProgress, 0);
      expect(state.feedbackMessage, contains('sol veya sağ yanını dön'));
      expect(state.progressMessage, 'Hareket ilerlemesi: %0');
    });

    test('uses English runtime guidance when English is selected', () {
      final container = ProviderContainer(
        overrides: <Override>[
          runtimeAppLanguageProvider.overrideWith((ref) => AppLanguage.english),
          selectedAssessmentProvider.overrideWith(
            (ref) => const AssessmentSelection(type: AssessmentType.squat),
          ),
          poseDetectorProvider.overrideWith((ref) => _FakePoseDetector()),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(assessmentLiveControllerProvider);

      expect(state.feedbackMessage, contains('left or right side'));
      expect(state.progressMessage, 'Movement progress: 0%');
    });

    test('complete stays active when readiness gate is not satisfied', () {
      final container = ProviderContainer(
        overrides: <Override>[
          selectedAssessmentProvider.overrideWith(
            (ref) => const AssessmentSelection(
              type: AssessmentType.balance,
              balanceSide: AssessmentSide.left,
            ),
          ),
          poseDetectorProvider.overrideWith((ref) => _FakePoseDetector()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        assessmentLiveControllerProvider.notifier,
      );
      final result = controller.complete();
      final state = container.read(assessmentLiveControllerProvider);

      expect(result, isNull);
      expect(state.snapshot.isActive, isTrue);
      expect(state.snapshot.isCompleted, isFalse);
      expect(state.feedbackMessage, contains('henüz hazır değil'));
    });

    test('retry restores the initial live state', () {
      final container = ProviderContainer(
        overrides: <Override>[
          selectedAssessmentProvider.overrideWith(
            (ref) => const AssessmentSelection(
              type: AssessmentType.shoulderMobility,
            ),
          ),
          poseDetectorProvider.overrideWith((ref) => _FakePoseDetector()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        assessmentLiveControllerProvider.notifier,
      );
      controller.retry();
      final state = container.read(assessmentLiveControllerProvider);

      expect(state.snapshot.isActive, isTrue);
      expect(state.snapshot.sampleCount, 0);
      expect(state.snapshot.isReadyToComplete, isFalse);
      expect(state.progressMessage, 'Elevasyon ilerlemesi: %0');
      expect(state.feedbackMessage, contains('iki yana doğru'));
    });
  });
}

class _FakePoseDetector implements PoseDetector {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
