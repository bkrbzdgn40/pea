import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/camera_image_stream_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'claims an existing stream once and coalesces duplicate starts',
    () async {
      final controller = _FakeCameraController(isStreamingImages: true);
      final coordinator = CameraImageStreamCoordinator();
      addTearDown(() async {
        await coordinator.dispose();
        await controller.dispose();
      });

      void onFrame(CameraImage _, CameraController _) {}

      coordinator.ensureStarted(
        controller: controller,
        shouldStart: () => true,
        onFrame: onFrame,
      );
      coordinator.ensureStarted(
        controller: controller,
        shouldStart: () => true,
        onFrame: onFrame,
      );
      await coordinator.waitForIdle();

      expect(controller.stopImageStreamCallCount, 1);
      expect(controller.startImageStreamCallCount, 1);
      expect(coordinator.ownedController, same(controller));
      expect(coordinator.ownsImageStream, isTrue);
    },
  );

  test('transfers ownership between camera controllers serially', () async {
    final first = _FakeCameraController();
    final second = _FakeCameraController();
    final coordinator = CameraImageStreamCoordinator();
    addTearDown(() async {
      await coordinator.dispose();
      await first.dispose();
      await second.dispose();
    });

    coordinator.ensureStarted(
      controller: first,
      shouldStart: () => true,
      onFrame: (_, _) {},
    );
    await coordinator.waitForIdle();

    coordinator.ensureStarted(
      controller: second,
      shouldStart: () => true,
      onFrame: (_, _) {},
    );
    await coordinator.waitForIdle();

    expect(first.startImageStreamCallCount, 1);
    expect(first.stopImageStreamCallCount, 1);
    expect(second.startImageStreamCallCount, 1);
    expect(second.stopImageStreamCallCount, 0);
    expect(coordinator.ownedController, same(second));
  });

  test('a newer request can cancel a queued controller transfer', () async {
    final first = _FakeCameraController();
    final second = _FakeCameraController();
    final coordinator = CameraImageStreamCoordinator();
    addTearDown(() async {
      await coordinator.dispose();
      await first.dispose();
      await second.dispose();
    });

    coordinator.ensureStarted(
      controller: first,
      shouldStart: () => true,
      onFrame: (_, _) {},
    );
    await coordinator.waitForIdle();

    coordinator.ensureStarted(
      controller: second,
      shouldStart: () => true,
      onFrame: (_, _) {},
    );
    coordinator.ensureStarted(
      controller: first,
      shouldStart: () => true,
      onFrame: (_, _) {},
    );
    await coordinator.waitForIdle();

    expect(first.startImageStreamCallCount, 1);
    expect(first.stopImageStreamCallCount, 0);
    expect(second.startImageStreamCallCount, 0);
    expect(coordinator.ownedController, same(first));
  });

  test('stop during a pending start does not leave an orphan stream', () async {
    final startGate = Completer<void>();
    final controller = _FakeCameraController(startGate: startGate);
    final coordinator = CameraImageStreamCoordinator();
    addTearDown(() async {
      await coordinator.dispose();
      await controller.dispose();
    });

    coordinator.ensureStarted(
      controller: controller,
      shouldStart: () => true,
      onFrame: (_, _) {},
    );
    await controller.startEntered.future;

    final stopFuture = coordinator.stop();
    startGate.complete();
    await stopFuture;

    expect(controller.startImageStreamCallCount, 1);
    expect(controller.stopImageStreamCallCount, 1);
    expect(controller.value.isStreamingImages, isFalse);
    expect(coordinator.ownedController, isNull);
    expect(coordinator.ownsImageStream, isFalse);
  });
}

class _FakeCameraController extends CameraController {
  _FakeCameraController({bool isStreamingImages = false, this.startGate})
    : super(
        const CameraDescription(
          name: 'fake-camera',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 0,
        ),
        ResolutionPreset.medium,
        enableAudio: false,
      ) {
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(640, 480),
      isStreamingImages: isStreamingImages,
    );
  }

  final Completer<void>? startGate;
  final Completer<void> startEntered = Completer<void>();
  int startImageStreamCallCount = 0;
  int stopImageStreamCallCount = 0;

  @override
  Widget buildPreview() => const SizedBox.expand();

  @override
  Future<void> startImageStream(
    void Function(CameraImage image) onLatestImageAvailable,
  ) async {
    startImageStreamCallCount += 1;
    if (!startEntered.isCompleted) {
      startEntered.complete();
    }
    final gate = startGate;
    if (gate != null) {
      await gate.future;
    }
    value = value.copyWith(isStreamingImages: true);
  }

  @override
  Future<void> stopImageStream() async {
    stopImageStreamCallCount += 1;
    value = value.copyWith(isStreamingImages: false);
  }
}
