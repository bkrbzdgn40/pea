import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/workout_plan_setup_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('shows supported exercises and explicit default targets', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(tester, home: const WorkoutPlanSetupScreen());
    await tester.pump();

    expect(find.text('Planlı Antrenman'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('1 set • 10 tekrar'), findsAtLeastNWidgets(1));
    expect(find.text('1 set • 30 saniye tutuş'), findsAtLeastNWidgets(1));
    expect(find.text('En az bir hareket seç'), findsOneWidget);
  });

  testWidgets('renders planned workout setup in English', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const WorkoutPlanSetupScreen(),
      locale: const Locale('en'),
    );
    await tester.pump();

    expect(find.text('Planned Workout'), findsOneWidget);
    expect(find.text('Number of rounds'), findsOneWidget);
    expect(find.text('1 set • 10 reps'), findsAtLeastNWidgets(1));
    expect(find.text('1 set • 30-second hold'), findsAtLeastNWidgets(1));
    expect(find.text('Select at least one exercise'), findsOneWidget);
  });
}
