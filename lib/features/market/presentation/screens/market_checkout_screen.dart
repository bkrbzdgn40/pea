import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/market_cart.dart';
import '../../domain/models/market_cart_line.dart';
import '../formatters/market_price_formatter.dart';
import '../providers/market_cart_provider.dart';
import '../widgets/market_empty_state.dart';

class MarketCheckoutScreen extends ConsumerWidget {
  const MarketCheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final isEmpty = ref.watch(
      marketCartProvider.select((cart) => cart.isEmpty),
    );

    return AppScaffoldShell(
      title: localizations.marketCheckoutTitle,
      showDrawer: false,
      maxContentWidth: 760,
      body: isEmpty
          ? MarketEmptyState(
              key: const Key('market-checkout-empty-state'),
              icon: Icons.receipt_long_outlined,
              title: localizations.marketCheckoutEmptyTitle,
              message: localizations.marketCheckoutEmptyMessage,
              actionLabel: localizations.marketReturnToCart,
              actionKey: const Key('market-checkout-return-to-cart'),
              onAction: () => Navigator.of(context).maybePop(),
            )
          : const _MarketCheckoutContent(),
    );
  }
}

class _MarketCheckoutContent extends ConsumerWidget {
  const _MarketCheckoutContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(marketCartProvider);
    final layout = AppLayout.of(context);
    final localizations = AppLocalizations.of(context);

    return CustomScrollView(
      key: const Key('market-checkout-scroll-view'),
      slivers: [
        const SliverToBoxAdapter(child: _CheckoutTemplateNotice()),
        SliverToBoxAdapter(child: SizedBox(height: layout.panelGap)),
        SliverToBoxAdapter(
          child: _CheckoutPlaceholderCard(
            key: const Key('market-checkout-delivery-card'),
            icon: Icons.local_shipping_outlined,
            title: localizations.marketDeliveryInformation,
            message: localizations.marketDeliveryTemplateMessage,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: layout.panelGap)),
        SliverToBoxAdapter(
          child: _CheckoutPlaceholderCard(
            key: const Key('market-checkout-payment-card'),
            icon: Icons.payment_outlined,
            title: localizations.marketPaymentMethod,
            message: localizations.marketPaymentTemplateMessage,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: layout.panelGap)),
        SliverToBoxAdapter(child: _OrderItemsCard(lines: cart.lines)),
        SliverToBoxAdapter(child: SizedBox(height: layout.panelGap)),
        SliverToBoxAdapter(child: _OrderTotalCard(cart: cart)),
        SliverToBoxAdapter(child: SizedBox(height: layout.panelGap)),
        SliverToBoxAdapter(
          child: FilledButton(
            key: const Key('market-checkout-disabled-payment'),
            onPressed: null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    localizations.marketCheckoutTemplateTitle,
                    textAlign: TextAlign.center,
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

class _CheckoutTemplateNotice extends StatelessWidget {
  const _CheckoutTemplateNotice();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: const Key('market-checkout-template-notice'),
      variant: AppSurfaceVariant.accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: colors.analysisAccent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.marketCheckoutTemplateTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  localizations.marketCheckoutTemplateDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.4,
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

class _CheckoutPlaceholderCard extends StatelessWidget {
  const _CheckoutPlaceholderCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return AppSurfaceCard(
      variant: AppSurfaceVariant.standard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.foregroundMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.4,
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

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.lines});

  final List<MarketCartLine> lines;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: const Key('market-checkout-order-items'),
      variant: AppSurfaceVariant.strong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizations.marketOrderItems,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < lines.length; index++) ...[
            _OrderLineSummary(line: lines[index]),
            if (index != lines.length - 1)
              Divider(height: AppSpacing.xl, color: colors.outlineSubtle),
          ],
        ],
      ),
    );
  }
}

class _OrderLineSummary extends StatelessWidget {
  const _OrderLineSummary({required this.line});

  final MarketCartLine line;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final formatter = MarketPriceFormatter(localizations.locale);

    return Column(
      key: ValueKey('market-checkout-line-${line.product.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations.marketProductName(line.product.id),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: colors.foreground,
            fontWeight: AppFontWeights.semibold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              '${line.quantity} × ${formatter.format(line.product.price)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.foregroundMuted),
            ),
            Text(
              formatter.format(line.lineTotal),
              key: ValueKey('market-checkout-line-total-${line.product.id}'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.foreground,
                fontWeight: AppFontWeights.heavy,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderTotalCard extends StatelessWidget {
  const _OrderTotalCard({required this.cart});

  final MarketCart cart;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final total = MarketPriceFormatter(
      localizations.locale,
    ).format(cart.subtotal);

    return AppSurfaceCard(
      key: const Key('market-checkout-total-card'),
      variant: AppSurfaceVariant.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResponsiveAmountRow(
            label: localizations.marketSubtotal,
            value: total,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            localizations.marketCheckoutTotalNote,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.foregroundMuted,
              height: 1.4,
            ),
          ),
          Divider(height: AppSpacing.xl, color: colors.outlineSubtle),
          _ResponsiveAmountRow(
            label: localizations.marketCheckoutTotal,
            value: total,
            valueKey: const Key('market-checkout-total-value'),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _ResponsiveAmountRow extends StatelessWidget {
  const _ResponsiveAmountRow({
    required this.label,
    required this.value,
    this.valueKey,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useStackedLayout = textScale >= 1.5 || constraints.maxWidth < 260;
        final textTheme = Theme.of(context).textTheme;
        final colors = context.semanticColors;

        final labelWidget = Text(
          label,
          style: (emphasize ? textTheme.titleMedium : textTheme.bodyLarge)
              ?.copyWith(
                color: colors.foreground,
                fontWeight: emphasize
                    ? AppFontWeights.heavy
                    : AppFontWeights.semibold,
              ),
        );
        final valueWidget = Text(
          value,
          key: valueKey,
          textAlign: TextAlign.end,
          style: (emphasize ? textTheme.titleLarge : textTheme.bodyLarge)
              ?.copyWith(
                color: colors.foreground,
                fontWeight: AppFontWeights.heavy,
              ),
        );

        if (useStackedLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              labelWidget,
              const SizedBox(height: AppSpacing.xs),
              Align(alignment: Alignment.centerRight, child: valueWidget),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: labelWidget),
            const SizedBox(width: AppSpacing.sm),
            valueWidget,
          ],
        );
      },
    );
  }
}
