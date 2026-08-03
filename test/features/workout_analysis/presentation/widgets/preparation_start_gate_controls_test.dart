import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/preparation_start_gate_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/preparation_start_gate_controls.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('explains the active readiness monitoring state', (tester) async {
    var cancelCount = 0;

    await pumpTestApp(
      tester,
      locale: const Locale('en'),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PreparationStartGateControls(
            phase: PreparationStartGatePhase.monitoring,
            countdownValue: null,
            isConfigReady: true,
            isCameraReady: true,
            isPreparing: false,
            compact: true,
            onArm: null,
            onCancel: () => cancelCount += 1,
            onOverride: null,
          ),
        ),
      ),
    );

    expect(find.text('Preparation check active'), findsOneWidget);
    expect(
      find.text(
        'Move into the frame. Analysis will start automatically when you are ready.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('preparation-cancel-gate')),
    );
    expect(cancelCount, 1);
  });

  testWidgets('countdown controls survive compact large-text layouts', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      locale: const Locale('en'),
      configuration: const PresentationTestConfiguration(
        viewport: PresentationTestViewport.compactPortrait,
        textScaleFactor: 2,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PreparationStartGateControls(
            phase: PreparationStartGatePhase.countingDown,
            countdownValue: 3,
            isConfigReady: true,
            isCameraReady: true,
            isPreparing: false,
            compact: true,
            onArm: null,
            onCancel: _noop,
            onOverride: null,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('preparation-countdown-controls')),
      findsOneWidget,
    );
    expect(find.text('3'), findsOneWidget);
    expectNoPresentationExceptions(tester);
  });
}

void _noop() {}
