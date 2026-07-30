import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/camera_permission_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/exercise_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/presentation_test_support.dart';

Finder _exerciseResultsScrollable() {
  return find.descendant(
    of: find.byKey(const PageStorageKey<String>('exercise-selection-results')),
    matching: find.byType(Scrollable),
  );
}

Finder _exerciseCard(String exerciseId) {
  return find.byKey(ValueKey<String>('exercise-selection-card-$exerciseId'));
}

Future<void> _scrollExerciseIntoView(
  WidgetTester tester,
  FinderBase<Element> target,
) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: _exerciseResultsScrollable(),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          switch (call.method) {
            case 'checkPermissionStatus':
              return 0;
            case 'checkServiceStatus':
              return 1;
          }
          return 0;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  testWidgets('renders compact exercise metadata in English', (tester) async {
    await pumpTestApp(
      tester,
      home: const ExerciseSelectionScreen(),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    final squatCard = _exerciseCard('squat');

    expect(squatCard, findsOneWidget);
    expect(
      find.descendant(
        of: squatCard,
        matching: find.text('Lower Body • Repetitions'),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'A foundational movement for lower-body strength and knee-hip control.',
      ),
      findsNothing,
    );
    expect(find.text('Analysis active'), findsNothing);
  });

  testWidgets('renders compact exercise metadata in Turkish', (tester) async {
    await pumpTestApp(
      tester,
      home: const ExerciseSelectionScreen(),
      locale: const Locale('tr'),
    );
    await tester.pumpAndSettle();

    final squatCard = _exerciseCard('squat');

    expect(
      find.descendant(of: squatCard, matching: find.text('Alt Vücut • Tekrar')),
      findsOneWidget,
    );
    expect(
      find.text('Alt vücut kuvveti ve diz-kalça kontrolü için temel hareket.'),
      findsNothing,
    );
  });

  testWidgets('keeps preparation-only setup details out of catalog cards', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const ExerciseSelectionScreen(),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    final squatCard = _exerciseCard('squat');
    expect(
      find.descendant(of: squatCard, matching: find.text('Side view')),
      findsNothing,
    );
    expect(
      find.descendant(of: squatCard, matching: find.text('Standing')),
      findsNothing,
    );

    final plankCard = _exerciseCard('plank');
    await _scrollExerciseIntoView(tester, plankCard);
    expect(
      find.descendant(of: plankCard, matching: find.text('On the floor')),
      findsNothing,
    );
  });

  testWidgets('distinguishes repetition and hold tracking compactly', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const ExerciseSelectionScreen(),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    final squatCard = _exerciseCard('squat');
    expect(
      find.descendant(
        of: squatCard,
        matching: find.text('Lower Body • Repetitions'),
      ),
      findsOneWidget,
    );

    final plankCard = _exerciseCard('plank');
    await _scrollExerciseIntoView(tester, plankCard);
    expect(
      find.descendant(of: plankCard, matching: find.text('Core • Hold')),
      findsOneWidget,
    );
  });

  testWidgets('sit-up card starts the permission flow', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final observer = RecordingNavigatorObserver();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          home: const ExerciseSelectionScreen(),
          navigatorObservers: <NavigatorObserver>[observer],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pushCountBeforeTap = observer.pushCount;
    final card = _exerciseCard('sit_up');
    await _scrollExerciseIntoView(tester, card);

    await tester.tap(card);
    await tester.pump();
    await tester.pump();

    expect(observer.pushCount, pushCountBeforeTap + 1);
    expect(container.read(selectedExerciseProvider), ExerciseType.sitUp);
    expect(find.byType(CameraPermissionScreen), findsOneWidget);
  });

  testWidgets('hollow hold card starts the permission flow', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final observer = RecordingNavigatorObserver();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          home: const ExerciseSelectionScreen(),
          navigatorObservers: <NavigatorObserver>[observer],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pushCountBeforeTap = observer.pushCount;
    final card = _exerciseCard('hollow_hold');
    await _scrollExerciseIntoView(tester, card);

    await tester.tap(card);
    await tester.pump();
    await tester.pump();

    expect(observer.pushCount, pushCountBeforeTap + 1);
    expect(container.read(selectedExerciseProvider), ExerciseType.hollowHold);
    expect(find.byType(CameraPermissionScreen), findsOneWidget);
  });

  testWidgets('stationary lunge card starts the permission flow', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final observer = RecordingNavigatorObserver();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          home: const ExerciseSelectionScreen(),
          navigatorObservers: <NavigatorObserver>[observer],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pushCountBeforeTap = observer.pushCount;
    final card = _exerciseCard('lunge');
    await _scrollExerciseIntoView(tester, card);

    await tester.tap(card);
    await tester.pump();
    await tester.pump();

    expect(observer.pushCount, pushCountBeforeTap + 1);
    expect(container.read(selectedExerciseProvider), ExerciseType.lunge);
    expect(find.byType(CameraPermissionScreen), findsOneWidget);
  });

  testWidgets('biceps curl card starts the permission flow', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final observer = RecordingNavigatorObserver();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          home: const ExerciseSelectionScreen(),
          navigatorObservers: <NavigatorObserver>[observer],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pushCountBeforeTap = observer.pushCount;
    final card = _exerciseCard('biceps_curl');
    await _scrollExerciseIntoView(tester, card);

    await tester.tap(card);
    await tester.pump();
    await tester.pump();

    expect(observer.pushCount, pushCountBeforeTap + 1);
    expect(container.read(selectedExerciseProvider), ExerciseType.bicepsCurl);
    expect(find.byType(CameraPermissionScreen), findsOneWidget);
  });

  testWidgets('category selector expands downward and collapses on selection', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const ExerciseSelectionScreen(),
      locale: const Locale('tr'),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('exercise-category-options')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('exercise-category-selector')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('exercise-category-options')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('exercise-category-upperBody')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('exercise-category-upperBody')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('exercise-category-options')),
      findsNothing,
    );
    final selectedCategory = tester.widget<Text>(
      find.byKey(const ValueKey<String>('selected-exercise-category')),
    );
    expect(selectedCategory.data, 'Üst Vücut');
  });

  testWidgets('filters exercises by target body region', (tester) async {
    await pumpTestApp(
      tester,
      home: const ExerciseSelectionScreen(),
      locale: const Locale('tr'),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('exercise-category-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('exercise-category-upperBody')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Biseps Curl'), findsOneWidget);

    await _scrollExerciseIntoView(tester, find.text('Omuz Press'));

    expect(find.text('Omuz Press'), findsOneWidget);
    expect(find.text('Squat'), findsNothing);
    expect(find.text('Plank'), findsNothing);
  });

  testWidgets('searches localized exercise names', (tester) async {
    await pumpTestApp(
      tester,
      home: const ExerciseSelectionScreen(),
      locale: const Locale('tr'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('exercise-search-field')),
      'omuz press',
    );
    await tester.pumpAndSettle();

    expect(find.text('Omuz Press'), findsOneWidget);
    expect(find.text('Biseps Curl'), findsNothing);
    expect(find.text('Squat'), findsNothing);
  });

  testWidgets('shows a recoverable empty state for unmatched filters', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const ExerciseSelectionScreen(),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('exercise-search-field')),
      'not-a-real-exercise',
    );
    await tester.pumpAndSettle();

    expect(find.text('No exercises found'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('clear-exercise-filters')),
    );
    await tester.pumpAndSettle();

    expect(find.text('All Exercises'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
  });

  testWidgets('renders persisted recent exercises compactly in stored order', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'exerciseSelection.recentExerciseIds': <String>[
        'shoulder_press',
        'biceps_curl',
      ],
    });

    await pumpTestApp(
      tester,
      home: const ExerciseSelectionScreen(),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    final shoulderPressCard = find.byKey(
      const ValueKey<String>('recent-exercise-card-shoulder_press'),
    );
    final bicepsCurlCard = find.byKey(
      const ValueKey<String>('recent-exercise-card-biceps_curl'),
    );

    expect(find.text('Recently Used'), findsOneWidget);
    expect(shoulderPressCard, findsOneWidget);
    expect(bicepsCurlCard, findsOneWidget);
    expect(tester.getSize(shoulderPressCard).width, lessThanOrEqualTo(150));
    expect(tester.getSize(shoulderPressCard).height, lessThanOrEqualTo(64));
    expect(
      tester.getTopLeft(shoulderPressCard).dx,
      lessThan(tester.getTopLeft(bicepsCurlCard).dx),
    );
  });

  testWidgets('shows at least four full exercise rows on a phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTestApp(
      tester,
      home: const ExerciseSelectionScreen(),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    final firstFourCards = <Finder>[
      _exerciseCard('squat'),
      _exerciseCard('plank'),
      _exerciseCard('hollow_hold'),
      _exerciseCard('lunge'),
    ];

    for (final card in firstFourCards) {
      final rect = tester.getRect(card);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(844));
      expect(rect.height, lessThanOrEqualTo(64));
    }
  });
}
