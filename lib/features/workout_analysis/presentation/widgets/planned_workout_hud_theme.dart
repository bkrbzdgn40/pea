import 'package:flutter/material.dart';

import 'planned_workout_hud_models.dart';

const Color plannedHudAccent = Color(0xFF61E6BE);
const Color plannedHudSurface = Color(0xD91A2026);
const Color plannedHudSurfaceStrong = Color(0xE6171D23);
const Color plannedHudMetricSurface = Color(0x8F1A2026);
const Color plannedHudMetricSurfaceStrong = Color(0xA6171D23);

BoxDecoration plannedSurfaceDecoration({
  required Color accentColor,
  required double radius,
  bool strong = false,
  Color? surfaceColor,
}) {
  return BoxDecoration(
    color:
        surfaceColor ?? (strong ? plannedHudSurfaceStrong : plannedHudSurface),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: accentColor.withValues(alpha: strong ? 0.48 : 0.28),
    ),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 7)),
    ],
  );
}

Color plannedHudToneColor(PlannedWorkoutHudTone tone) {
  return switch (tone) {
    PlannedWorkoutHudTone.positive => plannedHudAccent,
    PlannedWorkoutHudTone.caution => Colors.amberAccent,
    PlannedWorkoutHudTone.invalid => Colors.orangeAccent,
    PlannedWorkoutHudTone.muted => Colors.white38,
  };
}
