import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../navigation/app_destination.dart';
import '../../navigation/app_destination_navigator.dart';
import '../../theme/app_design_tokens.dart';
import 'app_surface_card.dart';

export '../../navigation/app_destination.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.currentPage});

  final AppDestination? currentPage;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSurfaceCard(
                padding: AppSpacing.headerSurfacePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.fitness_center_rounded,
                      color: AppColors.accent,
                      size: 30,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pose Analysis',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizations.workoutMenu,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: AppSurfaceCard(
                  color: AppColors.secondarySurface,
                  borderColor: AppColors.subtleBorder,
                  padding: EdgeInsets.zero,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: AppDestination.values
                        .map(
                          (destination) => _DrawerItem(
                            icon: destination.icon,
                            label: destination.label(localizations),
                            isSelected: currentPage == destination,
                            onTap: () => AppDestinationNavigator.open(
                              context,
                              destination: destination,
                              currentDestination: currentPage,
                            ),
                          ),
                        )
                        .toList(growable: false),
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
    return Material(
      color: Colors.transparent,
      child: ListTile(
        selected: isSelected,
        selectedTileColor: AppColors.accent.withValues(alpha: 0.12),
        leading: Icon(
          icon,
          color: isSelected ? AppColors.accent : Colors.white70,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.accent : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconColor: AppColors.accent,
        textColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        onTap: onTap,
      ),
    );
  }
}
