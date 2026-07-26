import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/preparation_live_camera_handoff_coordinator.dart';

void main() {
  test('runs release, live analysis, and reclaim in ownership order', () async {
    final coordinator = PreparationLiveCameraHandoffCoordinator();
    addTearDown(coordinator.dispose);
    final events = <String>[];
    final phases = <PreparationLiveCameraHandoffPhase>[];
    coordinator.addListener(() => phases.add(coordinator.phase));

    await coordinator.run(
      releasePreparation: () async {
        events.add('release');
        expect(
          coordinator.phase,
          PreparationLiveCameraHandoffPhase.releasingPreparation,
        );
      },
      runLiveAnalysis: () async {
        events.add('live');
        expect(
          coordinator.phase,
          PreparationLiveCameraHandoffPhase.liveAnalysis,
        );
      },
      reclaimPreparation: () async {
        events.add('reclaim');
        expect(
          coordinator.phase,
          PreparationLiveCameraHandoffPhase.reclaimingPreparation,
        );
      },
    );

    expect(events, <String>['release', 'live', 'reclaim']);
    expect(phases, <PreparationLiveCameraHandoffPhase>[
      PreparationLiveCameraHandoffPhase.releasingPreparation,
      PreparationLiveCameraHandoffPhase.liveAnalysis,
      PreparationLiveCameraHandoffPhase.reclaimingPreparation,
      PreparationLiveCameraHandoffPhase.preparation,
    ]);
    expect(coordinator.phase, PreparationLiveCameraHandoffPhase.preparation);
    expect(coordinator.canUsePreparationCamera, isTrue);
    expect(coordinator.isHandoffInProgress, isFalse);
  });

  test('coalesces repeated start requests into one active handoff', () async {
    final coordinator = PreparationLiveCameraHandoffCoordinator();
    addTearDown(coordinator.dispose);
    final releaseGate = Completer<void>();
    var releaseCount = 0;
    var liveCount = 0;
    var reclaimCount = 0;

    Future<void> runHandoff() {
      return coordinator.run(
        releasePreparation: () async {
          releaseCount += 1;
          await releaseGate.future;
        },
        runLiveAnalysis: () async {
          liveCount += 1;
        },
        reclaimPreparation: () async {
          reclaimCount += 1;
        },
      );
    }

    final first = runHandoff();
    final second = runHandoff();

    expect(second, same(first));
    expect(coordinator.isHandoffInProgress, isTrue);
    releaseGate.complete();
    await Future.wait<void>(<Future<void>>[first, second]);

    expect(releaseCount, 1);
    expect(liveCount, 1);
    expect(reclaimCount, 1);
  });

  test('reclaims preparation ownership when the live route fails', () async {
    final coordinator = PreparationLiveCameraHandoffCoordinator();
    addTearDown(coordinator.dispose);
    var reclaimed = false;

    await expectLater(
      coordinator.run(
        releasePreparation: () async {},
        runLiveAnalysis: () async => throw StateError('route failed'),
        reclaimPreparation: () async {
          reclaimed = true;
        },
      ),
      throwsStateError,
    );

    expect(reclaimed, isTrue);
    expect(coordinator.phase, PreparationLiveCameraHandoffPhase.preparation);
    expect(coordinator.canUsePreparationCamera, isTrue);
  });

  test('does not reclaim camera ownership after disposal', () async {
    final coordinator = PreparationLiveCameraHandoffCoordinator();
    final liveGate = Completer<void>();
    var reclaimCount = 0;

    final handoff = coordinator.run(
      releasePreparation: () async {},
      runLiveAnalysis: () async => liveGate.future,
      reclaimPreparation: () async {
        reclaimCount += 1;
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.phase, PreparationLiveCameraHandoffPhase.liveAnalysis);

    coordinator.dispose();
    liveGate.complete();
    await handoff;

    expect(reclaimCount, 0);
    expect(coordinator.phase, PreparationLiveCameraHandoffPhase.disposed);
  });
}
