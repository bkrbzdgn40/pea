import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/screen_awake_controller.dart';

void main() {
  test('keeps wakelock enabled while any camera workflow owns it', () async {
    final toggles = <bool>[];
    final controller = ScreenAwakeController(
      toggle: (enable) async => toggles.add(enable),
    );

    await controller.acquire(ScreenAwakeOwner.preparation);
    await controller.acquire(ScreenAwakeOwner.liveAnalysis);
    await controller.release(ScreenAwakeOwner.preparation);

    expect(controller.owners, <ScreenAwakeOwner>{
      ScreenAwakeOwner.liveAnalysis,
    });
    expect(toggles, <bool>[true]);

    await controller.release(ScreenAwakeOwner.liveAnalysis);

    expect(controller.owners, isEmpty);
    expect(toggles, <bool>[true, false]);
  });

  test('coalesces rapid preparation-to-live ownership transitions', () async {
    final toggles = <bool>[];
    final controller = ScreenAwakeController(
      toggle: (enable) async => toggles.add(enable),
    );

    final acquirePreparation = controller.acquire(ScreenAwakeOwner.preparation);
    final acquireLive = controller.acquire(ScreenAwakeOwner.liveAnalysis);
    final releasePreparation = controller.release(ScreenAwakeOwner.preparation);
    await Future.wait(<Future<void>>[
      acquirePreparation,
      acquireLive,
      releasePreparation,
    ]);

    expect(controller.owners, <ScreenAwakeOwner>{
      ScreenAwakeOwner.liveAnalysis,
    });
    expect(toggles, <bool>[true]);

    final acquirePreparationAgain = controller.acquire(
      ScreenAwakeOwner.preparation,
    );
    final releaseLive = controller.release(ScreenAwakeOwner.liveAnalysis);
    await Future.wait(<Future<void>>[acquirePreparationAgain, releaseLive]);

    expect(controller.owners, <ScreenAwakeOwner>{ScreenAwakeOwner.preparation});
    expect(toggles, <bool>[true]);

    await controller.release(ScreenAwakeOwner.preparation);
    expect(toggles, <bool>[true, false]);
  });

  test('platform failures do not break later ownership transitions', () async {
    final toggles = <bool>[];
    var shouldFail = true;
    final controller = ScreenAwakeController(
      toggle: (enable) async {
        toggles.add(enable);
        if (shouldFail) {
          shouldFail = false;
          throw StateError('wakelock unavailable');
        }
      },
    );

    await controller.acquire(ScreenAwakeOwner.preparation);
    await controller.acquire(ScreenAwakeOwner.liveAnalysis);

    expect(controller.isRequested, isTrue);
    expect(toggles, <bool>[true, true]);

    await controller.release(ScreenAwakeOwner.preparation);
    await controller.release(ScreenAwakeOwner.liveAnalysis);

    expect(toggles, <bool>[true, true, false]);
  });

  test('dispose releases an active wakelock request', () async {
    final toggles = <bool>[];
    final controller = ScreenAwakeController(
      toggle: (enable) async => toggles.add(enable),
    );

    await controller.acquire(ScreenAwakeOwner.preparation);
    await controller.dispose();

    expect(controller.owners, isEmpty);
    expect(toggles, <bool>[true, false]);
  });
}
