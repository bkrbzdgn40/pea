// ignore_for_file: depend_on_referenced_packages

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/assessment_models.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/assessment_live_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/camera_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_assessment_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/assessment_live_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('keeps result CTA disabled until assessment evidence is ready', (
    tester,
  ) async {
    final state = AssessmentLiveState(
      snapshot: const AssessmentSnapshot(
        type: AssessmentType.balance,
        phase: AssessmentPhase.active,
        sampleCount: 4,
        isReadyToComplete: false,
        readinessProgress: 0.4,
        continuousEvidenceDuration: Duration(seconds: 2),
        result: null,
      ),
      feedbackMessage: 'Seçilen ayağın üzerinde sabit kal.',
      progressMessage: 'Kesintisiz duruş: 2.0 / 5.0 sn',
    );
    final harness = await _pumpScreen(
      tester,
      selection: const AssessmentSelection(
        type: AssessmentType.balance,
        balanceSide: AssessmentSide.left,
      ),
      initialState: state,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await harness.dispose();
    });

    expect(find.text('Kesintisiz duruş: 2.0 / 5.0 sn'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Sonucu Gör'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('takes ownership when camera controller is already streaming', (
    tester,
  ) async {
    final state = AssessmentLiveState(
      snapshot: const AssessmentSnapshot(
        type: AssessmentType.squat,
        phase: AssessmentPhase.active,
        sampleCount: 0,
        isReadyToComplete: false,
        readinessProgress: 0,
        result: null,
      ),
      feedbackMessage: 'Squat yap.',
      progressMessage: 'Hareket ilerlemesi: %0',
    );
    final harness = await _pumpScreen(
      tester,
      selection: const AssessmentSelection(type: AssessmentType.squat),
      initialState: state,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await harness.dispose();
    });

    expect(harness.cameraController.stopImageStreamCallCount, 1);
    expect(harness.cameraController.startImageStreamCallCount, 1);
    expect(harness.cameraController.value.isStreamingImages, isTrue);
  });

  testWidgets('insufficient result hides partial metrics and offers retry', (
    tester,
  ) async {
    const partialResult = SquatAssessmentResult(
      sampleCount: 3,
      hasSufficientData: false,
      leftKneeFlexionDegrees: 90,
      rightKneeFlexionDegrees: 80,
      kneeFlexionAsymmetryDegrees: 10,
      deepestHipDepthRatio: -0.1,
      torsoInclinationAtDeepestDegrees: 15,
    );
    final state = AssessmentLiveState(
      snapshot: const AssessmentSnapshot(
        type: AssessmentType.squat,
        phase: AssessmentPhase.completed,
        sampleCount: 3,
        isReadyToComplete: false,
        readinessProgress: 0,
        result: partialResult,
      ),
      feedbackMessage: 'Sonuç için yeterli ölçüm toplanamadı.',
      progressMessage: 'Hareket ilerlemesi: %60',
    );
    final harness = await _pumpScreen(
      tester,
      selection: const AssessmentSelection(type: AssessmentType.squat),
      initialState: state,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await harness.dispose();
    });

    expect(find.text('Yetersiz ölçüm'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    expect(find.text('Diz fleksiyonu'), findsNothing);
    expect(find.text('Diz farkı'), findsNothing);

    await tester.tap(find.text('Tekrar Dene'));
    await tester.pump();

    expect(harness.notifier.retryCallCount, 1);
    expect(find.text('Sonucu Gör'), findsOneWidget);
  });

  testWidgets('squat result avoids side-view asymmetry claims', (tester) async {
    const result = SquatAssessmentResult(
      sampleCount: 10,
      hasSufficientData: true,
      leftKneeFlexionDegrees: 96,
      rightKneeFlexionDegrees: null,
      kneeFlexionAsymmetryDegrees: null,
      deepestHipDepthRatio: -0.1,
      torsoInclinationAtDeepestDegrees: 18,
    );
    final state = AssessmentLiveState(
      snapshot: const AssessmentSnapshot(
        type: AssessmentType.squat,
        phase: AssessmentPhase.completed,
        sampleCount: 10,
        isReadyToComplete: true,
        readinessProgress: 1,
        result: result,
      ),
      feedbackMessage: 'Değerlendirme tamamlandı.',
      progressMessage: 'Ölçüm hazır',
    );
    final harness = await _pumpScreen(
      tester,
      selection: const AssessmentSelection(type: AssessmentType.squat),
      initialState: state,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await harness.dispose();
    });

    expect(find.text('Değerlendirme sonucu'), findsOneWidget);
    expect(find.text('Diz fleksiyonu'), findsOneWidget);
    expect(find.text('96.0°'), findsOneWidget);
    expect(find.text('Diz farkı'), findsNothing);
    expect(find.text('Sol diz fleksiyonu'), findsNothing);
    expect(find.text('Sağ diz fleksiyonu'), findsNothing);
  });
}

class _ScreenHarness {
  const _ScreenHarness({
    required this.container,
    required this.notifier,
    required this.cameraController,
  });

  final ProviderContainer container;
  final _FakeAssessmentLiveController notifier;
  final _FakeCameraController cameraController;

  Future<void> dispose() async {
    await cameraController.dispose();
    container.dispose();
  }
}

Future<_ScreenHarness> _pumpScreen(
  WidgetTester tester, {
  required AssessmentSelection selection,
  required AssessmentLiveState initialState,
}) async {
  final cameraController = _FakeCameraController();
  late _FakeAssessmentLiveController fakeNotifier;
  final container = ProviderContainer(
    overrides: <Override>[
      selectedAssessmentProvider.overrideWith((ref) => selection),
      assessmentLiveControllerProvider.overrideWith(
        () => fakeNotifier = _FakeAssessmentLiveController(initialState),
      ),
      cameraProvider.overrideWith((ref) async => cameraController),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AssessmentLiveScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();

  return _ScreenHarness(
    container: container,
    notifier: fakeNotifier,
    cameraController: cameraController,
  );
}

class _FakeAssessmentLiveController extends AssessmentLiveController {
  _FakeAssessmentLiveController(this.initialState);

  final AssessmentLiveState initialState;
  int retryCallCount = 0;

  @override
  AssessmentLiveState build() => initialState;

  @override
  AssessmentResult? complete() => state.snapshot.result;

  @override
  void retry() {
    retryCallCount += 1;
    state = AssessmentLiveState(
      snapshot: AssessmentSnapshot(
        type: state.snapshot.type,
        phase: AssessmentPhase.active,
        sampleCount: 0,
        isReadyToComplete: false,
        readinessProgress: 0,
        continuousEvidenceDuration:
            state.snapshot.type == AssessmentType.balance
            ? Duration.zero
            : null,
        result: null,
      ),
      feedbackMessage: 'Tekrar ölçüm yap.',
      progressMessage: state.snapshot.type == AssessmentType.balance
          ? 'Kesintisiz duruş: 0.0 / 5.0 sn'
          : 'Hareket ilerlemesi: %0',
    );
  }
}

class _FakeCameraController extends CameraController {
  _FakeCameraController()
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
      isStreamingImages: true,
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
