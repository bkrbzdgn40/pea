import 'package:flutter/material.dart';

import 'app_design_tokens.dart';

class AppHudTokens {
  const AppHudTokens._();

  static const Color accent = AppColors.analysisAccent;
  static const Color surface = Color(0xD91A2026);
  static const Color surfaceStrong = Color(0xE6171D23);
  static const Color metricSurface = Color(0x8F1A2026);
  static const Color metricSurfaceStrong = Color(0xA6171D23);

  static BoxDecoration surfaceDecoration({
    required Color accentColor,
    required double radius,
    bool strong = false,
    Color? surfaceColor,
  }) {
    return BoxDecoration(
      color: surfaceColor ?? (strong ? surfaceStrong : surface),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: accentColor.withValues(
          alpha: strong ? AppOpacity.strongBorder : AppOpacity.border,
        ),
      ),
      boxShadow: AppShadows.hud,
    );
  }
}
