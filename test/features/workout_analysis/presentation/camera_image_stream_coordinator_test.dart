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

  test('drops frames while the current handler is still in flight', () async {
    final controller = _FakeCameraController();
    final coordinator = CameraImageStreamCoordinator();
    final firstFrameGate = Completer<void>();
    var handledFrameCount = 0;
    addTearDown(() async {
      if (!firstFrameGate.isCompleted) {
        firstFrameGate.complete();
      }
      await coordinator.dispose();
      await controller.dispose();
    });

    coordinator.ensureStarted(
      controller: controller,
      shouldStart: () => true,
      onFrame: (_, _) async {
        handledFrameCount += 1;
        if (handledFrameCount == 1) {
          await firstFrameGate.future;
        }
      },
    );
    await coordinator.waitForIdle();

    controller.emitFrame();
    controller.emitFrame();
    controller.emitFrame();
    await Future<void>.delayed(Duration.zero);

    expect(handledFrameCount, 1);
    expect(coordinator.hasInFlightFrame, isTrue);

    firstFrameGate.complete();
    await coordinator.waitForIdle();
    controller.emitFrame();
    await coordinator.waitForIdle();

    expect(handledFrameCount, 2);
  });

  test(
    'applies the callback interval before invoking the frame handler',
    () async {
      final controller = _FakeCameraController();
      final coordinator = CameraImageStreamCoordinator();
      var handledFrameCount = 0;
      addTearDown(() async {
        await coordinator.dispose();
        await controller.dispose();
      });

      coordinator.ensureStarted(
        controller: controller,
        shouldStart: () => true,
        minimumFrameInterval: () => const Duration(seconds: 1),
        onFrame: (_, _) {
          handledFrameCount += 1;
        },
      );
      await coordinator.waitForIdle();

      controller.emitFrame();
      await coordinator.waitForIdle();
      controller.emitFrame();
      await coordinator.waitForIdle();

      expect(handledFrameCount, 1);
    },
  );

  test('stop rejects new callbacks and drains the in-flight handler', () async {
    final controller = _FakeCameraController();
    final coordinator = CameraImageStreamCoordinator();
    final frameGate = Completer<void>();
    var handledFrameCount = 0;
    addTearDown(() async {
      if (!frameGate.isCompleted) {
        frameGate.complete();
      }
      await coordinator.dispose();
      await controller.dispose();
    });

    coordinator.ensureStarted(
      controller: controller,
      shouldStart: () => true,
      onFrame: (_, _) async {
        handledFrameCount += 1;
        await frameGate.future;
      },
    );
    await coordinator.waitForIdle();

    controller.emitFrame();
    await Future<void>.delayed(Duration.zero);
    final stopFuture = coordinator.stop();
    controller.emitFrame();
    await Future<void>.delayed(Duration.zero);

    expect(handledFrameCount, 1);

    frameGate.complete();
    await stopFuture;

    expect(controller.stopImageStreamCallCount, 1);
    expect(coordinator.hasInFlightFrame, isFalse);
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
  void Function(CameraImage image)? _onLatestImageAvailable;

  @override
  Widget buildPreview() => const SizedBox.expand();

  @override
  Future<void> startImageStream(
    void Function(CameraImage image) onLatestImageAvailable,
  ) async {
    startImageStreamCallCount += 1;
    _onLatestImageAvailable = onLatestImageAvailable;
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
    _onLatestImageAvailable = null;
    value = value.copyWith(isStreamingImages: false);
  }

  void emitFrame() {
    _onLatestImageAvailable?.call(_FakeCameraImage());
  }
}

class _FakeCameraImage implements CameraImage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
