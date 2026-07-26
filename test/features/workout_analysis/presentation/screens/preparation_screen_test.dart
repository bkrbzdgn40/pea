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
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/screen_awake_controller.dart';
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

  testWidgets('keeps preparation awake only while foreground and visible', (
    tester,
  ) async {
    final cameraController = _FakeCameraController();
    addTearDown(cameraController.dispose);
    final toggles = <bool>[];
    final awakeController = ScreenAwakeController(
      toggle: (enable) async => toggles.add(enable),
    );

    await _pumpSelectedExercise(
      tester,
      cameraController: cameraController,
      awakeController: awakeController,
    );

    expect(toggles, <bool>[true]);

    final lifecycleObserver =
        tester.state(find.byType(PreparationScreen)) as WidgetsBindingObserver;
    lifecycleObserver.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();

    expect(toggles, <bool>[true, false]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(toggles, <bool>[true, false]);
  });

  testWidgets('does not request wakelock without an analysis selection', (
    tester,
  ) async {
    final toggles = <bool>[];
    final awakeController = ScreenAwakeController(
      toggle: (enable) async => toggles.add(enable),
    );
    await pumpTestApp(
      tester,
      home: const PreparationScreen(),
      overrides: <Override>[
        screenAwakeControllerProvider.overrideWithValue(awakeController),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(toggles, isEmpty);
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
      find.byKey(const ValueKey<String>('preparation-safe-zone')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('preparation-readiness-banner')),
      findsOneWidget,
    );
    expect(
      find.text('Kadraja geç ve vücudunu kameraya göster.'),
      findsOneWidget,
    );
    final readinessCard = find.byKey(
      const ValueKey<String>('preparation-readiness-card'),
    );
    await tester.scrollUntilVisible(
      readinessCard,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(readinessCard, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('preparation-check-person')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('preparation-check-framing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('preparation-check-cameraView')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('preparation-check-startPose')),
      findsOneWidget,
    );
    final readinessStatus = tester.widget<Text>(
      find.byKey(const ValueKey<String>('preparation-readiness-status')),
    );
    expect(readinessStatus.data, 'Konumunu ayarla');
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
    expect(find.text('Hazırlığı Başlat'), findsOneWidget);
    final startButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('preparation-start-gate')),
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
    expect(find.text('Hazırlığı Başlat'), findsOneWidget);
    final startButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('preparation-start-gate')),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('arms preparation without opening live analysis', (tester) async {
    final cameraController = _FakeCameraController();
    addTearDown(cameraController.dispose);

    await pumpTestApp(
      tester,
      home: PreparationScreen(
        analysisScreenBuilder: (_) => const _PassiveAnalysisScreen(),
      ),
      overrides: <Override>[
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
        exerciseConfigProvider.overrideWith((ref) => buildSquatConfig()),
        cameraProvider.overrideWith((ref) async => cameraController),
        preparationCameraControllerProvider.overrideWith(
          () => _FakePreparationCameraController(),
        ),
        screenAwakeControllerProvider.overrideWithValue(
          _buildNoopScreenAwakeController(),
        ),
      ],
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('preparation-start-gate')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('preparation-start-gate-active')),
      findsOneWidget,
    );
    expect(
      find.text('Kadraja geç. Hazır olduğunda analiz otomatik başlayacak.'),
      findsOneWidget,
    );
    expect(find.byType(_PassiveAnalysisScreen), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('preparation-start-analysis')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('preparation-cancel-gate')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('preparation-start-gate')),
      findsOneWidget,
    );
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
        screenAwakeControllerProvider.overrideWithValue(
          _buildNoopScreenAwakeController(),
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
    expect(
      find.byKey(const ValueKey<String>('preparation-readiness-card')),
      findsNothing,
    );
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
        screenAwakeControllerProvider.overrideWithValue(
          _buildNoopScreenAwakeController(),
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
    expect(
      find.byKey(const ValueKey<String>('preparation-readiness-card')),
      findsNothing,
    );
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
        screenAwakeControllerProvider.overrideWithValue(
          _buildNoopScreenAwakeController(),
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
    expect(
      find.byKey(const ValueKey<String>('preparation-readiness-card')),
      findsNothing,
    );
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
  ScreenAwakeController? awakeController,
}) async {
  final resolvedAwakeController =
      awakeController ?? _buildNoopScreenAwakeController();
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
      screenAwakeControllerProvider.overrideWithValue(resolvedAwakeController),
    ],
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

ScreenAwakeController _buildNoopScreenAwakeController() {
  return ScreenAwakeController(toggle: (_) async {});
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

class _PassiveAnalysisScreen extends StatelessWidget {
  const _PassiveAnalysisScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
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
