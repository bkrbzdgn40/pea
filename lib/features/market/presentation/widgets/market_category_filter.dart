import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
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
    final colors = context.semanticColors;

    return Container(
      key: const Key('market-category-filter-surface'),
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: colors.outlineSubtle),
      ),
      child: SingleChildScrollView(
        key: const Key('market-category-scroll-view'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _MarketCategoryChip(
              key: const Key('market-category-all'),
              label: localizations.marketAllCategories,
              icon: Icons.grid_view_rounded,
              selected: selectedCategory == null,
              onSelected: () => onSelected(null),
            ),
            for (final category in MarketCategory.values) ...[
              const SizedBox(width: AppSpacing.xs),
              _MarketCategoryChip(
                key: ValueKey('market-category-${category.id}'),
                label: localizations.marketCategoryLabel(category.id),
                icon: _categoryIcon(category),
                selected: selectedCategory == category,
                onSelected: () => onSelected(category),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketCategoryChip extends StatelessWidget {
  const _MarketCategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final foreground = selected ? colors.canvas : colors.foreground;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: FilterChip(
          selected: selected,
          onSelected: (_) => onSelected(),
          showCheckmark: false,
          avatar: Icon(icon, size: 18, color: foreground),
          label: Text(label),
          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foreground,
            fontWeight: selected
                ? AppFontWeights.heavy
                : AppFontWeights.semibold,
          ),
          backgroundColor: colors.surfaceStrong,
          selectedColor: colors.analysisAccent,
          side: BorderSide(
            color: selected ? colors.analysisAccent : colors.outline,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }
}

IconData _categoryIcon(MarketCategory category) {
  return switch (category) {
    MarketCategory.setup => Icons.videocam_outlined,
    MarketCategory.strength => Icons.fitness_center_rounded,
    MarketCategory.mobility => Icons.self_improvement_rounded,
    MarketCategory.accessories => Icons.sports_gymnastics_rounded,
    MarketCategory.apparel => Icons.checkroom_rounded,
  };
}
