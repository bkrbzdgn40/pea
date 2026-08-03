import 'package:flutter/material.dart';

import '../../theme/app_design_tokens.dart';
import '../../theme/app_semantic_colors.dart';

enum AppSurfaceVariant { standard, muted, strong, accent }

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.surfacePadding,
    this.variant = AppSurfaceVariant.standard,
    this.color,
    this.borderColor,
    this.radius = AppRadii.surface,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final AppSurfaceVariant variant;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final resolvedColors = _resolveColors(colors);

    return Container(
      clipBehavior: clipBehavior,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? resolvedColors.background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? resolvedColors.border),
      ),
      child: child,
    );
  }

  _AppSurfaceColors _resolveColors(AppSemanticColors colors) {
    return switch (variant) {
      AppSurfaceVariant.standard => _AppSurfaceColors(
        background: colors.surface,
        border: colors.outline,
      ),
      AppSurfaceVariant.muted => _AppSurfaceColors(
        background: colors.surfaceMuted,
        border: colors.outlineSubtle,
      ),
      AppSurfaceVariant.strong => _AppSurfaceColors(
        background: colors.surfaceStrong,
        border: colors.outline,
      ),
      AppSurfaceVariant.accent => _AppSurfaceColors(
        background: colors.analysisAccent.withValues(alpha: AppOpacity.subtle),
        border: colors.analysisAccent.withValues(
          alpha: AppOpacity.strongBorder,
        ),
      ),
    };
  }
}

class _AppSurfaceColors {
  const _AppSurfaceColors({required this.background, required this.border});

  final Color background;
  final Color border;
}
