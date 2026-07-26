import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/range_rep_outcome_view_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/live_range_rep_outcome_controller.dart';

void main() {
  test(
    'shows each rep once and dismisses it after the display window',
    () async {
      final controller = LiveRangeRepOutcomeController(
        displayDuration: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);

      const first = RangeRepOutcomeViewData(
        repIndex: 1,
        status: RangeRepValidationStatus.valid,
        title: 'Valid rep',
        message: 'Good rep.',
        tone: RangeRepOutcomeTone.positive,
      );

      expect(controller.show(first), isTrue);
      expect(controller.state, same(first));
      expect(controller.show(first), isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(controller.state, isNull);
    },
  );

  test('a newer rep replaces the visible outcome and its timer', () async {
    final controller = LiveRangeRepOutcomeController(
      displayDuration: const Duration(milliseconds: 30),
    );
    addTearDown(controller.dispose);

    const first = RangeRepOutcomeViewData(
      repIndex: 1,
      status: RangeRepValidationStatus.valid,
      title: 'Valid rep',
      message: 'First',
      tone: RangeRepOutcomeTone.positive,
    );
    const second = RangeRepOutcomeViewData(
      repIndex: 2,
      status: RangeRepValidationStatus.lowConfidence,
      title: 'Rep completed',
      message: 'Second',
      tone: RangeRepOutcomeTone.caution,
      primaryReason: RangeRepValidationReason.coverageLoss,
    );

    controller.show(first);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(controller.show(second), isTrue);
    expect(controller.state, same(second));

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.state, same(second));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.state, isNull);
  });
  test('reset allows the same rep index in a new analysis session', () {
    final controller = LiveRangeRepOutcomeController(
      displayDuration: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);

    const outcome = RangeRepOutcomeViewData(
      repIndex: 1,
      status: RangeRepValidationStatus.valid,
      title: 'Valid rep',
      message: 'Good rep.',
      tone: RangeRepOutcomeTone.positive,
    );

    expect(controller.show(outcome), isTrue);
    controller.reset();
    expect(controller.state, isNull);
    expect(controller.show(outcome), isTrue);
  });
}
