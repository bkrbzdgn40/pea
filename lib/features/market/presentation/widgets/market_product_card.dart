import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/market_product.dart';
import '../formatters/market_price_formatter.dart';
import 'market_product_visual.dart';

class MarketProductCard extends StatelessWidget {
  const MarketProductCard({super.key, required this.product, this.onTap});

  final MarketProduct product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final productName = localizations.marketProductName(product.id);
    final price = MarketPriceFormatter(
      localizations.locale,
    ).format(product.price);

    return Semantics(
      container: true,
      button: onTap != null,
      label: onTap == null
          ? '$productName, $price'
          : localizations.marketOpenProductDetails(productName, price),
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.large),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AppSurfaceCard(
            key: ValueKey('market-product-${product.id}'),
            variant: AppSurfaceVariant.strong,
            borderColor: product.isFeatured
                ? colors.analysisAccent.withValues(alpha: 0.38)
                : colors.outline,
            radius: AppRadii.large,
            padding: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MarketProductCardVisual(
                        product: product,
                        featuredLabel: localizations.marketFeaturedLabel,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: colors.foreground,
                                  fontWeight: AppFontWeights.heavy,
                                  height: 1.2,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            price,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: colors.analysisAccent,
                                  fontWeight: AppFontWeights.heavy,
                                  letterSpacing: -0.2,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketProductCardVisual extends StatelessWidget {
  const _MarketProductCardVisual({
    required this.product,
    required this.featuredLabel,
  });

  final MarketProduct product;
  final String featuredLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Stack(
      key: ValueKey('market-product-visual-frame-${product.id}'),
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.analysisAccent.withValues(alpha: 0.16),
                colors.surfaceStrong,
                colors.analysisAccent.withValues(alpha: 0.06),
              ],
              stops: const [0, 0.62, 1],
            ),
          ),
        ),
        Positioned(
          right: -30,
          top: -34,
          child: IgnorePointer(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.analysisAccent.withValues(alpha: 0.12),
                  width: 18,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.surface),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: MarketProductVisual(
                  productId: product.id,
                  imageAssetPath: product.imageAssetPath,
                ),
              ),
            ),
          ),
        ),
        if (product.isFeatured)
          PositionedDirectional(
            top: AppSpacing.xs,
            start: AppSpacing.xs,
            child: _FeaturedBadge(label: featuredLabel),
          ),
        PositionedDirectional(
          end: AppSpacing.xs,
          bottom: AppSpacing.xs,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: colors.outline),
            ),
            child: Icon(
              Icons.north_east_rounded,
              size: 18,
              color: colors.analysisAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Container(
        key: const Key('market-product-featured-badge'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: colors.analysisAccent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: [
            BoxShadow(
              color: colors.analysisAccent.withValues(alpha: 0.24),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 13, color: colors.canvas),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.canvas,
                fontWeight: AppFontWeights.heavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
