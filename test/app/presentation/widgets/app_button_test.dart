import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_button.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/app/theme/app_theme.dart';

void main() {
  testWidgets(
    'primary button keeps a minimum touch target and invokes action',
    (WidgetTester tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: AppButton(
                label: 'Devam Et',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => tapCount += 1,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(AppTouchTargets.minimum),
      );

      await tester.tap(find.text('Devam Et'));
      await tester.pump();

      expect(tapCount, 1);
    },
  );

  testWidgets('loading button exposes progress and blocks duplicate actions', (
    WidgetTester tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AppButton(
            label: 'Kaydediliyor',
            isLoading: true,
            onPressed: () => tapCount += 1,
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.text('Kaydediliyor'));
    await tester.pump();

    expect(tapCount, 0);
  });

  testWidgets('maps variants to intentional Material button families', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Column(
            children: [
              AppButton(label: 'Primary', onPressed: () {}),
              AppButton(
                label: 'Secondary',
                variant: AppButtonVariant.secondary,
                onPressed: () {},
              ),
              AppButton(
                label: 'Outline',
                variant: AppButtonVariant.outline,
                onPressed: () {},
              ),
              AppButton(
                label: 'Ghost',
                variant: AppButtonVariant.ghost,
                onPressed: () {},
              ),
              AppButton(
                label: 'Danger',
                variant: AppButtonVariant.danger,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(FilledButton), findsNWidgets(3));
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
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
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppButton(
              label: 'Antrenmana guvenli bicimde devam et',
              icon: Icons.arrow_forward_rounded,
              expand: true,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Antrenmana guvenli bicimde devam et'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
