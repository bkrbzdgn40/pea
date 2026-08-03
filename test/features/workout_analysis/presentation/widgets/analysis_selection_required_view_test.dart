import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_state_views.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/analysis_selection_required_view.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('uses the shared empty-state surface and action', (
    WidgetTester tester,
  ) async {
    var actionCount = 0;

    await pumpTestApp(
      tester,
      configuration: const PresentationTestConfiguration(
        viewport: PresentationTestViewport.compactPortrait,
        textScaleFactor: 2,
      ),
      home: Scaffold(
        body: AnalysisSelectionRequiredView(
          title: 'Hareket seçimi gerekli',
          message: 'Analize devam etmek için bir hareket seçmelisiniz.',
          onSelectExercise: () => actionCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppEmptyView), findsOneWidget);
    expect(find.text('Hareket seçimi gerekli'), findsOneWidget);
    expect(find.text('Hareket Seç'), findsOneWidget);
    expectNoPresentationExceptions(tester);

    final actionFinder = find.text('Hareket Seç');
    await tester.ensureVisible(actionFinder);
    await tester.pumpAndSettle();
    await tester.tap(actionFinder);
    await tester.pump();

    expect(actionCount, 1);
  });
}
