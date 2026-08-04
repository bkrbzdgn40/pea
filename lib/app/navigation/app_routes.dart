import 'package:flutter/material.dart';

import '../../features/market/presentation/screens/market_screen.dart';
import '../../features/workout_analysis/presentation/screens/exercise_selection_screen.dart';
import '../../features/workout_analysis/presentation/screens/guide_screen.dart';
import '../../features/workout_analysis/presentation/screens/home_screen.dart';
import '../../features/workout_analysis/presentation/screens/how_to_use_screen.dart';
import '../../features/workout_analysis/presentation/screens/session_history_screen.dart';
import '../../features/workout_analysis/presentation/screens/settings_screen.dart';
import 'app_destination.dart';

abstract final class AppRoutes {
  static final Map<String, WidgetBuilder> builders =
      Map<String, WidgetBuilder>.unmodifiable(<String, WidgetBuilder>{
        AppDestination.home.routeName: (_) => const HomeScreen(),
        AppDestination.howToUse.routeName: (_) => const HowToUseScreen(),
        AppDestination.exerciseSelection.routeName: (_) =>
            const ExerciseSelectionScreen(),
        AppDestination.sessionHistory.routeName: (_) =>
            const SessionHistoryScreen(),
        AppDestination.guide.routeName: (_) => const GuideScreen(),
        AppDestination.market.routeName: (_) => const MarketScreen(),
        AppDestination.settings.routeName: (_) => const SettingsScreen(),
      });
}
