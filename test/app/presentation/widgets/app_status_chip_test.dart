import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_status_chip.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_status_tone.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/app/theme/app_theme.dart';

void main() {
  testWidgets(
    'uses icon and text so status is not communicated by color alone',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Center(
              child: AppStatusChip(label: 'Hazir', tone: AppStatusTone.success),
            ),
          ),
        ),
      );

      expect(find.text('Hazir'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      final border = decoration.border! as Border;

      expect(
        decoration.color,
        AppColors.success.withValues(alpha: AppOpacity.subtle),
      );
      expect(
        border.top.color,
        AppColors.success.withValues(alpha: AppOpacity.strongBorder),
      );
    },
  );

  testWidgets('allows a deliberately text-only neutral chip', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: AppStatusChip(label: 'Bekliyor', showIcon: false),
        ),
      ),
    );

    expect(find.text('Bekliyor'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });
}
