import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../providers/market_cart_provider.dart';

class MarketCartAction extends ConsumerWidget {
  const MarketCartAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final itemCount = ref.watch(
      marketCartProvider.select((cart) => cart.itemCount),
    );

    return Semantics(
      button: true,
      label: itemCount == 0
          ? localizations.marketCart
          : localizations.marketCartItemCount(itemCount),
      child: ExcludeSemantics(
        child: IconButton(
          key: const Key('market-cart-action'),
          tooltip: localizations.marketCart,
          onPressed: onPressed,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_bag_outlined),
              if (itemCount > 0)
                PositionedDirectional(
                  top: -8,
                  end: -10,
                  child: Container(
                    key: const Key('market-cart-count-badge'),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.analysisAccent,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: colors.canvas, width: 2),
                    ),
                    child: Text(
                      itemCount > 99 ? '99+' : '$itemCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.canvas,
                        fontWeight: AppFontWeights.heavy,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
