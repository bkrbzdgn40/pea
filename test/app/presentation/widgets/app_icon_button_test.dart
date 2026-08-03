import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_icon_button.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/app/theme/app_theme.dart';

void main() {
  testWidgets('requires a visible tooltip contract and minimum touch target', (
    WidgetTester tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AppIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Kapat',
            onPressed: () => tapCount += 1,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Kapat'), findsOneWidget);
    expect(
      tester.getSize(find.byType(IconButton)),
      const Size.square(AppTouchTargets.minimum),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('danger variant remains disabled when callback is absent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: AppIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Sil',
            variant: AppIconButtonVariant.danger,
            onPressed: null,
          ),
        ),
      ),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
  });
}
