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
    expect(find.text('Omuz Mobilitesi'), findsOneWidget);
    expect(find.textContaining('klinik tanı'), findsOneWidget);
  });
}
