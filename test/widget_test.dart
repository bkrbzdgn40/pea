import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_estimation_app/app/app.dart';
import 'package:pose_estimation_app/features/auth/presentation/providers/auth_bootstrap_provider.dart';

void main() {
  testWidgets('app opens the demo home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authBootstrapProvider.overrideWith(
            (ref) => const AuthBootstrapState.ready(
              didCreateAnonymousSession: false,
            ),
          ),
        ],
        child: const PoseAnalysisApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Workout Analysis'), findsOneWidget);
    expect(find.text('AI Coach'), findsOneWidget);
  });
}
