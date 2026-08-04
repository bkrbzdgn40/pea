import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/camera_focus_stabilizer.dart';

void main() {
  testWidgets('locks focus after the requested settle duration', (
    tester,
  ) async {
    final controller = _FakeCameraController();
    final stabilizer = CameraFocusStabilizer();

    final operation = stabilizer.lockForAnalysis(
      controller,
      settleDuration: const Duration(milliseconds: 900),
    );
    await tester.pump(const Duration(milliseconds: 899));

    expect(controller.focusModeCalls, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(await operation, isTrue);
    expect(controller.focusModeCalls, <FocusMode>[FocusMode.locked]);
    expect(controller.value.focusMode, FocusMode.locked);
  });

  test(
    'deduplicates repeated requests for the same controller and mode',
    () async {
      final controller = _FakeCameraController();
      final stabilizer = CameraFocusStabilizer();

      final first = stabilizer.lockForAnalysis(controller);
      final second = stabilizer.lockForAnalysis(controller);

      expect(identical(first, second), isTrue);
      expect(await first, isTrue);
      expect(controller.focusModeCalls, <FocusMode>[FocusMode.locked]);
    },
  );

  testWidgets('a newer autofocus request cancels a pending lock', (
    tester,
  ) async {
    final controller = _FakeCameraController();
    final stabilizer = CameraFocusStabilizer();

    final pendingLock = stabilizer.lockForAnalysis(
      controller,
      settleDuration: const Duration(milliseconds: 900),
    );
    await tester.pump();

    final autofocus = stabilizer.useAuto(controller);
    await tester.pump();

    expect(await pendingLock, isFalse);
    expect(await autofocus, isTrue);
    expect(controller.focusModeCalls, isEmpty);
    expect(controller.value.focusMode, FocusMode.auto);
  });

  testWidgets('dispose cancels the pending settle timer', (tester) async {
    final controller = _FakeCameraController();
    final stabilizer = CameraFocusStabilizer();

    final pendingLock = stabilizer.lockForAnalysis(
      controller,
      settleDuration: const Duration(milliseconds: 900),
    );
    await tester.pump();

    stabilizer.dispose();
    await tester.pump();

    expect(await pendingLock, isFalse);
    expect(controller.focusModeCalls, isEmpty);
  });

  test('unsupported focus controls do not fail camera ownership', () async {
    final controller = _FakeCameraController(throwOnSet: true);
    final stabilizer = CameraFocusStabilizer();

    expect(await stabilizer.lockForAnalysis(controller), isFalse);
    expect(controller.focusModeCalls, <FocusMode>[FocusMode.locked]);
    expect(controller.value.focusMode, FocusMode.auto);
  });
}

class _FakeCameraController extends CameraController {
  _FakeCameraController({this.throwOnSet = false})
    : super(
        const CameraDescription(
          name: 'fake-camera',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 0,
        ),
        ResolutionPreset.low,
        enableAudio: false,
      ) {
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(320, 240),
      focusMode: FocusMode.auto,
    );
  }

  final bool throwOnSet;
  final List<FocusMode> focusModeCalls = <FocusMode>[];

  @override
  Widget buildPreview() => const SizedBox.expand();

  @override
  Future<void> setFocusMode(FocusMode mode) async {
    focusModeCalls.add(mode);
    if (throwOnSet) {
      throw CameraException('focusUnsupported', 'Focus is not supported.');
    }
    value = value.copyWith(focusMode: mode);
  }
}
