import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/camera_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/preparation_camera_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/preparation_live_camera_handoff_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/preparation_screen.dart';

import '../../../../support/presentation_test_support.dart';
import '../../../../support/workout_analysis_test_support.dart';

void main() {
  testWidgets('uses preparation terminology when no exercise is selected', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const PreparationScreen(),
      locale: const Locale('en'),
    );
    await tester.pump();

    expect(find.byType(PreparationScreen), findsOneWidget);
    expect(find.text('Preparation'), findsOneWidget);
    expect(find.text('Choose an exercise before preparation'), findsOneWidget);
    expect(
      find.text(
        'A valid exercise selection is required before preparation and analysis can begin.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('calibration'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('preparation-camera-preview')),
      findsNothing,
    );
  });

  testWidgets('shows live camera preview and exercise-specific guidance', (
    tester,
  ) async {
    final cameraController = _FakeCameraController();
    addTearDown(cameraController.dispose);

    await _pumpSelectedExercise(
      tester,
      cameraController: cameraController,
      locale: const Locale('tr'),
    );

    expect(find.byType(PreparationScreen), findsOneWidget);
    expect(find.text('Hazırlık'), findsOneWidget);
    expect(find.text('Squat analizi öncesi'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('preparation-camera-preview')),
      findsOneWidget,
    );
    expect(find.byType(CameraPreview), findsOneWidget);
    expect(
      find.text(
        'Kendini kadrajda kontrol et. Analiz, başlat düğmesine dokunana kadar başlamaz.',
      ),
      findsOneWidget,
    );
    final cameraViewInstruction = find.text(
      'Sağ veya sol yanını kameraya dön.',
    );
    await tester.scrollUntilVisible(
      cameraViewInstruction,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(cameraViewInstruction, findsOneWidget);
    expect(
      find.text(
        'Başın, omuzların, kalçan, dizlerin, ayak bileklerin ve ayakların kadrajda tamamen görünsün.',
      ),
      findsOneWidget,
    );
    expect(find.text('Squat analizine başla'), findsOneWidget);
    final startButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('preparation-start-analysis')),
    );
    expect(startButton.onPressed, isNotNull);
    expect(cameraController.startImageStreamCallCount, 1);
  });

  testWidgets('paints preparation landmarks without workout metrics', (
    tester,
  ) async {
    final cameraController = _FakeCameraController();
    addTearDown(cameraController.dispose);
    final landmarks = <PoseLandmark>[
      buildLandmark(PoseLandmarkType.leftShoulder, 100, 120),
      buildLandmark(PoseLandmarkType.leftHip, 110, 240),
    ];

    await _pumpSelectedExercise(
      tester,
      cameraController: cameraController,
      preparationState: PreparationCameraState(landmarks: landmarks),
    );

    expect(
      find.byKey(const ValueKey<String>('preparation-pose-overlay')),
      findsOneWidget,
    );
    expect(find.textContaining('FPS'), findsNothing);
    expect(find.textContaining('Tekrar:'), findsNothing);
    expect(find.textContaining('Süre:'), findsNothing);
    expect(find.text('Squat analizine başla'), findsOneWidget);
    final startButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('preparation-start-analysis')),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('recreates the camera after live analysis releases its stream', (
    tester,
  ) async {
    final initialController = _FakeCameraController(name: 'initial-camera');
    final resumedController = _FakeCameraController(name: 'resumed-camera');
    addTearDown(initialController.dispose);
    addTearDown(resumedController.dispose);
    var cameraRequestCount = 0;
    var analysisRouteDisposed = false;
    final cameraHandoffCoordinator = PreparationLiveCameraHandoffCoordinator();
    addTearDown(cameraHandoffCoordinator.dispose);
    final landmarks = <PoseLandmark>[
      buildLandmark(PoseLandmarkType.leftShoulder, 100, 120),
      buildLandmark(PoseLandmarkType.leftHip, 110, 240),
    ];

    await pumpTestApp(
      tester,
      home: PreparationScreen(
        cameraHandoffCoordinator: cameraHandoffCoordinator,
        analysisScreenBuilder: (_) => _ReturnFromAnalysisScreen(
          cameraController: initialController,
          onDispose: () => analysisRouteDisposed = true,
        ),
      ),
      overrides: <Override>[
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
        exerciseConfigProvider.overrideWith((ref) => buildSquatConfig()),
        cameraProvider.overrideWith((ref) async {
          cameraRequestCount += 1;
          return cameraRequestCount == 1
              ? initialController
              : resumedController;
        }),
        preparationCameraControllerProvider.overrideWith(
          () => _FakePreparationCameraController(
            PreparationCameraState(landmarks: landmarks),
          ),
        ),
      ],
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(initialController.startImageStreamCallCount, 1);
    expect(
      cameraHandoffCoordinator.phase,
      PreparationLiveCameraHandoffPhase.preparation,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('preparation-start-analysis')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('return-from-analysis')),
      findsOneWidget,
    );
    expect(initialController.stopImageStreamCallCount, 1);
    expect(initialController.startImageStreamCallCount, 2);
    expect(initialController.value.isStreamingImages, isTrue);
    expect(
      cameraHandoffCoordinator.phase,
      PreparationLiveCameraHandoffPhase.liveAnalysis,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('return-from-analysis')),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(analysisRouteDisposed, isTrue);
    expect(cameraRequestCount, 2);
    expect(initialController.stopImageStreamCallCount, 2);
    expect(resumedController.startImageStreamCallCount, 1);
    expect(resumedController.value.isStreamingImages, isTrue);
    expect(
      cameraHandoffCoordinator.phase,
      PreparationLiveCameraHandoffPhase.preparation,
    );
    expect(find.text('Squat analizine başla'), findsOneWidget);
    final startButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('preparation-start-analysis')),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('shows a stable loading surface before camera initialization', (
    tester,
  ) async {
    final cameraCompleter = Completer<CameraController>();

    await pumpTestApp(
      tester,
      home: const PreparationScreen(),
      overrides: <Override>[
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
        exerciseConfigProvider.overrideWith((ref) => buildSquatConfig()),
        cameraProvider.overrideWith((ref) => cameraCompleter.future),
        preparationCameraControllerProvider.overrideWith(
          () => _FakePreparationCameraController(),
        ),
      ],
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('preparation-camera-loading')),
      findsOneWidget,
    );
    expect(find.text('Kamera hazırlanıyor...'), findsOneWidget);
    expect(find.text('Kamera henüz hazır değil'), findsOneWidget);
  });

  testWidgets('shows camera permission recovery without starting analysis', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const PreparationScreen(),
      overrides: <Override>[
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
        exerciseConfigProvider.overrideWith((ref) => buildSquatConfig()),
        cameraProvider.overrideWith(
          (ref) async =>
              throw CameraException('cameraPermission', 'permission missing'),
        ),
        preparationCameraControllerProvider.overrideWith(
          () => _FakePreparationCameraController(),
        ),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('preparation-camera-error')),
      findsOneWidget,
    );
    expect(
      find.text('Analize devam etmek için kamera iznini kontrol et.'),
      findsOneWidget,
    );
    expect(find.text('İzni Kontrol Et'), findsOneWidget);
    expect(find.text('Kamera henüz hazır değil'), findsOneWidget);
  });

  testWidgets('shows a retry action when the camera cannot be opened', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const PreparationScreen(),
      locale: const Locale('en'),
      overrides: <Override>[
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
        exerciseConfigProvider.overrideWith((ref) => buildSquatConfig()),
        cameraProvider.overrideWith(
          (ref) async => throw StateError('camera busy'),
        ),
        preparationCameraControllerProvider.overrideWith(
          () => _FakePreparationCameraController(),
        ),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('preparation-camera-error')),
      findsOneWidget,
    );
    expect(find.textContaining('Camera could not be opened'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Camera is not ready yet'), findsOneWidget);
  });

  testWidgets('stops the preparation image stream when the app pauses', (
    tester,
  ) async {
    final cameraController = _FakeCameraController();
    addTearDown(cameraController.dispose);

    await _pumpSelectedExercise(tester, cameraController: cameraController);
    expect(cameraController.startImageStreamCallCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();

    expect(cameraController.stopImageStreamCallCount, 1);
  });
}

