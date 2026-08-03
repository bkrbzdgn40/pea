import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';

void main() {
  test('preserves the shared radius tokens used by presentation surfaces', () {
    expect(AppRadii.small, 12);
    expect(AppRadii.compact, 14);
    expect(AppRadii.surface, 16);
    expect(AppRadii.large, 24);
    expect(AppRadii.pill, 999);
  });

  test(
    'defines a predictable spacing scale without changing legacy insets',
    () {
      expect(<double>[
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ], orderedEquals(<double>[4, 8, 12, 16, 20, 24, 32]));
      expect(AppSpacing.pagePadding, const EdgeInsets.fromLTRB(20, 12, 20, 24));
      expect(AppSpacing.surfacePadding, const EdgeInsets.all(16));
      expect(AppSpacing.headerSurfacePadding, const EdgeInsets.all(18));
    },
  );

  test('keeps semantic status colors distinct and stable', () {
    expect(AppColors.accent, Colors.greenAccent);
    expect(AppColors.analysisAccent, const Color(0xFF61E6BE));
    expect(AppColors.success, const Color(0xFF61E6BE));
    expect(AppColors.caution, Colors.amberAccent);
    expect(AppColors.invalid, Colors.orangeAccent);
    expect(AppColors.danger, Colors.redAccent);
  });

  test('defines shared motion and accessibility contracts', () {
    expect(AppMotionDurations.instant, Duration.zero);
    expect(AppMotionDurations.fast, const Duration(milliseconds: 140));
    expect(AppMotionDurations.standard, const Duration(milliseconds: 240));
    expect(AppMotionDurations.emphasized, const Duration(milliseconds: 360));
    expect(AppFontWeights.semibold, FontWeight.w600);
    expect(AppFontWeights.heavy, FontWeight.w800);
    expect(AppTouchTargets.minimum, 48);
  });
}
