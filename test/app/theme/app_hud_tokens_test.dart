import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/app/theme/app_hud_tokens.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/live_analysis/live_analysis_theme.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/planned_workout_hud_models.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/planned_workout_hud_theme.dart';

void main() {
  test('live and planned HUD compatibility aliases share one token source', () {
    expect(liveHudAccent, AppHudTokens.accent);
    expect(plannedHudAccent, AppHudTokens.accent);
    expect(liveHudSurface, AppHudTokens.surface);
    expect(plannedHudSurface, AppHudTokens.surface);
    expect(liveHudSurfaceStrong, AppHudTokens.surfaceStrong);
    expect(plannedHudSurfaceStrong, AppHudTokens.surfaceStrong);
    expect(liveHudMetricSurface, AppHudTokens.metricSurface);
    expect(plannedHudMetricSurface, AppHudTokens.metricSurface);
    expect(liveHudMetricSurfaceStrong, AppHudTokens.metricSurfaceStrong);
    expect(plannedHudMetricSurfaceStrong, AppHudTokens.metricSurfaceStrong);
  });

  test(
    'live and planned HUD surface decorators remain visually equivalent',
    () {
      final liveDecoration = liveHudSurfaceDecoration(
        accentColor: liveHudAccent,
        radius: 18,
        strong: true,
        glow: true,
      );
      final plannedDecoration = plannedSurfaceDecoration(
        accentColor: plannedHudAccent,
        radius: 18,
        strong: true,
        glow: true,
      );

      expect(liveDecoration.color, plannedDecoration.color);
      expect(liveDecoration.borderRadius, plannedDecoration.borderRadius);
      expect(liveDecoration.border, plannedDecoration.border);
      expect(liveDecoration.boxShadow, plannedDecoration.boxShadow);
      expect(liveDecoration.boxShadow, isNotEmpty);
      expect(liveDecoration.boxShadow!.length, greaterThan(2));
    },
  );

  test('planned HUD tones use semantic status colors', () {
    expect(
      plannedHudToneColor(PlannedWorkoutHudTone.positive),
      AppColors.success,
    );
    expect(
      plannedHudToneColor(PlannedWorkoutHudTone.caution),
      AppColors.caution,
    );
    expect(
      plannedHudToneColor(PlannedWorkoutHudTone.invalid),
      AppColors.invalid,
    );
    expect(
      plannedHudToneColor(PlannedWorkoutHudTone.muted),
      AppColors.disabledForeground,
    );
  });
}
