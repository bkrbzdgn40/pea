import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_ui_primitives.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';

import '../../../support/presentation_test_harness.dart';
import '../../../support/presentation_test_support.dart';

void main() {
  testWidgetsAcrossPresentationMatrix(
    'core primitives render without overflow',
    PresentationTestMatrix.critical,
    (tester, configuration) async {
      await pumpTestApp(
        tester,
        configuration: configuration,
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSection(
                    title: 'Canli antrenman ozeti',
                    description:
                        'Olcumler yalnizca mevcut egzersiz ve oturum icin gosterilir.',
                    child: const AppMetricTile(
                      label: 'Hareket kalitesi',
                      value: '%89',
                      supportingText:
                          'Olcum guveni uygun, tempo dengeli ve hareket araligi yeterli.',
                      icon: Icons.monitor_heart_outlined,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const AppFeedbackBanner(
                    title: 'Kadraj ayari gerekiyor',
                    message:
                        'Vucudunun tamami gorunecek sekilde kameradan biraz uzaklas.',
                    tone: AppStatusTone.caution,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      AppStatusChip(
                        label: 'Analiz hazir',
                        tone: AppStatusTone.success,
                      ),
                      AppStatusChip(
                        label: 'Dusuk guven',
                        tone: AppStatusTone.caution,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    key: const ValueKey('visual-contract-primary-button'),
                    label: 'Antrenmana Devam Et',
                    icon: Icons.arrow_forward_rounded,
                    expand: true,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('visual-contract-primary-button')),
            )
            .height,
        greaterThanOrEqualTo(AppTouchTargets.minimum),
      );
      expectNoPresentationExceptions(tester);
    },
  );

  testWidgets('surface primitive keeps its semantic visual contract', (
    WidgetTester tester,
  ) async {
    const surfaceKey = ValueKey('visual-contract-surface');

    await pumpTestApp(
      tester,
      home: const Scaffold(
        body: Center(
          child: SizedBox(
            width: 280,
            child: AppSurfaceCard(
              key: surfaceKey,
              child: Text('Surface contract'),
            ),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byKey(surfaceKey),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    final radius = decoration.borderRadius! as BorderRadius;

    expect(decoration.color, AppColors.primarySurface);
    expect(border.top.color, AppColors.surfaceBorder);
    expect(radius.topLeft.x, AppRadii.surface);
    expect(radius.topLeft.y, AppRadii.surface);
    expectNoPresentationExceptions(tester);
  });
}
