import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_drawer.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/features/achievements/presentation/models/achievement.dart';
import 'package:pose_estimation_app/features/achievements/presentation/providers/achievements_provider.dart';
import 'package:pose_estimation_app/features/goals/presentation/models/workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/home_dashboard_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/home_dashboard_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/exercise_selection_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/guide_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/home_screen.dart';

import '../../../support/presentation_test_harness.dart';
import '../../../support/presentation_test_support.dart';

void main() {
  test('AppDestination exposes route-only drawer metadata', () {
    expect(AppDestination.values, <AppDestination>[
      AppDestination.home,
      AppDestination.howToUse,
      AppDestination.exerciseSelection,
      AppDestination.sessionHistory,
      AppDestination.guide,
      AppDestination.settings,
    ]);
    expect(
      AppDestination.values
          .map(
            (destination) =>
                destination.label(const AppLocalizations(Locale('tr'))),
          )
          .toSet(),
      <String>{
        'Ana Sayfa',
        'Nasıl Kullanılır',
        'Hareket Seç',
        'Geçmiş Oturumlar',
        'Hareket Rehberi',
        'Ayarlar',
      },
    );
    expect(
      AppDestination.values
          .map(
            (destination) =>
                destination.label(const AppLocalizations(Locale('en'))),
          )
          .toSet(),
      <String>{
        'Home',
        'How to Use',
        'Select Exercise',
        'Session History',
        'Exercise Guide',
        'Settings',
      },
    );
    expect(
      AppDestination.values.map((destination) => destination.routeName).toSet(),
      <String>{
        '/home',
        '/how-to-use',
        '/exercises',
        '/history',
        '/guide',
        '/settings',
      },
    );
    expect(
      AppDestination.values.map((destination) => destination.icon).toList(),
      <IconData>[
        Icons.home_rounded,
        Icons.help_outline_rounded,
        Icons.directions_run_rounded,
        Icons.history_rounded,
        Icons.menu_book_rounded,
        Icons.settings_rounded,
      ],
    );
  });

  testWidgets('drawer remains usable with compact large text', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      locale: const Locale('tr'),
      configuration: const PresentationTestConfiguration(
        viewport: PresentationTestViewport.compactPortrait,
        textScaleFactor: 2,
      ),
      home: const _DrawerHost(currentPage: AppDestination.home),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();

    expect(find.text('Pose Analysis'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Geçmiş Oturumlar'), findsOneWidget);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('current destination selection only closes the drawer', (
    WidgetTester tester,
  ) async {
    final observer = _RootNavigationObserver();

    await pumpTestApp(
      tester,
      navigatorObservers: <NavigatorObserver>[observer],
      locale: const Locale('tr'),
      home: const _DrawerHost(currentPage: AppDestination.settings),
    );
    await tester.pumpAndSettle();

    final replaceCountBefore = observer.replaceCount;
    final pushCountBefore = observer.pushCount;

    await _selectDrawerDestination(tester, 'Ayarlar');

    expect(observer.replaceCount, replaceCountBefore);
    expect(observer.pushCount, pushCountBefore);
    expect(find.text('Drawer Host'), findsOneWidget);
  });

  testWidgets('repeated history selection never grows the route stack', (
    WidgetTester tester,
  ) async {
    final observer = _RootNavigationObserver();

    await pumpTestApp(
      tester,
      navigatorObservers: <NavigatorObserver>[observer],
      locale: const Locale('tr'),
      home: const _DrawerHost(currentPage: AppDestination.sessionHistory),
    );
    await tester.pumpAndSettle();

    final replaceCountBefore = observer.replaceCount;
    final pushCountBefore = observer.pushCount;

    for (var index = 0; index < 5; index += 1) {
      await _selectDrawerDestination(tester, 'Geçmiş Oturumlar');
    }

    expect(observer.replaceCount, replaceCountBefore);
    expect(observer.pushCount, pushCountBefore);
    expect(find.text('Drawer Host'), findsOneWidget);
  });

  testWidgets('home stays below the first drawer destination', (
    WidgetTester tester,
  ) async {
    final observer = _RootNavigationObserver();

    await pumpTestApp(
      tester,
      navigatorObservers: <NavigatorObserver>[observer],
      locale: const Locale('tr'),
      home: const _DrawerHost(currentPage: AppDestination.home),
    );
    await tester.pumpAndSettle();

    final pushCountBefore = observer.pushCount;
    final replaceCountBefore = observer.replaceCount;

    await _selectDrawerDestination(tester, 'Hareket Seç');

    expect(observer.pushCount, pushCountBefore + 1);
    expect(observer.replaceCount, replaceCountBefore);
    expect(observer.lastNewRoute?.settings.name, '/exercises');
    expect(find.byType(ExerciseSelectionScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Drawer Host'), findsOneWidget);
    expect(find.byType(ExerciseSelectionScreen), findsNothing);
  });

  testWidgets('different drawer destination replaces the current drawer root', (
    WidgetTester tester,
  ) async {
    final observer = _RootNavigationObserver();

    await pumpTestApp(
      tester,
      navigatorObservers: <NavigatorObserver>[observer],
      locale: const Locale('tr'),
      home: const _DrawerHost(currentPage: AppDestination.home),
    );
    await tester.pumpAndSettle();

    await _selectDrawerDestination(tester, 'Nasıl Kullanılır');
    final replaceCountBefore = observer.replaceCount;

    await _selectDrawerDestination(tester, 'Hareket Seç');

    expect(observer.replaceCount, replaceCountBefore + 1);
    expect(observer.lastNewRoute?.settings.name, '/exercises');
    expect(find.byType(ExerciseSelectionScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();

    final selectedTileFinder = find.widgetWithText(ListTile, 'Hareket Seç');
    final selectedTile = tester.widget<ListTile>(selectedTileFinder);
    final selectedShape = selectedTile.shape! as RoundedRectangleBorder;

    expect(selectedTile.selected, isTrue);
    expect(selectedShape.borderRadius, BorderRadius.circular(AppRadii.small));

    Navigator.of(tester.element(selectedTileFinder)).pop();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Drawer Host'), findsOneWidget);
    expect(find.byType(ExerciseSelectionScreen), findsNothing);
  });

  testWidgets('home selection resets the complete root stack', (
    WidgetTester tester,
  ) async {
    final observer = _RootNavigationObserver();

    await pumpTestApp(
      tester,
      navigatorObservers: <NavigatorObserver>[observer],
      locale: const Locale('tr'),
      overrides: [
        homeDashboardProvider.overrideWith(
          (ref) =>
              HomeDashboardData.fallback(source: HomeDashboardSource.empty),
        ),
        goalsProvider.overrideWith(
          (ref) => const GoalsState(
            source: GoalsDataSource.empty,
            goals: <WorkoutGoal>[],
          ),
        ),
        achievementsProvider.overrideWith(
          (ref) => const AchievementsState(
            source: AchievementsDataSource.empty,
            achievements: <Achievement>[],
          ),
        ),
      ],
      home: const _DrawerHost(currentPage: AppDestination.guide),
    );
    await tester.pumpAndSettle();

    final pushCountBefore = observer.pushCount;

    await _selectDrawerDestination(tester, 'Ana Sayfa');

    expect(observer.pushCount, pushCountBefore + 1);
    expect(observer.lastNewRoute?.settings.name, '/home');
    expect(observer.removeCount, greaterThanOrEqualTo(1));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('replacement keeps the previous non-root route predictable', (
    WidgetTester tester,
  ) async {
    final observer = _RootNavigationObserver();

    await pumpTestApp(
      tester,
      navigatorObservers: <NavigatorObserver>[observer],
      locale: const Locale('tr'),
      home: const _NavigationRootHost(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open drawer route'));
    await tester.pumpAndSettle();
    await _selectDrawerDestination(tester, 'Hareket Rehberi');

    expect(find.byType(GuideScreen), findsOneWidget);
    expect(observer.lastNewRoute?.settings.name, '/guide');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Navigation Root'), findsOneWidget);
    expect(find.byType(GuideScreen), findsNothing);
  });
}

Future<void> _selectDrawerDestination(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.menu).first);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, label));
  await tester.pumpAndSettle();
}

class _DrawerHost extends StatelessWidget {
  const _DrawerHost({required this.currentPage});

  final AppDestination currentPage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drawer Host')),
      drawer: AppDrawer(currentPage: currentPage),
      body: const SizedBox.shrink(),
    );
  }
}

class _NavigationRootHost extends StatelessWidget {
  const _NavigationRootHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const _DrawerHost(currentPage: AppDestination.settings),
              ),
            );
          },
          child: const Text('Open drawer route'),
        ),
      ),
      appBar: AppBar(title: const Text('Navigation Root')),
    );
  }
}

class _RootNavigationObserver extends NavigatorObserver {
  int pushCount = 0;
  int replaceCount = 0;
  int removeCount = 0;
  Route<dynamic>? lastNewRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    lastNewRoute = route;
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replaceCount += 1;
    lastNewRoute = newRoute;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    removeCount += 1;
    super.didRemove(route, previousRoute);
  }
}
