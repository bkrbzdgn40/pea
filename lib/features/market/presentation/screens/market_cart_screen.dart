import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/market_cart_line.dart';
import '../formatters/market_price_formatter.dart';
import '../providers/market_cart_provider.dart';
import '../widgets/market_empty_state.dart';
import '../widgets/market_product_visual.dart';
import 'market_checkout_screen.dart';

class MarketCartScreen extends ConsumerWidget {
  const MarketCartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final isEmpty = ref.watch(
      marketCartProvider.select((cart) => cart.isEmpty),
    );

    return AppScaffoldShell(
      title: localizations.marketCart,
      showDrawer: false,
      maxContentWidth: 760,
      body: isEmpty
          ? MarketEmptyState(
              key: const Key('market-cart-empty-state'),
              icon: Icons.shopping_bag_outlined,
              title: localizations.marketCartEmptyTitle,
              message: localizations.marketCartEmptyMessage,
              actionLabel: localizations.marketContinueShopping,
              actionKey: const Key('market-cart-return-to-products'),
              onAction: () => Navigator.of(context).maybePop(),
            )
          : const _MarketCartContent(),
    );
  }
}

class _MarketCartContent extends ConsumerWidget {
  const _MarketCartContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(marketCartProvider);
    final localizations = AppLocalizations.of(context);
    final layout = AppLayout.of(context);
    final lines = cart.lines;

    return CustomScrollView(
      key: const Key('market-cart-scroll-view'),
      slivers: [
        SliverToBoxAdapter(
          child: _CartOverviewCard(
            itemCount: cart.itemCount,
            lineCount: cart.lines.length,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: layout.panelGap)),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index.isOdd) {
              return SizedBox(height: layout.panelGap);
            }
            return _MarketCartLineCard(line: lines[index ~/ 2]);
          }, childCount: lines.isEmpty ? 0 : (lines.length * 2) - 1),
        ),
        SliverToBoxAdapter(child: SizedBox(height: layout.panelGap)),
        SliverToBoxAdapter(
          child: AppSurfaceCard(
            key: const Key('market-cart-summary'),
            variant: AppSurfaceVariant.accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final useStackedLayout =
                        textScale >= 1.5 || constraints.maxWidth < 260;

                    final label = Text(
                      localizations.marketSubtotal,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: AppFontWeights.heavy,
                      ),
                    );
                    final value = Text(
                      MarketPriceFormatter(
                        localizations.locale,
                      ).format(cart.subtotal),
                      key: const Key('market-cart-subtotal-value'),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: AppFontWeights.heavy,
                      ),
                    );

                    if (useStackedLayout) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          label,
                          const SizedBox(height: AppSpacing.xs),
                          Align(alignment: Alignment.centerRight, child: value),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: label),
                        const SizedBox(width: AppSpacing.sm),
                        value,
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  localizations.marketCheckoutTemplateMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.semanticColors.foregroundMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: const Key('market-proceed-to-checkout'),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const MarketCheckoutScreen(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_outlined),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          localizations.marketProceedToCheckout,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxs)),
      ],
    );
  }
}

class _CartOverviewCard extends StatelessWidget {
  const _CartOverviewCard({required this.itemCount, required this.lineCount});

  final int itemCount;
  final int lineCount;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: const Key('market-cart-overview'),
      variant: AppSurfaceVariant.muted,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.analysisAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.compact),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              color: colors.analysisAccent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.marketCartOverviewTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  localizations.marketCartOverviewSummary(itemCount, lineCount),
                  key: const Key('market-cart-overview-summary'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foregroundMuted,
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

class _MarketCartLineCard extends ConsumerWidget {
  const _MarketCartLineCard({required this.line});

  final MarketCartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final controller = ref.read(marketCartProvider.notifier);

    return AppSurfaceCard(
      key: ValueKey('market-cart-line-${line.product.id}'),
      variant: AppSurfaceVariant.strong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.small),
                child: SizedBox.square(
                  dimension: 72,
                  child: MarketProductVisual(
                    productId: line.product.id,
                    imageAssetPath: line.product.imageAssetPath,
                    iconSize: 36,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.marketProductName(line.product.id),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.foreground,
                        fontWeight: AppFontWeights.heavy,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      MarketPriceFormatter(
                        localizations.locale,
                      ).format(line.product.price),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.foregroundMuted,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: localizations.marketRemoveProductFromCart(
                  localizations.marketProductName(line.product.id),
                ),
                child: ExcludeSemantics(
                  child: IconButton(
                    key: ValueKey('market-cart-remove-${line.product.id}'),
                    tooltip: localizations.marketRemoveFromCart,
                    onPressed: () => controller.remove(line.product.id),
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: colors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _QuantityControl(line: line),
              Text(
                MarketPriceFormatter(
                  localizations.locale,
                ).format(line.lineTotal),
                key: ValueKey('market-cart-line-total-${line.product.id}'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.foreground,
                  fontWeight: AppFontWeights.heavy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityControl extends ConsumerWidget {
  const _QuantityControl({required this.line});

  final MarketCartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final controller = ref.read(marketCartProvider.notifier);
    final productName = localizations.marketProductName(line.product.id);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: colors.outlineSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: localizations.marketDecreaseProductQuantity(productName),
            child: ExcludeSemantics(
              child: IconButton(
                key: ValueKey('market-cart-decrement-${line.product.id}'),
                tooltip: localizations.marketDecreaseQuantity,
                onPressed: () => controller.decrement(line.product.id),
                icon: const Icon(Icons.remove_rounded),
              ),
            ),
          ),
          Semantics(
            container: true,
            liveRegion: true,
            label: localizations.marketProductQuantityValue(
              productName,
              line.quantity,
            ),
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 28),
                child: Text(
                  '${line.quantity}',
                  key: ValueKey('market-cart-quantity-${line.product.id}'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: localizations.marketIncreaseProductQuantity(productName),
            child: ExcludeSemantics(
              child: IconButton(
                key: ValueKey('market-cart-increment-${line.product.id}'),
                tooltip: localizations.marketIncreaseQuantity,
                onPressed: () => controller.increment(line.product.id),
                icon: const Icon(Icons.add_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
