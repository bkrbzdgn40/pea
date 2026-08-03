import 'package:flutter/material.dart';

import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';

/// Shared Home preview card for secondary surfaces such as goals and badges.
class HomeFeaturePreviewCard extends StatelessWidget {
  const HomeFeaturePreviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badgeText,
    this.progress,
    this.trailingText,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? badgeText;
  final double? progress;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final normalizedProgress = progress?.clamp(0, 1).toDouble();

    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.surface),
          onTap: onTap,
          child: Ink(
            padding: AppSpacing.surfacePadding,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadii.surface),
              border: Border.all(color: colors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.analysisAccent.withValues(
                          alpha: AppOpacity.subtle,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                      child: Icon(icon, color: colors.analysisAccent, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xxs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colors.foreground,
                                      fontWeight: AppFontWeights.heavy,
                                    ),
                              ),
                              if (badgeText != null)
                                _PreviewBadge(text: badgeText!),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colors.foregroundMuted,
                                  height: 1.3,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.analysisAccent,
                    ),
                  ],
                ),
                if (normalizedProgress != null || trailingText != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trailingText ?? '',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.foregroundMuted,
                                fontWeight: AppFontWeights.semibold,
                              ),
                        ),
                      ),
                      if (normalizedProgress != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '%${(normalizedProgress * 100).round()}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors.analysisAccent,
                                fontWeight: AppFontWeights.heavy,
                              ),
                        ),
                      ],
                    ],
                  ),
                  if (normalizedProgress != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    LinearProgressIndicator(
                      value: normalizedProgress,
                      minHeight: 7,
                      backgroundColor: colors.outlineSubtle,
                      color: colors.analysisAccent,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.analysisAccent,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.black,
            fontWeight: AppFontWeights.heavy,
          ),
        ),
      ),
    );
  }
}
