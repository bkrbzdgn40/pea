import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../theme/app_design_tokens.dart';
import '../../../features/workout_analysis/presentation/screens/exercise_selection_screen.dart';
import '../../../features/workout_analysis/presentation/screens/guide_screen.dart';
import '../../../features/workout_analysis/presentation/screens/how_to_use_screen.dart';
import '../../../features/workout_analysis/presentation/screens/home_screen.dart';
import '../../../features/workout_analysis/presentation/screens/session_history_screen.dart';
import '../../../features/workout_analysis/presentation/screens/settings_screen.dart';
import 'app_surface_card.dart';

enum AppDestination {
  home(
    icon: Icons.home_rounded,
    builder: _buildHome,
    suppressPushWhenCurrent: true,
  ),
  howToUse(
    icon: Icons.help_outline_rounded,
    builder: _buildHowToUse,
    suppressPushWhenCurrent: true,
  ),
  exerciseSelection(
    icon: Icons.directions_run_rounded,
    builder: _buildExerciseSelection,
  ),
  sessionHistory(icon: Icons.history_rounded, builder: _buildSessionHistory),
  guide(icon: Icons.menu_book_rounded, builder: _buildGuide),
  settings(icon: Icons.settings_rounded, builder: _buildSettings);

  const AppDestination({
    required this.icon,
    required this.builder,
    this.suppressPushWhenCurrent = false,
  });

  final IconData icon;
  final WidgetBuilder builder;
  final bool suppressPushWhenCurrent;

  String label(AppLocalizations localizations) {
    return switch (this) {
      AppDestination.home => localizations.home,
      AppDestination.howToUse => localizations.howToUse,
      AppDestination.exerciseSelection => localizations.selectExercise,
      AppDestination.sessionHistory => localizations.sessionHistory,
      AppDestination.guide => localizations.exerciseGuide,
      AppDestination.settings => localizations.settings,
    };
  }

  static Widget _buildHome(BuildContext context) => const HomeScreen();

  static Widget _buildHowToUse(BuildContext context) => const HowToUseScreen();

  static Widget _buildExerciseSelection(BuildContext context) =>
      const ExerciseSelectionScreen();

  static Widget _buildSessionHistory(BuildContext context) =>
      const SessionHistoryScreen();

  static Widget _buildGuide(BuildContext context) => const GuideScreen();

  static Widget _buildSettings(BuildContext context) => const SettingsScreen();
}

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
                            onTap: () => _open(
                              context,
                              destination,
                              isCurrent: currentPage == destination,
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

  void _open(
    BuildContext context,
    AppDestination destination, {
    bool isCurrent = false,
  }) {
    final navigator = Navigator.of(context);
    navigator.pop();
    if (isCurrent && destination.suppressPushWhenCurrent) return;
    navigator.push(MaterialPageRoute(builder: destination.builder));
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
