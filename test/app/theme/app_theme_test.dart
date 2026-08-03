import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/app.dart';
import 'package:pose_estimation_app/app/navigation/app_page_transitions.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/app/theme/app_semantic_colors.dart';
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
    expect(theme.colorScheme.surface, AppColors.primarySurface);
    expect(theme.colorScheme.error, AppColors.danger);
  });

  test('registers semantic colors as a ThemeExtension', () {
    final semanticColors = AppTheme.dark.extension<AppSemanticColors>();

    expect(semanticColors, isNotNull);
    expect(semanticColors!.canvas, AppColors.scaffoldBackground);
    expect(semanticColors.surface, AppColors.primarySurface);
    expect(semanticColors.accent, AppColors.accent);
    expect(semanticColors.analysisAccent, AppColors.analysisAccent);
    expect(semanticColors.success, AppColors.success);
    expect(semanticColors.caution, AppColors.caution);
    expect(semanticColors.invalid, AppColors.invalid);
    expect(semanticColors.danger, AppColors.danger);
  });

  test('provides typography and component theme contracts', () {
    final theme = AppTheme.dark;

    expect(theme.textTheme.displayLarge?.color, AppColors.primaryForeground);
    expect(theme.textTheme.headlineMedium?.color, AppColors.primaryForeground);
    expect(theme.textTheme.titleMedium?.color, AppColors.primaryForeground);
    expect(theme.textTheme.bodyMedium?.color, AppColors.secondaryForeground);
    expect(theme.textTheme.labelLarge?.color, AppColors.primaryForeground);

    expect(theme.cardTheme.color, AppColors.primarySurface);
    expect(theme.dialogTheme.backgroundColor, AppColors.strongSurface);
    expect(theme.bottomSheetTheme.backgroundColor, AppColors.strongSurface);
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(theme.drawerTheme.width, 304);
    expect(theme.bottomSheetTheme.showDragHandle, isTrue);
    expect(
      theme.pageTransitionsTheme.builders.values,
      everyElement(isA<AppPageTransitionsBuilder>()),
    );
    expect(theme.inputDecorationTheme.filled, isTrue);
    expect(theme.progressIndicatorTheme.color, AppColors.accent);
    expect(theme.elevatedButtonTheme.style, isNotNull);
    expect(theme.filledButtonTheme.style, isNotNull);
    expect(theme.outlinedButtonTheme.style, isNotNull);
    expect(theme.textButtonTheme.style, isNotNull);
  });
}
