import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../navigation/app_destination.dart';
import '../../navigation/app_destination_navigator.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_semantic_colors.dart';
import 'app_surface_card.dart';

export '../../navigation/app_destination.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.currentPage});

  final AppDestination? currentPage;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSurfaceCard(
                variant: AppSurfaceVariant.strong,
                padding: AppSpacing.headerSurfacePadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: colors.analysisAccent.withValues(
                          alpha: AppOpacity.subtle,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.compact),
                        border: Border.all(
                          color: colors.analysisAccent.withValues(
                            alpha: AppOpacity.strongBorder,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: colors.accent,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pose Analysis',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleLarge?.copyWith(
                              color: colors.foreground,
                              fontWeight: AppFontWeights.heavy,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            localizations.workoutMenu,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: AppSurfaceCard(
                  variant: AppSurfaceVariant.muted,
                  padding: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    itemCount: AppDestination.values.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xxs),
                    itemBuilder: (context, index) {
                      final destination = AppDestination.values[index];
                      return _DrawerItem(
                        icon: destination.icon,
                        label: destination.label(localizations),
                        isSelected: currentPage == destination,
                        onTap: () => AppDestinationNavigator.open(
                          context,
                          destination: destination,
                          currentDestination: currentPage,
                        ),
                      );
                    },
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

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        selected: isSelected,
        leading: Icon(icon),
        title: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: isSelected ? colors.accent : colors.foreground,
            fontWeight: AppFontWeights.semibold,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.circle,
                color: colors.accent,
                size: 8,
                semanticLabel: null,
              )
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        onTap: onTap,
      ),
    );
  }
}
