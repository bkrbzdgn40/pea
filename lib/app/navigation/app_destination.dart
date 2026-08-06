import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';

enum AppDestination {
  home(icon: Icons.home_rounded, routeName: '/home'),
  howToUse(icon: Icons.help_outline_rounded, routeName: '/how-to-use'),
  exerciseSelection(
    icon: Icons.directions_run_rounded,
    routeName: '/exercises',
  ),
  sessionHistory(icon: Icons.history_rounded, routeName: '/history'),
  analytics(icon: Icons.query_stats_rounded, routeName: '/analytics'),
  achievements(icon: Icons.emoji_events_rounded, routeName: '/achievements'),
  goals(icon: Icons.flag_rounded, routeName: '/goals'),
  guide(icon: Icons.menu_book_rounded, routeName: '/guide'),
  market(icon: Icons.storefront_rounded, routeName: '/market'),
  settings(icon: Icons.settings_rounded, routeName: '/settings');

  const AppDestination({required this.icon, required this.routeName});

  final IconData icon;
  final String routeName;

  String label(AppLocalizations localizations) {
    return switch (this) {
      AppDestination.home => localizations.home,
      AppDestination.howToUse => localizations.howToUse,
      AppDestination.exerciseSelection => localizations.selectExercise,
      AppDestination.sessionHistory => localizations.sessionHistory,
      AppDestination.analytics => localizations.analytics,
      AppDestination.achievements => localizations.achievements,
      AppDestination.goals => localizations.goals,
      AppDestination.guide => localizations.exerciseGuide,
      AppDestination.market => localizations.market,
      AppDestination.settings => localizations.settings,
    };
  }
}
