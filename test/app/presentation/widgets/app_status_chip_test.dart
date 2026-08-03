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

  testWidgets('truncates long labels without overflowing narrow layouts', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: AppStatusChip(
              label: 'Analiz sonucu guvenle hazir ve kullanilabilir',
              tone: AppStatusTone.success,
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('Analiz sonucu guvenle hazir ve kullanilabilir'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
