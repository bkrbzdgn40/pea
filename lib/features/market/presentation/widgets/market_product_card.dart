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
        child: AppSurfaceCard(
          key: ValueKey('market-product-${product.id}'),
          variant: AppSurfaceVariant.strong,
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: colors.outlineSubtle),
                        ),
                      ),
                      child: MarketProductVisual(
                        productId: product.id,
                        imageAssetPath: product.imageAssetPath,
                      ),
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
                                color: colors.foreground,
                                fontWeight: AppFontWeights.heavy,
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
    );
  }
}
