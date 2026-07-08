import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_visibility_policy.dart';

void main() {
  group('RangeRepVisibilityPolicy', () {
    test('short invalid streak freezes without triggering resync', () {
      final policy = RangeRepVisibilityPolicy();
      final baseTime = DateTime(2026, 1, 1, 12);

      var assessment = policy.evaluate(isInvalidFrame: true, now: baseTime);
      assessment = policy.evaluate(
        isInvalidFrame: true,
        now: baseTime.add(const Duration(milliseconds: 100)),
      );
      assessment = policy.evaluate(
        isInvalidFrame: true,
        now: baseTime.add(const Duration(milliseconds: 200)),
      );

      expect(assessment.invalidFrameStreak, 3);
      expect(assessment.shouldResync, isFalse);
      expect(assessment.hasResyncedCurrentRun, isFalse);
      expect(assessment.statusLabel, 'freeze');

      final recovered = policy.evaluate(
        isInvalidFrame: false,
        now: baseTime.add(const Duration(milliseconds: 250)),
      );

      expect(recovered.invalidFrameStreak, 0);
      expect(recovered.statusLabel, 'stable');
    });

    test('long invalid streak triggers a safe resync', () {
      final policy = RangeRepVisibilityPolicy();
      final baseTime = DateTime(2026, 1, 1, 12);

      policy.evaluate(isInvalidFrame: true, now: baseTime);
      policy.evaluate(
        isInvalidFrame: true,
        now: baseTime.add(const Duration(milliseconds: 100)),
      );
      policy.evaluate(
        isInvalidFrame: true,
        now: baseTime.add(const Duration(milliseconds: 200)),
      );
      final assessment = policy.evaluate(
        isInvalidFrame: true,
        now: baseTime.add(const Duration(milliseconds: 300)),
      );

      expect(assessment.invalidFrameStreak, 4);
      expect(assessment.shouldResync, isTrue);
      expect(assessment.hasResyncedCurrentRun, isTrue);
      expect(assessment.resyncReason, 'invalid streak threshold');
    });

    test('long invalid duration can resync before the streak threshold', () {
      final policy = RangeRepVisibilityPolicy();
      final baseTime = DateTime(2026, 1, 1, 12);

      policy.evaluate(isInvalidFrame: true, now: baseTime);
      policy.evaluate(
        isInvalidFrame: true,
        now: baseTime.add(const Duration(milliseconds: 200)),
      );
      final assessment = policy.evaluate(
        isInvalidFrame: true,
        now: baseTime.add(const Duration(milliseconds: 460)),
      );

      expect(assessment.invalidFrameStreak, 3);
      expect(assessment.shouldResync, isTrue);
      expect(assessment.hasResyncedCurrentRun, isTrue);
      expect(assessment.resyncReason, 'invalid duration threshold');
    });
  });
}
