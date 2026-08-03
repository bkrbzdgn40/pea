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
    bool glow = false,
    Color? surfaceColor,
  }) {
    final borderAlpha = strong ? AppOpacity.strongBorder : AppOpacity.border;
    return BoxDecoration(
      color: surfaceColor ?? (strong ? surfaceStrong : surface),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: accentColor.withValues(alpha: borderAlpha),
        width: strong ? 1.25 : 1,
      ),
      boxShadow: <BoxShadow>[
        ...AppShadows.hud,
        if (glow)
          BoxShadow(
            color: accentColor.withValues(alpha: strong ? 0.24 : 0.16),
            blurRadius: strong ? 28 : 20,
            spreadRadius: strong ? -2 : -4,
          ),
        BoxShadow(
          color: Colors.white.withValues(alpha: strong ? 0.045 : 0.025),
          blurRadius: 1,
          offset: const Offset(0, -1),
        ),
      ],
    );
  }
}
