import 'package:flutter/material.dart';

import '../../theme/app_design_tokens.dart';
import '../../theme/app_semantic_colors.dart';
import 'app_status_tone.dart';
import 'app_surface_card.dart';

class AppMetricTile extends StatelessWidget {
  const AppMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.supportingText,
    this.icon,
    this.tone = AppStatusTone.accent,
    this.trailing,
    this.semanticLabel,
  });

  final String label;
  final String value;
  final String? supportingText;
  final IconData? icon;
  final AppStatusTone tone;
  final Widget? trailing;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final toneColor = tone.resolveColor(colors);

    return Semantics(
      container: true,
      label: semanticLabel ?? '$label: $value',
      child: AppSurfaceCard(
        variant: AppSurfaceVariant.muted,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: toneColor.withValues(alpha: AppOpacity.subtle),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Icon(icon, color: toneColor, size: 21),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.foregroundMuted,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.foreground,
                      fontWeight: AppFontWeights.heavy,
                      height: 1.05,
                    ),
                  ),
                  if (supportingText != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      supportingText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
