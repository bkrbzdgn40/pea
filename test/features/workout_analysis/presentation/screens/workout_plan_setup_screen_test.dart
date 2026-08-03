import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_button.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/saved_workout_plan.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/saved_workout_plans_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/workout_plan_setup_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('opens the plan builder in a modal bottom sheet', (tester) async {
    _useTallPhoneViewport(tester);
    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('workout-plan-builder-sheet')),
      findsNothing,
    );

    await _openNewPlanBuilder(tester);

    expect(
      find.byKey(const ValueKey<String>('workout-plan-builder-sheet')),
      findsOneWidget,
    );
    expect(find.text('Plan henüz boş'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('workout-plan-name-field')),
      findsOneWidget,
    );
  });

  testWidgets('builds an ordered plan and allows duplicate exercises', (
    WidgetTester tester,
  ) async {
    _useTallPhoneViewport(tester);
    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await _openNewPlanBuilder(tester);

    await _addExercise(tester, ExerciseType.squat);
    await _addExercise(tester, ExerciseType.plank);

    expect(find.text('1. Squat'), findsOneWidget);
    expect(find.text('2. Plank'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.copy_rounded).first);
    await tester.pump();

    expect(find.text('1. Squat'), findsOneWidget);
    expect(find.text('2. Squat'), findsOneWidget);
    expect(find.text('3. Plank'), findsOneWidget);
  });

  testWidgets('reorders entries and edits set, target, and rest values', (
    WidgetTester tester,
  ) async {
    _useTallPhoneViewport(tester);
    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await _openNewPlanBuilder(tester);

    await _addExercise(tester, ExerciseType.squat);
    await _addExercise(tester, ExerciseType.plank);

    final reorderable = tester.widget<ReorderableListView>(
      find.byKey(const ValueKey<String>('workout-plan-entry-list')),
    );
    final reorder = (reorderable as dynamic).onReorder as ReorderCallback;
    reorder(1, 0);
    await tester.pump();

    expect(find.text('1. Plank'), findsOneWidget);
    expect(find.text('2. Squat'), findsOneWidget);

    await tester.tap(find.byTooltip('Set +').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Tutuş hedefi +').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Dinlenme +').first);
    await tester.pump();

    expect(find.text('2'), findsAtLeastNWidgets(1));
    expect(find.text('35 sn'), findsOneWidget);
    expect(find.text('30 sn'), findsOneWidget);
  });

  testWidgets('caps plan rest at sixty seconds', (WidgetTester tester) async {
    _useTallPhoneViewport(tester);
    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await _openNewPlanBuilder(tester);
    await _addExercise(tester, ExerciseType.squat);

    final addRest = find.byTooltip('Dinlenme +').first;
    for (var index = 0; index < 3; index += 1) {
      await tester.tap(addRest);
      await tester.pump();
    }

    expect(find.text('60 sn'), findsOneWidget);
    await tester.tap(addRest, warnIfMissed: false);
    await tester.pump();
    expect(find.text('60 sn'), findsOneWidget);
  });

  testWidgets('uses a searchable horizontally filtered exercise picker', (
    WidgetTester tester,
  ) async {
    _useTallPhoneViewport(tester);
    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await _openNewPlanBuilder(tester);

    final addButton = find.byKey(const ValueKey<String>('add-plan-exercise'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('plan-exercise-region-scroll')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('plan-exercise-picker-list')),
      findsOneWidget,
    );
    expect(find.text('Tüm Hareketler'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('plan-exercise-search')),
      'plank',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('plan-picker-plank')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('plan-picker-squat')),
      findsNothing,
    );
  });

  testWidgets('reorders entries downward using the adjusted item index', (
    WidgetTester tester,
  ) async {
    _useTallPhoneViewport(tester);
    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await _openNewPlanBuilder(tester);

    await _addExercise(tester, ExerciseType.squat);
    await _addExercise(tester, ExerciseType.plank);
    await _addExercise(tester, ExerciseType.bicepsCurl);

    final reorderable = tester.widget<ReorderableListView>(
      find.byKey(const ValueKey<String>('workout-plan-entry-list')),
    );
    final reorder = (reorderable as dynamic).onReorder as ReorderCallback;
    reorder(0, 3);
    await tester.pump();

    expect(find.text('1. Plank'), findsOneWidget);
    expect(find.text('2. Biseps Curl'), findsOneWidget);
    expect(find.text('3. Squat'), findsOneWidget);
  });

  testWidgets('opens saved plan actions directly from its card', (
    WidgetTester tester,
  ) async {
    _useTallPhoneViewport(tester);
    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await _openNewPlanBuilder(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('workout-plan-name-field')),
      'Ev Planı',
    );
    await _addExercise(tester, ExerciseType.bicepsCurl);

    final saveButton = find.byKey(const ValueKey<String>('save-workout-plan'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(repository.plans, hasLength(1));
    final plan = repository.plans.single;
    expect(find.text('Plan kaydedildi.'), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('edit-plan-${plan.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('start-plan-${plan.id}')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ValueKey<String>('edit-plan-${plan.id}')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('workout-plan-builder-sheet')),
      findsOneWidget,
    );
    expect(find.text('1. Biseps Curl'), findsOneWidget);
    expect(find.text('Plan güncel.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('workout-plan-name-field')),
          )
          .controller!
          .text,
      'Ev Planı',
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('workout-plan-name-field')),
      'Ev Planı 2',
    );
    await tester.pump();

    expect(find.text('Kaydedilmemiş değişiklikler var.'), findsOneWidget);
    expect(tester.widget<AppButton>(saveButton).onPressed, isNotNull);
  });

  testWidgets('stacks saved plans vertically inside the page scroll', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemoryWorkoutPlanRepository();
    repository.plans.addAll(
      List<SavedWorkoutPlan>.generate(
        6,
        (index) => _savedPlan(
          id: 'plan-$index',
          name: 'Plan ${index + 1}',
          exercise: index.isEven ? ExerciseType.squat : ExerciseType.plank,
        ),
      ),
    );
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    final firstCard = find.byKey(
      const ValueKey<String>('saved-plan-card-plan-0'),
    );
    final secondCard = find.byKey(
      const ValueKey<String>('saved-plan-card-plan-1'),
    );
    expect(
      tester.getTopLeft(secondCard).dy,
      greaterThan(tester.getBottomLeft(firstCard).dy),
    );
    final exerciseStrip = tester.widget<ListView>(
      find.byKey(const ValueKey<String>('plan-exercise-strip-plan-0')),
    );
    expect(exerciseStrip.scrollDirection, Axis.horizontal);

    await tester.ensureVisible(find.text('Plan 6'));
    await tester.pumpAndSettle();

    expect(find.text('Plan 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens a plan summary only after name and exercises exist', (
    WidgetTester tester,
  ) async {
    _useTallPhoneViewport(tester);
    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await _openNewPlanBuilder(tester);

    final reviewButton = find.byKey(
      const ValueKey<String>('review-workout-plan'),
    );
    expect(tester.widget<AppButton>(reviewButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey<String>('workout-plan-name-field')),
      'Core Planı',
    );
    await _addExercise(tester, ExerciseType.plank);
    await tester.ensureVisible(reviewButton);
    expect(tester.widget<AppButton>(reviewButton).onPressed, isNotNull);

    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    expect(find.text('Plan Özeti'), findsOneWidget);
    expect(find.text('Core Planı'), findsOneWidget);
    expect(find.text('Plank'), findsOneWidget);
    expect(
      find.text('1 set • 30 saniye tutuş • set sonrası 15 sn dinlenme'),
      findsOneWidget,
    );
    expect(find.text('Planı Başlat'), findsOneWidget);

    final reviewSaveButton = find.byKey(
      const ValueKey<String>('review-save-plan'),
    );
    await tester.tap(reviewSaveButton);
    await tester.tap(reviewSaveButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(tester.widget<AppButton>(reviewSaveButton).onPressed, isNull);

    final reviewEditButton = find.byKey(
      const ValueKey<String>('review-edit-plan'),
    );
    await tester.ensureVisible(reviewEditButton);
    await tester.pumpAndSettle();
    await tester.tap(reviewEditButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('workout-plan-builder-sheet')),
      findsOneWidget,
    );
    expect(find.text('1. Plank'), findsOneWidget);
    expect(find.text('Plan güncel.'), findsOneWidget);
  });

  testWidgets('protects an unsaved draft before closing the builder sheet', (
    WidgetTester tester,
  ) async {
    _useTallPhoneViewport(tester);
    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await _openNewPlanBuilder(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('workout-plan-name-field')),
      'Kaydedilmemiş Plan',
    );
    await _addExercise(tester, ExerciseType.squat);

    await tester.tap(
      find.byKey(const ValueKey<String>('close-workout-plan-builder')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Değişiklikler silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(find.text('1. Squat'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('close-workout-plan-builder')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Değişiklikleri Sil'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('workout-plan-builder-sheet')),
      findsNothing,
    );
  });

  testWidgets('protects an unsaved modal draft on Android back', (
    WidgetTester tester,
  ) async {
    _useTallPhoneViewport(tester);
    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await _openNewPlanBuilder(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('workout-plan-name-field')),
      'Kaydedilmemiş Plan',
    );
    await _addExercise(tester, ExerciseType.squat);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Değişiklikler silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Değişiklikleri Sil'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('workout-plan-builder-sheet')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('new-workout-plan')),
      findsOneWidget,
    );
  });

  testWidgets('keeps the modal builder usable on a compact phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await _openNewPlanBuilder(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('workout-plan-name-field')),
      'Hızlı Core Planı',
    );
    await _addExercise(tester, ExerciseType.plank);
    final reviewButton = find.byKey(
      const ValueKey<String>('review-workout-plan'),
    );
    final startButton = find.byKey(
      const ValueKey<String>('start-workout-plan'),
    );
    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(reviewButton, findsOneWidget);
    expect(find.text('Kaydet ve Başlat'), findsOneWidget);
    expect(tester.widget<AppButton>(startButton).onPressed, isNotNull);
  });

  testWidgets('uses split plan editing in landscape', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await _openNewPlanBuilder(tester);

    expect(
      find.byKey(const ValueKey<String>('workout-plan-builder-split-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workout-plan-settings-scroll')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to stacked editing with large landscape text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await _openNewPlanBuilder(tester);

    expect(
      find.byKey(const ValueKey<String>('workout-plan-builder-stacked-layout')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

void _useTallPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openNewPlanBuilder(WidgetTester tester) async {
  final newPlanButton = find.byKey(const ValueKey<String>('new-workout-plan'));
  await tester.ensureVisible(newPlanButton);
  await tester.pumpAndSettle();
  await tester.tap(newPlanButton);
  await tester.pumpAndSettle();
}

Future<void> _addExercise(WidgetTester tester, ExerciseType exercise) async {
  final addButton = find.byKey(const ValueKey<String>('add-plan-exercise'));
  await tester.ensureVisible(addButton);
  await tester.tap(addButton);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey<String>('plan-exercise-search')),
    exercise.title,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey<String>('plan-picker-${exercise.id}')));
  await tester.pumpAndSettle();
}

SavedWorkoutPlan _savedPlan({
  required String id,
  required String name,
  required ExerciseType exercise,
}) {
  return SavedWorkoutPlan(
    id: id,
    name: name,
    rounds: 1,
    entries: [
      SavedWorkoutPlanEntry(
        id: '$id-entry',
        exercise: exercise,
        sets: 1,
        target: exercise == ExerciseType.plank
            ? const WorkoutTarget.hold(Duration(seconds: 30))
            : const WorkoutTarget.repetitions(10),
        restAfterSet: const Duration(seconds: 15),
      ),
    ],
    updatedAt: DateTime(2026, 7, 30),
  );
}

class _MemoryWorkoutPlanRepository implements WorkoutPlanRepository {
  final List<SavedWorkoutPlan> plans = <SavedWorkoutPlan>[];
  int saveCalls = 0;

  @override
  Future<void> deletePlan(String planId) async {
    plans.removeWhere((plan) => plan.id == planId);
  }

  @override
  Future<List<SavedWorkoutPlan>> loadPlans() async {
    return List<SavedWorkoutPlan>.unmodifiable(plans);
  }

  @override
  Future<void> savePlan(SavedWorkoutPlan plan) async {
    saveCalls += 1;
    plans.removeWhere((existing) => existing.id == plan.id);
    plans.insert(0, plan);
  }
}
