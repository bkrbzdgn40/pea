import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/market_product.dart';
import '../formatters/market_price_formatter.dart';
import '../providers/market_cart_provider.dart';
import '../widgets/market_cart_action.dart';
import '../widgets/market_product_visual.dart';
import 'market_cart_screen.dart';

class MarketProductDetailScreen extends ConsumerWidget {
  const MarketProductDetailScreen({super.key, required this.product});

  final MarketProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return AppScaffoldShell(
      title: localizations.marketProductName(product.id),
      showDrawer: false,
      maxContentWidth: 760,
      actions: [MarketCartAction(onPressed: () => _openMarketCart(context))],
      body: _MarketProductDetail(product: product),
    );
  }
}

class _MarketProductDetail extends ConsumerWidget {
  const _MarketProductDetail({required this.product});

  final MarketProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final quantity = ref.watch(
      marketCartProvider.select((cart) => cart.quantityFor(product.id)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppLayout.of(context, constraints: constraints);
        final visualHeight = layout.isLandscape ? 180.0 : 260.0;
        final visualIconSize = layout.isLandscape ? 72.0 : 92.0;

        return SingleChildScrollView(
          key: ValueKey('market-product-detail-${product.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSurfaceCard(
                variant: AppSurfaceVariant.strong,
                padding: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: visualHeight,
                  child: MarketProductVisual(
                    productId: product.id,
                    imageAssetPath: product.imageAssetPath,
                    iconSize: visualIconSize,
                    semanticLabel: localizations.marketProductImageLabel(
                      localizations.marketProductName(product.id),
                    ),
                  ),
                ),
              ),
              SizedBox(height: layout.panelGap),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.analysisAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(
                      color: colors.analysisAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    localizations.marketCategoryLabel(product.category.id),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.analysisAccent,
                      fontWeight: AppFontWeights.heavy,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                localizations.marketProductName(product.id),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.foreground,
                  fontWeight: AppFontWeights.heavy,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                MarketPriceFormatter(
                  localizations.locale,
                ).format(product.price),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.foreground,
                  fontWeight: AppFontWeights.heavy,
                ),
              ),
              if (quantity > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    key: const Key('market-product-cart-status'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(
                        color: colors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: colors.success,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          localizations.marketInCart(quantity),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors.success,
                                fontWeight: AppFontWeights.heavy,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const Key('market-add-to-cart'),
                onPressed: () {
                  ref.read(marketCartProvider.notifier).add(product);
                },
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: Text(
                  quantity == 0
                      ? localizations.marketAddToCart
                      : localizations.marketAddAnotherToCart,
                ),
              ),
              SizedBox(height: layout.panelGap),
              AppSurfaceCard(
                variant: AppSurfaceVariant.standard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.marketProductInformation,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.foreground,
                        fontWeight: AppFontWeights.heavy,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      localizations.marketProductDescription(product.id),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.foregroundMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: layout.panelGap),
              AppSurfaceCard(
                variant: AppSurfaceVariant.muted,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: colors.foregroundMuted,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        localizations.marketTemplateProductDetailMessage,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.foregroundMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
            ],
          ),
        );
      },
    );
  }
}

void _openMarketCart(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const MarketCartScreen()),
  );
}
