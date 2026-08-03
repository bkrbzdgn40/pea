import 'package:flutter/material.dart';

import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_hud_tokens.dart';
import 'planned_workout_hud_models.dart';

const Color plannedHudAccent = AppHudTokens.accent;
const Color plannedHudSurface = AppHudTokens.surface;
const Color plannedHudSurfaceStrong = AppHudTokens.surfaceStrong;
const Color plannedHudMetricSurface = AppHudTokens.metricSurface;
const Color plannedHudMetricSurfaceStrong = AppHudTokens.metricSurfaceStrong;

BoxDecoration plannedSurfaceDecoration({
  required Color accentColor,
  required double radius,
  bool strong = false,
  Color? surfaceColor,
}) {
  return AppHudTokens.surfaceDecoration(
    accentColor: accentColor,
    radius: radius,
    strong: strong,
    surfaceColor: surfaceColor,
  );
}

Color plannedHudToneColor(PlannedWorkoutHudTone tone) {
  return switch (tone) {
    PlannedWorkoutHudTone.positive => AppColors.success,
    PlannedWorkoutHudTone.caution => AppColors.caution,
    PlannedWorkoutHudTone.invalid => AppColors.invalid,
    PlannedWorkoutHudTone.muted => AppColors.disabledForeground,
  };
}
