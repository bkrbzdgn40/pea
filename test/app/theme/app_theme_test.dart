import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/app.dart';
import 'package:pose_estimation_app/app/theme/app_theme.dart';
import 'package:pose_estimation_app/features/auth/presentation/providers/auth_bootstrap_provider.dart';

void main() {
  testWidgets('PoseAnalysisApp uses the shared dark AppTheme contract', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authBootstrapProvider.overrideWith(
            (ref) => const AuthBootstrapState.error(
              'Kullanici oturumu hazirlanamadi.',
            ),
          ),
        ],
        child: const PoseAnalysisApp(),
      ),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final theme = app.theme!;

    expect(theme, same(AppTheme.dark));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, Colors.black);
    expect(theme.appBarTheme.backgroundColor, Colors.black);
    expect(theme.appBarTheme.foregroundColor, Colors.white);
    expect(theme.colorScheme.primary, Colors.greenAccent);
  });
}
