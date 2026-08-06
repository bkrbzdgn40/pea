import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/live_analysis/live_hud_visibility_policy.dart';

void main() {
  group('LiveHudVisibilityPolicy', () {
    test('keeps the active default surface minimal', () {
      const policy = LiveHudVisibilityPolicy(
        mode: LiveHudMode.minimal,
        isPaused: false,
        hasCriticalWarning: false,
      );

      expect(policy.showActiveHud, isTrue);
      expect(policy.showDetailedContent, isFalse);
      expect(policy.showSecondaryMetric, isFalse);
      expect(policy.showTechnicalMetrics, isFalse);
      expect(policy.showProgressContext, isFalse);
      expect(policy.showFinishAction, isFalse);
    });

    test('reveals retained metrics in detailed mode', () {
      const policy = LiveHudVisibilityPolicy(
        mode: LiveHudMode.detailed,
        isPaused: false,
        hasCriticalWarning: false,
      );

      expect(policy.showActiveHud, isTrue);
      expect(policy.showDetailedContent, isTrue);
      expect(policy.showSecondaryMetric, isTrue);
      expect(policy.showTechnicalMetrics, isTrue);
      expect(policy.showProgressContext, isTrue);
      expect(policy.showFinishAction, isTrue);
    });

    test('uses the paused surface as a detailed checkpoint', () {
      const policy = LiveHudVisibilityPolicy(
        mode: LiveHudMode.minimal,
        isPaused: true,
        hasCriticalWarning: false,
      );

      expect(policy.showActiveHud, isFalse);
      expect(policy.showDetailedContent, isTrue);
      expect(policy.showFinishAction, isTrue);
    });

    test('lets a critical warning suppress every HUD detail', () {
      const policy = LiveHudVisibilityPolicy(
        mode: LiveHudMode.detailed,
        isPaused: false,
        hasCriticalWarning: true,
      );

      expect(policy.showActiveHud, isFalse);
      expect(policy.showDetailedContent, isFalse);
      expect(policy.showFinishAction, isFalse);
    });
  });
}
