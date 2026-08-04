import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';

class MarketCatalogHeader extends StatelessWidget {
  const MarketCatalogHeader({super.key, required this.productCount});

  final int productCount;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      variant: AppSurfaceVariant.accent,
      padding: AppSpacing.headerSurfacePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.analysisAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.compact),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: colors.analysisAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      localizations.marketCatalogTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.foreground,
                        fontWeight: AppFontWeights.heavy,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.analysisAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(
                          color: colors.analysisAccent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        localizations.marketPreviewLabel,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.analysisAccent,
                              fontWeight: AppFontWeights.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  localizations.marketCatalogDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  localizations.marketExampleProductCount(productCount),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