Future<void> _pumpSelectedExercise(
  WidgetTester tester, {
  required _FakeCameraController cameraController,
  Locale locale = const Locale('tr'),
  PreparationCameraState? preparationState,
}) async {
  await pumpTestApp(
    tester,
    home: const PreparationScreen(),
    locale: locale,
    overrides: <Override>[
      selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
      exerciseConfigProvider.overrideWith((ref) => buildSquatConfig()),
      cameraProvider.overrideWith((ref) async => cameraController),
      preparationCameraControllerProvider.overrideWith(
        () => _FakePreparationCameraController(
          preparationState ?? PreparationCameraState(),
        ),
      ),
    ],
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

class _FakePreparationCameraController extends PreparationCameraController {
  _FakePreparationCameraController([this.initialState]);

  final PreparationCameraState? initialState;

  @override
  PreparationCameraState build() => initialState ?? PreparationCameraState();

  @override
  Future<void> processCameraImage(
    CameraImage image,
    int sensorOrientation, {
    DeviceOrientation? deviceOrientation,
    CameraLensDirection? lensDirection,
    DateTime? capturedAt,
  }) async {}
}

class _ReturnFromAnalysisScreen extends StatefulWidget {
  const _ReturnFromAnalysisScreen({
    required this.cameraController,
    required this.onDispose,
  });

  final _FakeCameraController cameraController;
  final VoidCallback onDispose;

  @override
  State<_ReturnFromAnalysisScreen> createState() =>
      _ReturnFromAnalysisScreenState();
}

class _ReturnFromAnalysisScreenState extends State<_ReturnFromAnalysisScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(widget.cameraController.startImageStream((_) {}));
    });
  }

  @override
  void dispose() {
    widget.onDispose();
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 500),
      ).then((_) => widget.cameraController.stopImageStream()),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey<String>('return-from-analysis'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hazırlığa dön'),
        ),
      ),
    );
  }
}

class _FakeCameraController extends CameraController {
  _FakeCameraController({String name = 'fake-camera'})
    : super(
        CameraDescription(
          name: name,
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 0,
        ),
        ResolutionPreset.medium,
        enableAudio: false,
      ) {
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(640, 480),
      isStreamingImages: false,
    );
  }

  int startImageStreamCallCount = 0;
  int stopImageStreamCallCount = 0;

  @override
  Widget buildPreview() => const SizedBox.expand();

  @override
  Future<void> startImageStream(
    void Function(CameraImage image) onLatestImageAvailable,
  ) async {
    startImageStreamCallCount += 1;
    value = value.copyWith(isStreamingImages: true);
  }

  @override
  Future<void> stopImageStream() async {
    stopImageStreamCallCount += 1;
    value = value.copyWith(isStreamingImages: false);
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
  }
}
