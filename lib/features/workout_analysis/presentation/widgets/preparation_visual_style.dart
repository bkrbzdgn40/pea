import 'package:flutter/material.dart';

import '../../../../app/presentation/widgets/app_status_tone.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../models/setup_readiness_view_data.dart';

abstract final class PreparationVisualStyle {
  static Color readinessColor(
    BuildContext context,
    SetupReadinessVisualState state,
  ) {
    final colors = context.semanticColors;
    return switch (state) {
      SetupReadinessVisualState.checking => colors.caution,
      SetupReadinessVisualState.needsAdjustment => colors.invalid,
      SetupReadinessVisualState.ready => colors.success,
    };
  }

  static AppStatusTone readinessTone(SetupReadinessVisualState state) {
    return switch (state) {
      SetupReadinessVisualState.checking => AppStatusTone.caution,
      SetupReadinessVisualState.needsAdjustment => AppStatusTone.invalid,
      SetupReadinessVisualState.ready => AppStatusTone.success,
    };
  }

  static IconData readinessIcon(SetupReadinessVisualState state) {
    return switch (state) {
      SetupReadinessVisualState.checking => Icons.center_focus_weak_rounded,
      SetupReadinessVisualState.needsAdjustment => Icons.navigation_rounded,
      SetupReadinessVisualState.ready => Icons.check_circle_rounded,
    };
  }

  static Color checkColor(
    BuildContext context,
    SetupReadinessCheckState state,
  ) {
    final colors = context.semanticColors;
    return switch (state) {
      SetupReadinessCheckState.pending => colors.foregroundSubtle,
      SetupReadinessCheckState.needsAdjustment => colors.invalid,
      SetupReadinessCheckState.complete => colors.success,
    };
  }

  static IconData checkIcon(SetupReadinessCheckState state) {
    return switch (state) {
      SetupReadinessCheckState.pending => Icons.more_horiz_rounded,
      SetupReadinessCheckState.needsAdjustment => Icons.priority_high_rounded,
      SetupReadinessCheckState.complete => Icons.check_rounded,
    };
  }
}
