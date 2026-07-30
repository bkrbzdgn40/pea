import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/workout_rest_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('returns automatically when the rest timer finishes', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(tester, home: const _WorkoutRestHost());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('open-rest-screen')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Dinlenme'), findsOneWidget);
    expect(find.text('Sırada: Squat • Set 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('planned-rest-countdown')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('completed'), findsOneWidget);
    expect(find.text('Dinlenme'), findsNothing);
  });

  testWidgets('stays usable in a compact landscape viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpTestApp(
      tester,
      home: const WorkoutRestScreen(
        duration: Duration(seconds: 30),
        planName: 'Ev Planı',
        nextExerciseName: 'Standing Knee Raise',
        nextSetNumber: 2,
        tickDuration: Duration(minutes: 1),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('skip-planned-rest')),
      findsOneWidget,
    );
  });

  testWidgets('skip rest returns immediately', (WidgetTester tester) async {
    await pumpTestApp(tester, home: const _WorkoutRestHost());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('open-rest-screen')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey<String>('skip-planned-rest')));
    await tester.pumpAndSettle();

    expect(find.text('skipped'), findsOneWidget);
  });
}

class _WorkoutRestHost extends StatefulWidget {
  const _WorkoutRestHost();

  @override
  State<_WorkoutRestHost> createState() => _WorkoutRestHostState();
}

class _WorkoutRestHostState extends State<_WorkoutRestHost> {
  WorkoutRestResult? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              key: const ValueKey<String>('open-rest-screen'),
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<WorkoutRestResult>(
                      MaterialPageRoute(
                        builder: (_) => const WorkoutRestScreen(
                          duration: Duration(seconds: 2),
                          planName: 'Ev Planı',
                          nextExerciseName: 'Squat',
                          nextSetNumber: 2,
                          tickDuration: Duration(seconds: 1),
                        ),
                      ),
                    );
                if (mounted) {
                  setState(() => _result = result);
                }
              },
              child: const Text('Dinlenmeyi aç'),
            ),
            if (_result != null) Text(_result!.name),
          ],
        ),
      ),
    );
  }
}
