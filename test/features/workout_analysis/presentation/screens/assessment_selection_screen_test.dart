import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/assessment_selection_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('shows all three assessment modes with a clinical disclaimer', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(tester, home: const AssessmentSelectionScreen());
    await tester.pump();

    expect(find.text('Squat Değerlendirmesi'), findsOneWidget);
    expect(find.text('Denge Değerlendirmesi'), findsOneWidget);
    expect(find.text('Omuz Elevasyon Değerlendirmesi'), findsOneWidget);
    expect(find.textContaining('klinik tanı'), findsOneWidget);
    expect(find.textContaining('normalize image-plane'), findsNothing);
    expect(find.textContaining('gövde kompansasyonu'), findsNothing);
  });

  testWidgets('renders assessment selection in English', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const AssessmentSelectionScreen(),
      locale: const Locale('en'),
    );
    await tester.pump();

    expect(find.text('Assessment Mode'), findsOneWidget);
    expect(find.text('Squat Assessment'), findsOneWidget);
    expect(find.text('Balance Assessment'), findsOneWidget);
    expect(find.text('Shoulder Elevation Assessment'), findsOneWidget);
    expect(find.textContaining('clinical diagnosis'), findsOneWidget);
  });
}
