import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/preparation_screen.dart';

import '../../../../support/presentation_test_support.dart';
import '../../../../support/workout_analysis_test_support.dart';

void main() {
  testWidgets('uses preparation terminology when no exercise is selected', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const PreparationScreen(),
      locale: const Locale('en'),
    );
    await tester.pump();

    expect(find.byType(PreparationScreen), findsOneWidget);
    expect(find.text('Preparation'), findsOneWidget);
    expect(find.text('Choose an exercise before preparation'), findsOneWidget);
    expect(
      find.text(
        'A valid exercise selection is required before preparation and analysis can begin.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('calibration'), findsNothing);
  });

  testWidgets(
    'keeps the existing preparation behavior for a selected exercise',
    (tester) async {
      await pumpTestApp(
        tester,
        home: const PreparationScreen(),
        locale: const Locale('tr'),
        overrides: <Override>[
          selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
          exerciseConfigProvider.overrideWith((ref) => buildSquatConfig()),
        ],
      );
      await tester.pump();

      expect(find.byType(PreparationScreen), findsOneWidget);
      expect(find.text('Hazırlık'), findsOneWidget);
      expect(find.text('Squat analizi öncesi'), findsOneWidget);
      expect(find.text('Telefonu sabit bir yere koy.'), findsOneWidget);
      expect(find.text('Squat analizine başla'), findsOneWidget);
    },
  );
}
