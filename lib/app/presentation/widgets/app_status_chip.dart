import 'package:flutter/material.dart';

import '../../theme/app_design_tokens.dart';
import '../../theme/app_semantic_colors.dart';
import 'app_status_tone.dart';

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.icon,
    this.showIcon = true,
    this.semanticLabel,
  });

  final String label;
  final AppStatusTone tone;
  final IconData? icon;
  final bool showIcon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final toneColor = tone.resolveColor(colors);

    return Semantics(
      container: true,
      label: semanticLabel ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs + 2,
        ),
        decoration: BoxDecoration(
          color: toneColor.withValues(alpha: AppOpacity.subtle),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: toneColor.withValues(alpha: AppOpacity.strongBorder),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(icon ?? tone.defaultIcon, size: 15, color: toneColor),
              const SizedBox(width: AppSpacing.xxs + 2),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: toneColor,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
