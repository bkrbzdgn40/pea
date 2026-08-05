import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/market_product.dart';
import '../providers/market_catalog_provider.dart';
import '../widgets/market_cart_action.dart';
import '../widgets/market_category_filter.dart';
import '../widgets/market_empty_state.dart';
import '../widgets/market_product_card.dart';
import 'market_cart_screen.dart';
import 'market_product_detail_screen.dart';

class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final catalog = ref.watch(marketCatalogProvider);

    return AppScaffoldShell(
      title: localizations.market,
      currentPage: AppDestination.market,
      actions: [MarketCartAction(onPressed: () => _openMarketCart(context))],
      body: catalog.when(
        data: (products) => _MarketCatalog(products: products),
        loading: () => const _MarketCatalogLoading(),
        error: (_, _) => MarketEmptyState(
          key: const Key('market-catalog-error'),
          icon: Icons.inventory_2_outlined,
          title: localizations.marketCatalogLoadFailedTitle,
          message: localizations.marketCatalogLoadFailedMessage,
          actionLabel: localizations.retry,
          actionIcon: Icons.refresh_rounded,
          actionKey: const Key('market-catalog-retry'),
          onAction: () => ref.invalidate(marketCatalogProvider),
        ),
      ),
    );
  }
}

class _MarketCatalogLoading extends StatelessWidget {
  const _MarketCatalogLoading();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    final colors = context.semanticColors;

    return Center(
      key: const Key('market-catalog-loading'),
      child: AppSurfaceCard(
        variant: AppSurfaceVariant.muted,
        radius: AppRadii.large,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.analysisAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.analysisAccent.withValues(alpha: 0.28),
                ),
              ),
              child: const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.marketCatalogLoading,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.foregroundMuted,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketCatalog extends ConsumerWidget {
  const _MarketCatalog({required this.products});

  final List<MarketProduct> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedMarketCategoryProvider);
    final filteredProducts = selectedCategory == null
        ? products
        : products
              .where((product) => product.category == selectedCategory)
              .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppLayout.of(context, constraints: constraints);
        final cardExtent = layout.hasLargeText ? 268.0 : 236.0;

        final colors = context.semanticColors;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            PositionedDirectional(
              top: -76,
              end: -92,
              child: IgnorePointer(
                child: Container(
                  width: 228,
                  height: 228,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.analysisAccent.withValues(alpha: 0.09),
                        colors.analysisAccent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            CustomScrollView(
              key: const Key('market-catalog-scroll-view'),
              slivers: [
                SliverToBoxAdapter(
                  child: MarketCategoryFilter(
                    selectedCategory: selectedCategory,
                    onSelected: (category) {
                      ref.read(selectedMarketCategoryProvider.notifier).state =
                          category;
                    },
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: layout.panelGap)),
                SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: layout.panelGap,
                    mainAxisSpacing: layout.panelGap,
                    mainAxisExtent: cardExtent,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final product = filteredProducts[index];
                    return MarketProductCard(
                      product: product,
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                MarketProductDetailScreen(product: product),
                          ),
                        );
                      },
                    );
                  }, childCount: filteredProducts.length),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxs),
                ),
              ],
            ),
          ],
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
