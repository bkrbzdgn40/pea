import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/preparation_live_analysis_route.dart';

import '../../../support/presentation_test_harness.dart';
import '../../../support/presentation_test_support.dart';

void main() {
  testWidgets('uses a short fade-only camera handoff transition', (
    tester,
  ) async {
    final route = PreparationLiveAnalysisRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );
    const child = SizedBox(key: ValueKey<String>('live-route-child'));
    late Widget transition;

    await pumpTestApp(
      tester,
      home: Builder(
        builder: (context) {
          transition = route.transitionsBuilder(
            context,
            const AlwaysStoppedAnimation<double>(0.5),
            const AlwaysStoppedAnimation<double>(0),
            child,
          );
          return transition;
        },
      ),
    );

    expect(route.transitionDuration, AppMotionDurations.fast);
    expect(route.reverseTransitionDuration, AppMotionDurations.fast);
    expect(route.opaque, isTrue);
    expect(transition, isA<FadeTransition>());
    expect((transition as FadeTransition).child, same(child));
  });

  testWidgets('removes the handoff fade for reduced motion', (tester) async {
    final route = PreparationLiveAnalysisRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );
    const child = SizedBox(key: ValueKey<String>('live-route-child'));
    late Widget transition;

    await pumpTestApp(
      tester,
      home: Builder(
        builder: (context) {
          transition = route.transitionsBuilder(
            context,
            const AlwaysStoppedAnimation<double>(0.5),
            const AlwaysStoppedAnimation<double>(0),
            child,
          );
          return transition;
        },
      ),
      configuration: const PresentationTestConfiguration(
        disableAnimations: true,
      ),
    );

    expect(transition, same(child));
    expect(
      find.byKey(const ValueKey<String>('live-route-child')),
      findsOneWidget,
    );
  });
}
