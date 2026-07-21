import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/assessment_models.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/assessment_live_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_assessment_provider.dart';

void main() {
  group('AssessmentLiveController', () {
    test('starts with capture guidance and incomplete readiness', () {
      final container = ProviderContainer(
        overrides: <Override>[
          selectedAssessmentProvider.overrideWith(
            (ref) => const AssessmentSelection(type: AssessmentType.squat),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(assessmentLiveControllerProvider);

      expect(state.snapshot.isActive, isTrue);
      expect(state.snapshot.isReadyToComplete, isFalse);
      expect(state.snapshot.readinessProgress, 0);
      expect(state.feedbackMessage, contains('Kameraya yandan dön'));
      expect(state.progressMessage, 'Hareket ilerlemesi: %0');
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
