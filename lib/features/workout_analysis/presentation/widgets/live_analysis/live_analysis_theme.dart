import 'package:flutter/material.dart';

import '../../../../../app/theme/app_hud_tokens.dart';

const Color liveHudAccent = AppHudTokens.accent;
const Color liveHudSurface = AppHudTokens.surface;
const Color liveHudSurfaceStrong = AppHudTokens.surfaceStrong;
const Color liveHudMetricSurface = AppHudTokens.metricSurface;
const Color liveHudMetricSurfaceStrong = AppHudTokens.metricSurfaceStrong;

BoxDecoration liveHudSurfaceDecoration({
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

String sentenceCaseLiveMetricLabel(String value) {
  if (value.isEmpty) {
    return value;
  }
  final lower = value.toLowerCase();
  return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
}
