import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../domain/models/market_category.dart';

class MarketCategoryFilter extends StatelessWidget {
  const MarketCategoryFilter({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  final MarketCategory? selectedCategory;
  final ValueChanged<MarketCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return SingleChildScrollView(
      key: const Key('market-category-scroll-view'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: Text(localizations.marketAllCategories),
            selected: selectedCategory == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final category in MarketCategory.values) ...[
            const SizedBox(width: AppSpacing.xs),
            FilterChip(
              key: ValueKey('market-category-${category.id}'),
              label: Text(localizations.marketCategoryLabel(category.id)),
              selected: selectedCategory == category,
              onSelected: (_) => onSelected(category),
            ),
          ],
        ],
      ),
    );
  }
}
