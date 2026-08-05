import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/assessment_selection_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('shows three camera measurements with a clinical disclaimer', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(tester, home: const AssessmentSelectionScreen());
    await tester.pump();

    expect(find.text('Kamera Ölçümleri'), findsOneWidget);
    expect(find.text('Squat Hareket Ölçümü'), findsOneWidget);
    expect(find.text('Tek Ayak Duruş Ölçümü'), findsOneWidget);
    expect(find.text('Omuz Hareket Ölçümü'), findsOneWidget);
    expect(find.textContaining('klinik tanı'), findsOneWidget);
    expect(find.textContaining('normalize image-plane'), findsNothing);
    expect(find.textContaining('gövde kompansasyonu'), findsNothing);
    expect(find.textContaining('fleksiyon'), findsNothing);
    expect(find.textContaining('elevasyon'), findsNothing);
  });

  test('uses plain movement language for result labels', () {
    const tr = AppLocalizations(Locale('tr'));
    const en = AppLocalizations(Locale('en'));

    expect(tr.kneeFlexion, 'Diz bükülme açısı');
    expect(tr.stabilityScore, 'Denge göstergesi');
    expect(tr.leftMaximumElevation, 'Sol kol kaldırma açısı');
    expect(en.kneeFlexion, 'Knee bend angle');
    expect(en.stabilityScore, 'Balance indicator');
    expect(en.leftMaximumElevation, 'Left arm raise angle');
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

    expect(find.text('Camera Measurements'), findsOneWidget);
    expect(find.text('Squat Movement Check'), findsOneWidget);
    expect(find.text('Single-Leg Stance Check'), findsOneWidget);
    expect(find.text('Shoulder Movement Check'), findsOneWidget);
    expect(find.textContaining('clinical diagnosis'), findsOneWidget);
    expect(find.textContaining('elevation'), findsNothing);
  });
}
