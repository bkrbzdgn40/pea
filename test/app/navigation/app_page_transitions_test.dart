import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/navigation/app_page_transitions.dart';
import 'package:pose_estimation_app/app/theme/app_theme.dart';

import '../../support/presentation_test_harness.dart';
import '../../support/presentation_test_support.dart';

void main() {
  test('AppTheme registers the shared transition on every platform', () {
    final builders = AppTheme.dark.pageTransitionsTheme.builders;

    for (final platform in TargetPlatform.values) {
      expect(builders[platform], isA<AppPageTransitionsBuilder>());
    }

    final iosBuilder =
        builders[TargetPlatform.iOS]! as AppPageTransitionsBuilder;
    expect(iosBuilder.preserveCupertinoGesture, isTrue);
  });

  testWidgets('uses fade and slide for standard navigation', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const _TransitionHarness(),
      configuration: const PresentationTestConfiguration(),
    );

    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(SlideTransition), findsWidgets);
  });

  testWidgets('removes decorative transition for reduced motion', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const _TransitionHarness(),
      configuration: const PresentationTestConfiguration(
        disableAnimations: true,
      ),
    );

    expect(find.byType(FadeTransition), findsNothing);
    expect(find.byType(SlideTransition), findsNothing);
    expect(find.byKey(const Key('transition-child')), findsOneWidget);
  });
}

class _TransitionHarness extends StatelessWidget {
  const _TransitionHarness();

  @override
  Widget build(BuildContext context) {
    final route = MaterialPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );

    return Scaffold(
      body: const AppPageTransitionsBuilder().buildTransitions<void>(
        route,
        context,
        const AlwaysStoppedAnimation<double>(0.5),
        const AlwaysStoppedAnimation<double>(0),
        const SizedBox(key: Key('transition-child')),
      ),
    );
  }
}
