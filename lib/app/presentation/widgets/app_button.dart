import 'package:flutter/material.dart';

import '../../theme/app_design_tokens.dart';
import '../../theme/app_semantic_colors.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final effectiveOnPressed = isLoading ? null : onPressed;
    final foregroundColor = _foregroundColor(colors);
    final content = _ButtonContent(
      label: label,
      icon: icon,
      isLoading: isLoading,
      foregroundColor: foregroundColor,
    );
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppTouchTargets.minimum),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          backgroundColor: colors.accent,
          foregroundColor: Colors.black,
          disabledBackgroundColor: colors.surfaceMuted,
          disabledForegroundColor: colors.foregroundSubtle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.compact),
          ),
        ),
        child: content,
      ),
      AppButtonVariant.secondary => FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppTouchTargets.minimum),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          backgroundColor: colors.surfaceStrong,
          foregroundColor: colors.foreground,
          disabledBackgroundColor: colors.surfaceMuted,
          disabledForegroundColor: colors.foregroundSubtle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.compact),
          ),
        ),
        child: content,
      ),
      AppButtonVariant.outline => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppTouchTargets.minimum),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          foregroundColor: colors.foreground,
          disabledForegroundColor: colors.foregroundSubtle,
          side: BorderSide(color: colors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.compact),
          ),
        ),
        child: content,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppTouchTargets.minimum),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          foregroundColor: colors.accent,
          disabledForegroundColor: colors.foregroundSubtle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ),
        child: content,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppTouchTargets.minimum),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          backgroundColor: colors.danger,
          foregroundColor: Colors.black,
          disabledBackgroundColor: colors.surfaceMuted,
          disabledForegroundColor: colors.foregroundSubtle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.compact),
          ),
        ),
        child: content,
      ),
    };

    return Semantics(
      button: true,
      enabled: effectiveOnPressed != null,
      label: semanticLabel ?? label,
      value: isLoading ? 'loading' : null,
      child: SizedBox(width: expand ? double.infinity : null, child: button),
    );
  }

  Color _foregroundColor(AppSemanticColors colors) {
    return switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.danger => Colors.black,
      AppButtonVariant.secondary ||
      AppButtonVariant.outline => colors.foreground,
      AppButtonVariant.ghost => colors.accent,
    };
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.foregroundColor,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foregroundColor,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ] else if (icon != null) ...[
          Icon(icon, size: 19),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
