import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/formatters/workout_presentation_formatter.dart';

void main() {
  group('WorkoutPresentationFormatter', () {
    test('formats durations as minutes and zero-padded seconds', () {
      expect(
        WorkoutPresentationFormatter.duration(const Duration(seconds: 65)),
        '1:05',
      );
    });

    test(
      'formats hold seconds with the preserved round-then-duration rule',
      () {
        expect(WorkoutPresentationFormatter.holdDuration(65.4), '1:05');
      },
    );

    test(
      'formats summary and history scores by rounding to an integer string',
      () {
        expect(WorkoutPresentationFormatter.roundedScore(89.6), '90');
      },
    );

    test('formats session detail scores with compact precision', () {
      expect(WorkoutPresentationFormatter.compactScore(89.6), '89.6');
      expect(WorkoutPresentationFormatter.compactScore(89.0), '89');
    });

    test('formats local date time as dd.MM.yyyy HH:mm', () {
      expect(
        WorkoutPresentationFormatter.dateTime(DateTime(2024, 2, 3, 4, 5)),
        '03.02.2024 04:05',
      );
    });

    test(
      'formats canonical and fallback exercise titles with snake_case words',
      () {
        expect(WorkoutPresentationFormatter.exerciseTitle('squat'), 'Squat');
        expect(WorkoutPresentationFormatter.exerciseTitle('plank'), 'Plank');
        expect(
          WorkoutPresentationFormatter.exerciseTitle('hollow_hold'),
          'Hollow Hold',
        );
        expect(
          WorkoutPresentationFormatter.exerciseTitle('push_up'),
          'Push Up',
        );
        expect(WorkoutPresentationFormatter.exerciseTitle('sit_up'), 'Sit Up');
        expect(
          WorkoutPresentationFormatter.exerciseTitle('single_leg_jump'),
          'Single Leg Jump',
        );
      },
    );
  });
}
