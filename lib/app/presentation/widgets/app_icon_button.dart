import 'package:flutter/material.dart';

import '../../theme/app_design_tokens.dart';
import '../../theme/app_semantic_colors.dart';

enum AppIconButtonVariant { standard, filled, danger }

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = AppIconButtonVariant.standard,
    this.iconSize = 22,
    this.isSelected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AppIconButtonVariant variant;
  final double iconSize;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final foregroundColor = switch (variant) {
      AppIconButtonVariant.standard =>
        isSelected ? colors.accent : colors.foreground,
      AppIconButtonVariant.filled => colors.foreground,
      AppIconButtonVariant.danger => colors.danger,
    };
    final backgroundColor = switch (variant) {
      AppIconButtonVariant.standard =>
        isSelected
            ? colors.accent.withValues(alpha: AppOpacity.subtle)
            : Colors.transparent,
      AppIconButtonVariant.filled => colors.surfaceStrong,
      AppIconButtonVariant.danger => colors.danger.withValues(
        alpha: AppOpacity.subtle,
      ),
    };

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: iconSize,
      constraints: const BoxConstraints.tightFor(
        width: AppTouchTargets.minimum,
        height: AppTouchTargets.minimum,
      ),
      style: IconButton.styleFrom(
        foregroundColor: foregroundColor,
        disabledForegroundColor: colors.foregroundSubtle,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
      ),
      icon: Icon(icon, semanticLabel: tooltip),
    );
  }
}
