import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_drawer.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/exercise_selection_screen.dart';

import '../../../support/presentation_test_support.dart';

void main() {
  test('AppDestination exposes the exact typed drawer metadata set', () {
    expect(AppDestination.values, <AppDestination>[
      AppDestination.home,
      AppDestination.howToUse,
      AppDestination.exerciseSelection,
      AppDestination.sessionHistory,
      AppDestination.guide,
      AppDestination.settings,
    ]);
    expect(
      AppDestination.values.map((destination) => destination.label).toSet(),
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
          .map((destination) => destination.name)
          .toSet()
          .length,
      6,
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

  testWidgets(
    'keeps the selected destination highlighted and does not push it',
    (WidgetTester tester) async {
      final observer = RecordingNavigatorObserver();

      await pumpTestApp(
        tester,
        navigatorObservers: [observer],
        home: Scaffold(
          appBar: AppBar(title: const Text('Drawer Host')),
          drawer: const AppDrawer(currentPage: AppDestination.howToUse),
          body: const SizedBox.shrink(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      final selectedTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Nasıl Kullanılır'),
      );
      final pushCountAfterOpening = observer.pushCount;

      expect(selectedTile.selected, isTrue);

      await tester.tap(find.text('Nasıl Kullanılır'));
      await tester.pumpAndSettle();

      expect(observer.pushCount, pushCountAfterOpening);
    },
  );

  testWidgets('pushes a MaterialPageRoute for a different destination', (
    WidgetTester tester,
  ) async {
    final observer = RecordingNavigatorObserver();

    await pumpTestApp(
      tester,
      navigatorObservers: [observer],
      home: Scaffold(
        appBar: AppBar(title: const Text('Drawer Host')),
        drawer: const AppDrawer(currentPage: AppDestination.howToUse),
        body: const SizedBox.shrink(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    final pushCountAfterOpening = observer.pushCount;

    await tester.tap(find.text('Hareket Seç'));
    await tester.pumpAndSettle();

    expect(observer.pushCount, pushCountAfterOpening + 1);
    expect(observer.lastPushedRoute, isA<MaterialPageRoute<dynamic>>());
    expect(find.byType(ExerciseSelectionScreen), findsOneWidget);
  });
}
