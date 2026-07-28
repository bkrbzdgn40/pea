import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_feedback_lifecycle.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_feedback_code.dart';

void main() {
  group('RangeRepFeedbackLifecycle', () {
    test('keeps a recovered corrective cue only until its TTL expires', () {
      final lifecycle = RangeRepFeedbackLifecycle(
        correctiveTtl: const Duration(milliseconds: 1200),
      );
      final startedAt = DateTime.utc(2030, 1, 1);

      expect(
        lifecycle.resolve(
          now: startedAt,
          phaseKey: 'descending',
          freshCandidate: RangeRepFeedbackCode.legacyFormThresholdViolation,
          hasFreshCorrectiveCandidate: true,
          hasLifecycleTransition: false,
        ),
        RangeRepFeedbackCode.legacyFormThresholdViolation,
      );

      expect(
        lifecycle.resolve(
          now: startedAt.add(const Duration(milliseconds: 800)),
          phaseKey: 'descending',
          freshCandidate: RangeRepFeedbackCode.descend,
          hasFreshCorrectiveCandidate: false,
          hasLifecycleTransition: false,
        ),
        RangeRepFeedbackCode.legacyFormThresholdViolation,
      );

      expect(
        lifecycle.resolve(
          now: startedAt.add(const Duration(milliseconds: 1200)),
          phaseKey: 'descending',
          freshCandidate: RangeRepFeedbackCode.descend,
          hasFreshCorrectiveCandidate: false,
          hasLifecycleTransition: false,
        ),
        RangeRepFeedbackCode.descend,
      );
    });

    test('clears a corrective cue immediately when the phase changes', () {
      final lifecycle = RangeRepFeedbackLifecycle();
      final startedAt = DateTime.utc(2030, 1, 1);

      lifecycle.resolve(
        now: startedAt,
        phaseKey: 'descending',
        freshCandidate: RangeRepFeedbackCode.legacyFormThresholdViolation,
        hasFreshCorrectiveCandidate: true,
        hasLifecycleTransition: false,
      );

      expect(
        lifecycle.resolve(
          now: startedAt.add(const Duration(milliseconds: 100)),
          phaseKey: 'peak',
          freshCandidate: RangeRepFeedbackCode.ascend,
          hasFreshCorrectiveCandidate: false,
          hasLifecycleTransition: true,
        ),
        RangeRepFeedbackCode.ascend,
      );
    });

    test('can clear a peak-window correction on the first clean frame', () {
      final lifecycle = RangeRepFeedbackLifecycle();
      final startedAt = DateTime.utc(2030, 1, 1);

      lifecycle.resolve(
        now: startedAt,
        phaseKey: 'peak',
        freshCandidate: RangeRepFeedbackCode.legacyFormThresholdViolation,
        hasFreshCorrectiveCandidate: true,
        hasLifecycleTransition: false,
        retainFreshCorrective: false,
      );

      expect(
        lifecycle.resolve(
          now: startedAt.add(const Duration(milliseconds: 100)),
          phaseKey: 'peak',
          freshCandidate: RangeRepFeedbackCode.ascend,
          hasFreshCorrectiveCandidate: false,
          hasLifecycleTransition: false,
        ),
        RangeRepFeedbackCode.ascend,
      );
    });

    test('keeps an incomplete-rep result briefly in neutral', () {
      final lifecycle = RangeRepFeedbackLifecycle(
        resultTtl: const Duration(milliseconds: 1600),
      );
      final startedAt = DateTime.utc(2030, 1, 1);

      expect(
        lifecycle.resolve(
          now: startedAt,
          phaseKey: 'neutral',
          freshCandidate: RangeRepFeedbackCode.repIncomplete,
          hasFreshCorrectiveCandidate: false,
          hasLifecycleTransition: true,
        ),
        RangeRepFeedbackCode.repIncomplete,
      );

      expect(
        lifecycle.resolve(
          now: startedAt.add(const Duration(milliseconds: 1500)),
          phaseKey: 'neutral',
          freshCandidate: RangeRepFeedbackCode.ready,
          hasFreshCorrectiveCandidate: false,
          hasLifecycleTransition: false,
        ),
        RangeRepFeedbackCode.repIncomplete,
      );

      expect(
        lifecycle.resolve(
          now: startedAt.add(const Duration(milliseconds: 1600)),
          phaseKey: 'neutral',
          freshCandidate: RangeRepFeedbackCode.ready,
          hasFreshCorrectiveCandidate: false,
          hasLifecycleTransition: false,
        ),
        RangeRepFeedbackCode.ready,
      );
    });

    test('reset clears an active lease', () {
      final lifecycle = RangeRepFeedbackLifecycle();
      final startedAt = DateTime.utc(2030, 1, 1);

      lifecycle.resolve(
        now: startedAt,
        phaseKey: 'neutral',
        freshCandidate: RangeRepFeedbackCode.repCompleted,
        hasFreshCorrectiveCandidate: false,
        hasLifecycleTransition: true,
      );
      lifecycle.reset();

      expect(
        lifecycle.resolve(
          now: startedAt.add(const Duration(milliseconds: 100)),
          phaseKey: 'neutral',
          freshCandidate: RangeRepFeedbackCode.ready,
          hasFreshCorrectiveCandidate: false,
          hasLifecycleTransition: false,
        ),
        RangeRepFeedbackCode.ready,
      );
    });
  });
}
