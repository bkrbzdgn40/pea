import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/workout_rest_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('waits for user confirmation when the rest timer finishes', (
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
    await tester.pump();

    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('Hazırsın'), findsOneWidget);
    expect(find.text('Dinlenme'), findsNothing);
    expect(find.text('completed'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('complete-planned-rest')),
    );
    await tester.pumpAndSettle();

    expect(find.text('completed'), findsOneWidget);
  });

  testWidgets('uses a split layout in a compact landscape viewport', (
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
      find.byKey(const ValueKey<String>('planned-rest-split-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('complete-planned-rest')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('add-planned-rest-time')),
      findsOneWidget,
    );
  });

  testWidgets('keeps large text usable in compact landscape', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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

    expect(
      find.byKey(const ValueKey<String>('planned-rest-stacked-layout')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('adds fifteen seconds without leaving the rest screen', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(tester, home: const _WorkoutRestHost());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('open-rest-screen')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('0:02'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('add-planned-rest-time')),
    );
    await tester.pump();

    expect(find.text('0:17'), findsOneWidget);
    expect(find.text('completed'), findsNothing);
  });

  testWidgets('ready action returns immediately', (WidgetTester tester) async {
    await pumpTestApp(tester, home: const _WorkoutRestHost());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('open-rest-screen')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(
      find.byKey(const ValueKey<String>('complete-planned-rest')),
    );
    await tester.pumpAndSettle();

    expect(find.text('completed'), findsOneWidget);
  });

  testWidgets('Android back returns skipped', (WidgetTester tester) async {
    await pumpTestApp(tester, home: const _WorkoutRestHost());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('open-rest-screen')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.binding.handlePopRoute();
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
          children: <Widget>[
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
