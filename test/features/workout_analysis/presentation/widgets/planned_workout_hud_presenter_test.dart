import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/planned_workout_hud_models.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/planned_workout_hud_presenter.dart';

void main() {
  test('hides the previous rep score until the new set has progress', () {
    final presentation = plannedSecondaryMetricPresentation(
      isHoldAnalysis: false,
      hasCurrentProgress: false,
      bestHoldSeconds: 0,
      lastRepScore: 94,
      isInvalidLastAttempt: false,
      isLowConfidenceLastRep: false,
    );

    expect(presentation.value, '—');
    expect(presentation.tone, PlannedWorkoutHudTone.muted);
  });

  test('hides the previous hold best until the new set has progress', () {
    final presentation = plannedSecondaryMetricPresentation(
      isHoldAnalysis: true,
      hasCurrentProgress: false,
      bestHoldSeconds: 38,
      lastRepScore: 0,
      isInvalidLastAttempt: false,
      isLowConfidenceLastRep: false,
    );

    expect(presentation.value, '—');
    expect(presentation.tone, PlannedWorkoutHudTone.muted);
  });

  test('shows a current low-confidence score with caution tone', () {
    final presentation = plannedSecondaryMetricPresentation(
      isHoldAnalysis: false,
      hasCurrentProgress: true,
      bestHoldSeconds: 0,
      lastRepScore: 72,
      isInvalidLastAttempt: false,
      isLowConfidenceLastRep: true,
    );

    expect(presentation.value, '72');
    expect(presentation.tone, PlannedWorkoutHudTone.caution);
  });

  test('ignores a stale rep validation status for current hold progress', () {
    final presentation = plannedSecondaryMetricPresentation(
      isHoldAnalysis: true,
      hasCurrentProgress: true,
      bestHoldSeconds: 18,
      lastRepScore: 0,
      isInvalidLastAttempt: true,
      isLowConfidenceLastRep: false,
    );

    expect(presentation.value, '0:18');
    expect(presentation.tone, PlannedWorkoutHudTone.positive);
  });
}
