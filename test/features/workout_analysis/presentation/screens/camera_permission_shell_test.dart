import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_scaffold_shell.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/camera_permission_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/analysis_selection_required_view.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('missing selection uses the shared root shell', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const CameraPermissionScreen(),
      configuration: const PresentationTestConfiguration(
        viewport: PresentationTestViewport.compactPortrait,
        textScaleFactor: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppScaffoldShell), findsOneWidget);
    expect(find.byType(AnalysisSelectionRequiredView), findsOneWidget);
    expect(find.text('Kamera İzni'), findsOneWidget);
    expectNoPresentationExceptions(tester);
  });
}
