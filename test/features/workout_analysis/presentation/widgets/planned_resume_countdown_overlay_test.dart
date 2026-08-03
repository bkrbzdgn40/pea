import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/live_analysis/live_analysis_side_panel.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets(
    'covers stale live data while announcing the prepared next step',
    (WidgetTester tester) async {
      await pumpTestApp(
        tester,
        home: const Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Text('94'),
              PlannedResumeCountdownOverlay(
                value: 3,
                nextExerciseName: 'Plank',
                nextSetNumber: 1,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('planned-resume-next-step')),
        findsOneWidget,
      );
      expect(find.text('Sırada: Plank • Set 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('planned-resume-countdown-3')),
        findsOneWidget,
      );

      expect(
        find.byKey(const ValueKey<String>('planned-resume-semantics-blocker')),
        findsOneWidget,
      );
      final decorated = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey<String>('planned-resume-countdown-overlay')),
      );
      final gradient =
          (decorated.decoration as BoxDecoration).gradient! as RadialGradient;
      expect(gradient.colors.every((color) => color.a == 1), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
