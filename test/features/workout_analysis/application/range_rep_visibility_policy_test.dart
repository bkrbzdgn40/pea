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
      expect(assessment.statusLabel, 'brief_freeze');
      expect(assessment.didStartInvalidRun, isFalse);

      final recovered = policy.evaluate(
        isInvalidFrame: false,
        now: baseTime.add(const Duration(milliseconds: 250)),
      );

      expect(recovered.invalidFrameStreak, 0);
      expect(recovered.statusLabel, 'stable');
    });

    test('1499 ms remains recoverable as a brief occlusion', () {
      final policy = RangeRepVisibilityPolicy();
      final baseTime = DateTime(2026, 1, 1, 12);

      policy.evaluate(isInvalidFrame: true, now: baseTime);
      final assessment = policy.evaluate(
        isInvalidFrame: true,
        now: baseTime.add(const Duration(milliseconds: 1499)),
      );

      expect(assessment.shouldResync, isFalse);
      expect(assessment.hasResyncedCurrentRun, isFalse);
      expect(assessment.statusLabel, 'brief_freeze');
    });

    test('1500 ms triggers a hard resync boundary', () {
      final policy = RangeRepVisibilityPolicy();
      final baseTime = DateTime(2026, 1, 1, 12);

      policy.evaluate(isInvalidFrame: true, now: baseTime);
      final assessment = policy.evaluate(
        isInvalidFrame: true,
        now: baseTime.add(const Duration(milliseconds: 1500)),
      );

      expect(assessment.shouldResync, isTrue);
      expect(assessment.hasResyncedCurrentRun, isTrue);
      expect(assessment.resyncReason, 'brief occlusion grace exceeded');
      expect(assessment.statusLabel, 'hard_resync');
    });

    test('long invalid run only triggers one hard resync', () {
      final policy = RangeRepVisibilityPolicy();
      final baseTime = DateTime(2026, 1, 1, 12);

      policy.evaluate(isInvalidFrame: true, now: baseTime);
      final firstResync = policy.evaluate(
        isInvalidFrame: true,
        now: baseTime.add(const Duration(milliseconds: 1500)),
      );
      final secondAssessment = policy.evaluate(
        isInvalidFrame: true,
        now: baseTime.add(const Duration(milliseconds: 2200)),
      );

      expect(firstResync.shouldResync, isTrue);
      expect(secondAssessment.shouldResync, isFalse);
      expect(secondAssessment.hasResyncedCurrentRun, isTrue);
    });
  });
}
