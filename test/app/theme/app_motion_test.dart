import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/app/theme/app_motion.dart';

void main() {
  testWidgets('keeps requested motion when accessibility does not reduce it', (
    WidgetTester tester,
  ) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(AppMotion.prefersReducedMotion(capturedContext), isFalse);
    expect(
      AppMotion.resolveDuration(capturedContext, AppMotionDurations.emphasized),
      AppMotionDurations.emphasized,
    );
    expect(
      AppMotion.resolveCurve(capturedContext, AppMotionCurves.standard),
      AppMotionCurves.standard,
    );
  });

  testWidgets('removes decorative motion when animations are disabled', (
    WidgetTester tester,
  ) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(AppMotion.prefersReducedMotion(capturedContext), isTrue);
    expect(
      AppMotion.resolveDuration(capturedContext, AppMotionDurations.emphasized),
      Duration.zero,
    );
    expect(
      AppMotion.resolveCurve(capturedContext, AppMotionCurves.standard),
      Curves.linear,
    );
  });

  testWidgets('treats accessible navigation as reduced motion', (
    WidgetTester tester,
  ) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(accessibleNavigation: true),
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(AppMotion.prefersReducedMotion(capturedContext), isTrue);
  });
}
