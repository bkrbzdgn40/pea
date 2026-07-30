import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/saved_workout_plan.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/saved_workout_plans_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/workout_plan_setup_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
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

    expect(find.text('Planlı Antrenman'), findsOneWidget);
    expect(find.text('Plan henüz boş'), findsOneWidget);

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

    await _addExercise(tester, ExerciseType.squat);
    await _addExercise(tester, ExerciseType.plank);

    final reorderable = tester.widget<ReorderableListView>(
      find.byKey(const ValueKey<String>('workout-plan-entry-list')),
    );
    reorderable.onReorder(1, 0);
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

  testWidgets('saves a named plan and restores it from saved plans', (
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

    await tester.enterText(
      find.byKey(const ValueKey<String>('workout-plan-name-field')),
      'Ev Planı',
    );
    await _addExercise(tester, ExerciseType.bicepsCurl);

    final saveButton = find.byKey(const ValueKey<String>('save-workout-plan'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.tap(saveButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(repository.plans, hasLength(1));
    expect(repository.plans.single.name, 'Ev Planı');
    expect(
      repository.plans.single.entries.single.exercise,
      ExerciseType.bicepsCurl,
    );
    expect(find.text('Plan kaydedildi.'), findsOneWidget);
    expect(find.text('Plan henüz boş'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('workout-plan-name-field')),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.widget<OutlinedButton>(saveButton).onPressed, isNull);

    await tester.tap(
      find.byKey(ValueKey<String>('load-plan-${repository.plans.single.id}')),
    );
    await tester.pump();

    expect(find.text('1. Biseps Curl'), findsOneWidget);
    expect(find.text('Plan güncel.'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(saveButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey<String>('workout-plan-name-field')),
      'Ev Planı 2',
    );
    await tester.pump();

    expect(find.text('Kaydedilmemiş değişiklikler var.'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(saveButton).onPressed, isNotNull);
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

    final reviewButton = find.byKey(
      const ValueKey<String>('review-workout-plan'),
    );
    expect(tester.widget<ElevatedButton>(reviewButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey<String>('workout-plan-name-field')),
      'Core Planı',
    );
    await _addExercise(tester, ExerciseType.plank);
    await tester.ensureVisible(reviewButton);
    expect(tester.widget<ElevatedButton>(reviewButton).onPressed, isNotNull);

    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    expect(find.text('Plan Özeti'), findsOneWidget);
    expect(find.text('Core Planı'), findsOneWidget);
    expect(find.text('1. Plank'), findsNothing);
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
    expect(tester.widget<OutlinedButton>(reviewSaveButton).onPressed, isNull);

    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
    expect(find.text('Plan henüz boş'), findsOneWidget);
  });

  testWidgets('protects an unsaved draft before starting a new plan', (
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

    await tester.enterText(
      find.byKey(const ValueKey<String>('workout-plan-name-field')),
      'Kaydedilmemiş Plan',
    );
    await _addExercise(tester, ExerciseType.squat);

    final newPlanButton = find.text('Yeni plan');
    await tester.ensureVisible(newPlanButton);
    await tester.tap(newPlanButton);
    await tester.pumpAndSettle();

    expect(find.text('Değişiklikler silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(find.text('1. Squat'), findsOneWidget);

    await tester.tap(newPlanButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Değişiklikleri Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Plan henüz boş'), findsOneWidget);
  });

  testWidgets('protects an unsaved draft when leaving the builder', (
    WidgetTester tester,
  ) async {
    _useTallPhoneViewport(tester);
    final repository = _MemoryWorkoutPlanRepository();
    await pumpTestApp(
      tester,
      home: const _WorkoutPlanSetupHost(),
      overrides: [workoutPlanRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('open-plan-builder')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('workout-plan-name-field')),
      'Kaydedilmemiş Plan',
    );
    await _addExercise(tester, ExerciseType.squat);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Değişiklikler silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(find.text('1. Squat'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Değişiklikleri Sil'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('open-plan-builder')),
      findsOneWidget,
    );
    expect(find.text('1. Squat'), findsNothing);
  });

  testWidgets('keeps builder usable on a compact phone viewport', (
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

    await _addExercise(tester, ExerciseType.plank);
    final reviewButton = find.byKey(
      const ValueKey<String>('review-workout-plan'),
    );
    await tester.ensureVisible(reviewButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(reviewButton, findsOneWidget);
  });
}

void _useTallPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

class _WorkoutPlanSetupHost extends StatelessWidget {
  const _WorkoutPlanSetupHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey<String>('open-plan-builder'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const WorkoutPlanSetupScreen(),
              ),
            );
          },
          child: const Text('Plan oluşturucuyu aç'),
        ),
      ),
    );
  }
}
