import 'package:flutter/material.dart';

import 'app_design_tokens.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceStrong,
    required this.outline,
    required this.outlineSubtle,
    required this.foreground,
    required this.foregroundMuted,
    required this.foregroundSubtle,
    required this.accent,
    required this.analysisAccent,
    required this.success,
    required this.caution,
    required this.invalid,
    required this.danger,
  });

  static const AppSemanticColors dark = AppSemanticColors(
    canvas: AppColors.scaffoldBackground,
    surface: AppColors.primarySurface,
    surfaceMuted: AppColors.secondarySurface,
    surfaceStrong: AppColors.strongSurface,
    outline: AppColors.surfaceBorder,
    outlineSubtle: AppColors.subtleBorder,
    foreground: AppColors.primaryForeground,
    foregroundMuted: AppColors.secondaryForeground,
    foregroundSubtle: AppColors.mutedForeground,
    accent: AppColors.accent,
    analysisAccent: AppColors.analysisAccent,
    success: AppColors.success,
    caution: AppColors.caution,
    invalid: AppColors.invalid,
    danger: AppColors.danger,
  );

  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceStrong;
  final Color outline;
  final Color outlineSubtle;
  final Color foreground;
  final Color foregroundMuted;
  final Color foregroundSubtle;
  final Color accent;
  final Color analysisAccent;
  final Color success;
  final Color caution;
  final Color invalid;
  final Color danger;

  @override
  AppSemanticColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceStrong,
    Color? outline,
    Color? outlineSubtle,
    Color? foreground,
    Color? foregroundMuted,
    Color? foregroundSubtle,
    Color? accent,
    Color? analysisAccent,
    Color? success,
    Color? caution,
    Color? invalid,
    Color? danger,
  }) {
    return AppSemanticColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      outline: outline ?? this.outline,
      outlineSubtle: outlineSubtle ?? this.outlineSubtle,
      foreground: foreground ?? this.foreground,
      foregroundMuted: foregroundMuted ?? this.foregroundMuted,
      foregroundSubtle: foregroundSubtle ?? this.foregroundSubtle,
      accent: accent ?? this.accent,
      analysisAccent: analysisAccent ?? this.analysisAccent,
      success: success ?? this.success,
      caution: caution ?? this.caution,
      invalid: invalid ?? this.invalid,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineSubtle: Color.lerp(outlineSubtle, other.outlineSubtle, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      foregroundMuted: Color.lerp(foregroundMuted, other.foregroundMuted, t)!,
      foregroundSubtle: Color.lerp(
        foregroundSubtle,
        other.foregroundSubtle,
        t,
      )!,
      accent: Color.lerp(accent, other.accent, t)!,
      analysisAccent: Color.lerp(analysisAccent, other.analysisAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      invalid: Color.lerp(invalid, other.invalid, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppSemanticColors get semanticColors {
    return Theme.of(this).extension<AppSemanticColors>() ??
        AppSemanticColors.dark;
  }
}
