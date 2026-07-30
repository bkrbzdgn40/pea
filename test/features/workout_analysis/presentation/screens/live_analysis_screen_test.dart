// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/auth/application/repositories/auth_repository.dart';
import 'package:pose_estimation_app/features/auth/domain/models/auth_user.dart';
import 'package:pose_estimation_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metric_registry.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_developer_ui_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_live_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/repositories/session_repository.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/camera_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/completed_session_metrics_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/completed_session_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_readiness_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/live_pause_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/live_tracking_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/range_rep_outcome_view_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/live_pause_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/live_range_rep_outcome_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/live_tracking_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/preparation_camera_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/session_repository_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_session_lifecycle_controller_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/live_analysis_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/pose_painter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';
import 'package:flutter/services.dart';
import '../../../../support/workout_analysis_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WakelockPlusPlatformInterface originalWakelockPlatform;

  setUpAll(() {
    originalWakelockPlatform = wakelockPlusPlatformInstance;
  });

  setUp(() {
    wakelockPlusPlatformInstance = _FakeWakelockPlusPlatform();
  });

  tearDown(() {
    wakelockPlusPlatformInstance = originalWakelockPlatform;
  });

  testWidgets('shows actionable camera errors without raw exception text', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: <Override>[
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
        activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.squat),
        exerciseConfigProvider.overrideWith((ref) => _squatConfig()),
        poseDetectorProvider.overrideWith((ref) => _FakePoseDetector()),
        authRepositoryProvider.overrideWithValue(
          const _FakeAuthRepository(currentUserId: 'test-user'),
        ),
        sessionRepositoryProvider.overrideWithValue(_FakeSessionRepository()),
        cameraProvider.overrideWith(
          (ref) async => throw StateError('private live camera detail'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const LiveAnalysisScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('live-camera-error')),
      findsOneWidget,
    );
    expect(
      find.textContaining('The camera could not be started'),
      findsOneWidget,
    );
    expect(find.textContaining('private live camera detail'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'starting another live session clears stale metrics after route build',
    (tester) async {
      final detector = _QueuedPoseDetector();
      final sessionRepository = _FakeSessionRepository();
      final container = ProviderContainer(
        overrides: <Override>[
          selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
          activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.squat),
          exerciseConfigProvider.overrideWith((ref) => _squatConfig()),
          poseDetectorProvider.overrideWith((ref) => detector),
          authRepositoryProvider.overrideWithValue(
            const _FakeAuthRepository(currentUserId: 'test-user'),
          ),
          sessionRepositoryProvider.overrideWithValue(sessionRepository),
          cameraProvider.overrideWith(
            (ref) async => throw CameraException('test', 'camera unavailable'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final staleMetrics = WorkoutLiveMetricsSnapshot(
        frameMetrics: ExerciseMetricSnapshotBuilder(
          scope: ExerciseMetricScope.frame,
        ).build(),
        sessionMetrics: ExerciseMetricSnapshotBuilder(
          scope: ExerciseMetricScope.session,
        ).build(),
      );
      container.read(completedSessionMetricsProvider.notifier).state =
          staleMetrics;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(completedSessionMetricsProvider);
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LiveAnalysisScreen(),
                          ),
                        );
                      },
                      child: const Text('Start another session'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start another session'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(container.read(completedSessionMetricsProvider), isNull);
      expect(
        container
            .read(workoutSessionLifecycleControllerProvider)
            .currentStateSnapshot()
            .activeSessionExercise,
        ExerciseType.squat,
      );
    },
  );

  testWidgets('keeps camera preview stable when workout state changes', (
    tester,
  ) async {
    final harness = await _pumpLiveAnalysisScreen(
      tester,
      exerciseType: ExerciseType.squat,
      config: _squatConfig(),
      showFinishButton: true,
    );
    addTearDown(harness.dispose);

    final previewBefore = tester.widget<CameraPreview>(
      find.byType(CameraPreview),
    );
    final stateBefore = harness.container.read(workoutControllerProvider);

    await tester.runAsync(() async {
      await _analyzePoseFrame(harness.controller, harness.detector, <Pose>[
        _squatPose(angle: 170),
      ]);
      harness.clock.advance(const Duration(milliseconds: 120));
      await _analyzePoseFrame(harness.controller, harness.detector, <Pose>[
        _squatPose(angle: 170),
      ]);
    });
    await tester.pump();

    final stateAfter = harness.container.read(workoutControllerProvider);
    final previewAfter = tester.widget<CameraPreview>(
      find.byType(CameraPreview),
    );
    expect(identical(stateAfter, stateBefore), isFalse);
    expect(identical(previewAfter, previewBefore), isTrue);
  });

  testWidgets('updates live metric cards only when displayed values change', (
    tester,
  ) async {
    const initialState = WorkoutState.hold(
      feedbackMessage: 'Form iyi',
      cameraFps: 10.2,
      analysisFps: 8.2,
      analysis: HoldWorkoutAnalysisState(
        currentHoldSeconds: 0.1,
        bestHoldSeconds: 2.1,
        currentPhase: 'HOLDING',
      ),
    );
    final cameraController = _FakeCameraController();
    late _FakeWorkoutController fakeController;
    final container = ProviderContainer(
      overrides: <Override>[
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.plank),
        activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.plank),
        exerciseConfigProvider.overrideWith((ref) => _plankConfig()),
        workoutControllerProvider.overrideWith(
          () => fakeController = _FakeWorkoutController(initialState),
        ),
        authRepositoryProvider.overrideWithValue(
          const _FakeAuthRepository(currentUserId: 'test-user'),
        ),
        sessionRepositoryProvider.overrideWithValue(_FakeSessionRepository()),
        cameraProvider.overrideWith((ref) async => cameraController),
      ],
    );
    addTearDown(() async {
      await cameraController.dispose();
      container.dispose();
    });

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
          home: const LiveAnalysisScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final primaryBefore = tester.widget(
      find.byKey(const ValueKey<String>('live-primary-metric-card')),
    );
    final secondaryBefore = tester.widget(
      find.byKey(const ValueKey<String>('live-secondary-metric-card')),
    );
    final feedbackBefore = tester.widget(
      find.byKey(const ValueKey<String>('live-feedback-message-card')),
    );
    final statusBefore = tester.widget<Text>(
      find.byKey(const ValueKey<String>('live-analysis-status-line')),
    );

    fakeController.publish(
      initialState.copyWith(
        cameraFps: 10.4,
        analysisFps: 8.4,
        holdAnalysis: initialState.holdAnalysis!.copyWith(
          currentHoldSeconds: 0.8,
          bestHoldSeconds: 2.8,
        ),
      ),
    );
    await tester.pump();

    expect(
      identical(
        tester.widget(
          find.byKey(const ValueKey<String>('live-primary-metric-card')),
        ),
        primaryBefore,
      ),
      isTrue,
    );
    expect(
      identical(
        tester.widget(
          find.byKey(const ValueKey<String>('live-secondary-metric-card')),
        ),
        secondaryBefore,
      ),
      isTrue,
    );
    expect(
      identical(
        tester.widget(
          find.byKey(const ValueKey<String>('live-feedback-message-card')),
        ),
        feedbackBefore,
      ),
      isTrue,
    );
    expect(
      identical(
        tester.widget<Text>(
          find.byKey(const ValueKey<String>('live-analysis-status-line')),
        ),
        statusBefore,
      ),
      isTrue,
    );

    fakeController.publish(
      initialState.copyWith(
        cameraFps: 11,
        analysisFps: 9,
        holdAnalysis: initialState.holdAnalysis!.copyWith(
          currentHoldSeconds: 1.1,
          bestHoldSeconds: 3.1,
          currentPhase: 'FORM_CHECK',
        ),
      ),
    );
    await tester.pump();

    expect(
      identical(
        tester.widget(
          find.byKey(const ValueKey<String>('live-primary-metric-card')),
        ),
        primaryBefore,
      ),
      isFalse,
    );
    expect(
      identical(
        tester.widget(
          find.byKey(const ValueKey<String>('live-secondary-metric-card')),
        ),
        secondaryBefore,
      ),
      isFalse,
    );
    expect(
      identical(
        tester.widget(
          find.byKey(const ValueKey<String>('live-feedback-message-card')),
        ),
        feedbackBefore,
      ),
      isFalse,
    );
    expect(
      identical(
        tester.widget<Text>(
          find.byKey(const ValueKey<String>('live-analysis-status-line')),
        ),
        statusBefore,
      ),
      isFalse,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('live-primary-metric-card')),
        matching: find.text('0:01'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'keeps exercise, repetition, score, and remote feedback visible',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const initialState = WorkoutState.rangeRep(
        feedbackMessage: 'Formunu koru.',
        analysis: RangeRepWorkoutAnalysisState(
          repCount: 4,
          lastRepScore: 86,
          currentPhase: 'ASCENDING',
        ),
      );
      final cameraController = _FakeCameraController();
      final container = ProviderContainer(
        overrides: <Override>[
          selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
          activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.squat),
          exerciseConfigProvider.overrideWith((ref) => _squatConfig()),
          workoutControllerProvider.overrideWith(
            () => _FakeWorkoutController(initialState),
          ),
          authRepositoryProvider.overrideWithValue(
            const _FakeAuthRepository(currentUserId: 'test-user'),
          ),
          sessionRepositoryProvider.overrideWithValue(_FakeSessionRepository()),
          cameraProvider.overrideWith((ref) async => cameraController),
        ],
      );
      addTearDown(() async {
        await cameraController.dispose();
        container.dispose();
      });

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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const LiveAnalysisScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final performanceHeader = find.byKey(
        const ValueKey<String>('live-performance-header'),
      );
      final primaryMetric = find.byKey(
        const ValueKey<String>('live-primary-metric-card'),
      );
      final secondaryMetric = find.byKey(
        const ValueKey<String>('live-secondary-metric-card'),
      );
      final feedbackCard = find.byKey(
        const ValueKey<String>('live-feedback-message-card'),
      );

      expect(performanceHeader, findsOneWidget);
      expect(tester.getSize(performanceHeader).height, 152);
      expect(
        find.byKey(const ValueKey<String>('live-active-exercise-name')),
        findsOneWidget,
      );
      expect(find.text('Squat'), findsOneWidget);
      expect(
        find.descendant(of: primaryMetric, matching: find.text('4')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: secondaryMetric, matching: find.text('86')),
        findsOneWidget,
      );
      expect(find.text('Detaylar'), findsNothing);

      final feedbackText = tester.widget<Text>(
        find.descendant(of: feedbackCard, matching: find.text('Formunu koru.')),
      );
      expect(feedbackText.style?.fontSize, 22);
      expect(feedbackText.style?.fontWeight, FontWeight.w800);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows and updates automatic tracked-leg guidance', (
    tester,
  ) async {
    const initialState = WorkoutState.rangeRep(
      feedbackMessage: 'Başlangıç pozuna gel.',
      analysis: RangeRepWorkoutAnalysisState(
        calibrationMetrics: WorkoutCalibrationMetrics.rangeRep(
          payload: RangeRepWorkoutCalibrationMetrics(
            rangeRepAutomaticSideSelectionEnabled: true,
          ),
        ),
      ),
    );
    final cameraController = _FakeCameraController();
    late _FakeWorkoutController fakeController;
    final container = ProviderContainer(
      overrides: <Override>[
        selectedExerciseProvider.overrideWith(
          (ref) => ExerciseType.standingKneeRaise,
        ),
        activeAnalysisExerciseProvider.overrideWithValue(
          ExerciseType.standingKneeRaise,
        ),
        exerciseConfigProvider.overrideWith(
          (ref) => loadExerciseConfig(
            'assets/config/exercises/standing_knee_raise.json',
          ),
        ),
        workoutControllerProvider.overrideWith(
          () => fakeController = _FakeWorkoutController(initialState),
        ),
        authRepositoryProvider.overrideWithValue(
          const _FakeAuthRepository(currentUserId: 'test-user'),
        ),
        sessionRepositoryProvider.overrideWithValue(_FakeSessionRepository()),
        cameraProvider.overrideWith((ref) async => cameraController),
      ],
    );
    addTearDown(() async {
      await cameraController.dispose();
      container.dispose();
    });

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
          home: const LiveAnalysisScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('live-range-rep-side-indicator')),
      findsOneWidget,
    );
    expect(find.textContaining('otomatik seçilecek'), findsOneWidget);

    fakeController.publish(
      initialState.copyWith(
        rangeRepAnalysis: initialState.rangeRepAnalysis!.copyWith(
          calibrationMetrics: const WorkoutCalibrationMetrics.rangeRep(
            payload: RangeRepWorkoutCalibrationMetrics(
              selectedRangeRepSide: 'right',
              rangeRepAutomaticSideSelectionEnabled: true,
              rangeRepMovementSelectedSide: 'right',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sağ bacak takip ediliyor'), findsOneWidget);
  });

  testWidgets('uses compact non-overlapping overlays in landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await _pumpLiveAnalysisScreen(
      tester,
      exerciseType: ExerciseType.plank,
      config: _plankConfig(),
      showFinishButton: true,
    );
    addTearDown(harness.dispose);

    harness.cameraController!.setDeviceOrientation(
      DeviceOrientation.landscapeLeft,
    );
    await tester.pump();

    final performanceHeader = find.byKey(
      const ValueKey<String>('live-performance-header'),
    );
    final feedbackCard = find.byKey(
      const ValueKey<String>('live-feedback-message-card'),
    );
    final pauseButton = find.byKey(const ValueKey<String>('live-pause-button'));

    expect(performanceHeader, findsOneWidget);
    expect(feedbackCard, findsOneWidget);
    expect(tester.getSize(performanceHeader).height, 76);
    expect(
      find.byKey(const ValueKey<String>('live-active-exercise-name')),
      findsOneWidget,
    );
    expect(find.text('Plank'), findsOneWidget);
    expect(
      tester.getRect(performanceHeader).top,
      greaterThan(tester.getRect(pauseButton).bottom),
    );
    expect(
      tester.getRect(performanceHeader).bottom,
      lessThan(tester.getRect(feedbackCard).top),
    );
    expect(tester.getSize(feedbackCard).width, lessThan(760));
    final landscapeFeedbackText = find.descendant(
      of: feedbackCard,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.style?.fontSize == 18 &&
            widget.style?.fontWeight == FontWeight.w800,
      ),
    );
    expect(landscapeFeedbackText, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      await _analyzePoseFrame(harness.controller, harness.detector, <Pose>[
        _plankPose(),
      ]);
      harness.clock.advance(const Duration(milliseconds: 100));
      await _analyzePoseFrame(harness.controller, harness.detector, <Pose>[
        _plankPose(),
      ]);
    });
    await tester.pump();

    final posePaint = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is PosePainter,
    );
    expect(posePaint, findsOneWidget);
    final painter =
        tester.widget<CustomPaint>(posePaint).painter! as PosePainter;
    expect(painter.absoluteImageSize, const Size(640, 480));
  });

  testWidgets('prioritizes the latest rep outcome over movement feedback', (
    tester,
  ) async {
    final harness = await _pumpLiveAnalysisScreen(
      tester,
      exerciseType: ExerciseType.squat,
      config: _squatConfig(),
      showFinishButton: true,
    );
    addTearDown(harness.dispose);

    const outcome = RangeRepOutcomeViewData(
      repIndex: 1,
      status: RangeRepValidationStatus.invalid,
      primaryReason: RangeRepValidationReason.insufficientRom,
      title: 'Geçersiz tekrar',
      message: 'Yeterli hareket aralığı oluşmadı.',
      tone: RangeRepOutcomeTone.invalid,
    );
    harness.container.read(liveRangeRepOutcomeProvider.notifier).show(outcome);
    await tester.pump();

    expect(find.text('Geçersiz tekrar'), findsOneWidget);
    expect(find.text('Yeterli hareket aralığı oluşmadı.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('live-feedback-message-card')),
        matching: find.byIcon(Icons.replay_rounded),
      ),
      findsOneWidget,
    );

    harness.container.read(liveRangeRepOutcomeProvider.notifier).dismiss();
    await tester.pump();
    expect(find.text('Geçersiz tekrar'), findsNothing);
  });

  testWidgets('keeps technical FPS out of the normal live surface', (
    tester,
  ) async {
    final harness = await _pumpLiveAnalysisScreen(
      tester,
      exerciseType: ExerciseType.squat,
      config: _squatConfig(),
      showFinishButton: true,
    );
    addTearDown(harness.dispose);

    expect(
      find.byKey(const ValueKey<String>('live-camera-fps-metric-card')),
      findsNothing,
    );
    expect(find.textContaining('FPS'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('live-secondary-metric-card')),
        matching: find.text('—'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'hides invalid-attempt scores and marks low-confidence scores as cautionary',
    (tester) async {
      const invalidState = WorkoutState.rangeRep(
        analysis: RangeRepWorkoutAnalysisState(
          repCount: 1,
          lastRepScore: 92,
          calibrationMetrics: WorkoutCalibrationMetrics.rangeRep(
            payload: RangeRepWorkoutCalibrationMetrics(
              hasLastRangeRepValidation: true,
              lastRangeRepValidationStatus: 'invalid',
              lastRangeRepValidatedRepIndex: 2,
            ),
          ),
        ),
      );
      final cameraController = _FakeCameraController();
      late _FakeWorkoutController fakeController;
      final container = ProviderContainer(
        overrides: <Override>[
          selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
          activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.squat),
          exerciseConfigProvider.overrideWith((ref) => _squatConfig()),
          workoutControllerProvider.overrideWith(
            () => fakeController = _FakeWorkoutController(invalidState),
          ),
          authRepositoryProvider.overrideWithValue(
            const _FakeAuthRepository(currentUserId: 'test-user'),
          ),
          sessionRepositoryProvider.overrideWithValue(_FakeSessionRepository()),
          cameraProvider.overrideWith((ref) async => cameraController),
        ],
      );
      addTearDown(() async {
        await cameraController.dispose();
        container.dispose();
      });

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
            home: const LiveAnalysisScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final scoreCard = find.byKey(
        const ValueKey<String>('live-secondary-metric-card'),
      );
      expect(
        find.descendant(of: scoreCard, matching: find.text('—')),
        findsOneWidget,
      );

      fakeController.publish(
        const WorkoutState.rangeRep(
          analysis: RangeRepWorkoutAnalysisState(
            repCount: 2,
            lastRepScore: 78,
            calibrationMetrics: WorkoutCalibrationMetrics.rangeRep(
              payload: RangeRepWorkoutCalibrationMetrics(
                hasLastRangeRepValidation: true,
                lastRangeRepValidationStatus: 'low confidence',
                lastRangeRepValidatedRepIndex: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final scoreText = tester.widget<Text>(
        find.descendant(of: scoreCard, matching: find.text('78')),
      );
      expect(scoreText.style?.color, Colors.amberAccent);
    },
  );

  testWidgets(
    'replaces exercise feedback with reposition guidance while tracking is lost',
    (tester) async {
      const initialState = WorkoutState.rangeRep(
        feedbackMessage: 'Dizlerini düzelt',
        analysis: RangeRepWorkoutAnalysisState(
          repCount: 4,
          isFormBad: true,
          currentPhase: 'DESCENDING',
        ),
      );
      final cameraController = _FakeCameraController();
      late _FakeLiveTrackingController trackingController;
      final container = ProviderContainer(
        overrides: <Override>[
          selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
          activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.squat),
          exerciseConfigProvider.overrideWith((ref) => _squatConfig()),
          workoutControllerProvider.overrideWith(
            () => _FakeWorkoutController(initialState),
          ),
          liveTrackingControllerProvider.overrideWith(
            () => trackingController = _FakeLiveTrackingController(),
          ),
          authRepositoryProvider.overrideWithValue(
            const _FakeAuthRepository(currentUserId: 'test-user'),
          ),
          sessionRepositoryProvider.overrideWithValue(_FakeSessionRepository()),
          cameraProvider.overrideWith((ref) async => cameraController),
        ],
      );
      addTearDown(() async {
        await cameraController.dispose();
        container.dispose();
      });

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
            home: const LiveAnalysisScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      trackingController.publish(
        LiveTrackingState(
          phase: LiveTrackingPhase.repositionRequired,
          lossStartedAt: DateTime(2026, 7, 26),
          lastTransitionAt: DateTime(2026, 7, 26),
        ),
      );
      await tester.pump();

      expect(find.text('Kadraja geri dön'), findsOneWidget);
      expect(find.textContaining('Sayım ve süre'), findsOneWidget);
      expect(find.text('Dizlerini düzelt'), findsNothing);
      expect(find.text('4'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('live-tracking-overlay-title')),
        findsOneWidget,
      );

      trackingController.publish(
        LiveTrackingState(
          phase: LiveTrackingPhase.reacquiring,
          lossStartedAt: DateTime(2026, 7, 26),
          lastTransitionAt: DateTime(2026, 7, 26),
        ),
      );
      await tester.pump();

      expect(find.text('Pozisyon kontrol ediliyor'), findsOneWidget);
    },
  );

  testWidgets('manual pause requires readiness and a resume countdown', (
    tester,
  ) async {
    final harness = await _pumpLiveAnalysisScreen(
      tester,
      exerciseType: ExerciseType.squat,
      config: _squatConfig(),
      showFinishButton: true,
    );
    addTearDown(harness.dispose);

    expect(
      find.byKey(const ValueKey<String>('live-pause-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('live-pause-button')));
    await tester.pump();

    expect(find.text('Antrenman duraklatıldı'), findsOneWidget);
    expect(find.text('Bitir'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('live-resume-button')),
      findsOneWidget,
    );
    expect(
      harness.container.read(livePauseControllerProvider).phase,
      LivePausePhase.paused,
    );

    await tester.tap(find.byKey(const ValueKey<String>('live-resume-button')));
    await tester.pump();

    expect(find.text('Devam etmeye hazırlan'), findsOneWidget);
    expect(
      harness.container.read(livePauseControllerProvider).phase,
      LivePausePhase.resumeMonitoring,
    );

    harness.container
        .read(livePauseControllerProvider.notifier)
        .updateReadiness(_readyReadinessSnapshot());
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('live-resume-countdown-3')),
      findsOneWidget,
    );
    expect(
      harness.container.read(livePauseControllerProvider).phase,
      LivePausePhase.resumeCountingDown,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byKey(const ValueKey<String>('live-resume-countdown-2')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byKey(const ValueKey<String>('live-resume-countdown-1')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));

    expect(
      harness.container.read(livePauseControllerProvider).phase,
      LivePausePhase.active,
    );
    expect(
      find.byKey(const ValueKey<String>('live-pause-overlay')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('live-pause-button')),
      findsOneWidget,
    );
  });

  testWidgets('pause lifecycle disarms a PEAK recovery before neutral return', (
    tester,
  ) async {
    final sessionRepository = _FakeSessionRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
        activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.squat),
        exerciseConfigProvider.overrideWith((ref) => _squatConfig()),
        poseDetectorProvider.overrideWith((ref) => _FakePoseDetector()),
        authRepositoryProvider.overrideWithValue(
          const _FakeAuthRepository(currentUserId: 'test-user'),
        ),
        sessionRepositoryProvider.overrideWithValue(sessionRepository),
        cameraProvider.overrideWith(
          (ref) async => throw CameraException('test', 'camera unavailable'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LiveAnalysisScreen()),
      ),
    );
    await tester.pump();

    final controller = container.read(workoutControllerProvider.notifier);
    final timeline = _ControllerTimeline();

    await tester.runAsync(() async {
      await _driveUntilPhase(
        container,
        controller,
        timeline,
        primaryAngle: 170,
        expectedPhase: 'NEUTRAL',
      );
      await _driveUntilPhase(
        container,
        controller,
        timeline,
        primaryAngle: 140,
        expectedPhase: 'DESCENDING',
      );
      await _driveUntilPhase(
        container,
        controller,
        timeline,
        primaryAngle: 90,
        expectedPhase: 'PEAK',
      );
    });

    expect(container.read(workoutControllerProvider).currentPhase, 'PEAK');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    var state = container.read(workoutControllerProvider);
    expect(state.currentPhase, rangeRepAwaitNeutralPhaseLabel);
    expect(state.repCount, 0);

    await tester.runAsync(() async {
      await _pumpFrames(controller, timeline, primaryAngle: 90);
      await _driveUntilPhase(
        container,
        controller,
        timeline,
        primaryAngle: 170,
        expectedPhase: 'NEUTRAL',
      );
    });
    await tester.pump();

    state = container.read(workoutControllerProvider);
    expect(state.repCount, 0);
    expect(state.currentPhase, 'NEUTRAL');
  });

  testWidgets(
    'pause lifecycle on plank reaches the controller interruption path',
    (tester) async {
      final harness = await _pumpLiveAnalysisScreen(
        tester,
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
      );
      addTearDown(harness.dispose);

      await tester.runAsync(() async {
        await _establishVisibleHoldOnScreen(
          harness.controller,
          harness.detector,
          harness.clock,
        );
      });

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      var state = harness.container.read(workoutControllerProvider);
      expect(state.currentHoldSeconds, 0);
      expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(state.isHolding, isFalse);
      expect(state.isHoldVisibilitySuspended, isFalse);
      expect(state.currentPhase, 'READY');

      await tester.runAsync(() async {
        harness.clock.advance(const Duration(seconds: 10));
        await _analyzePoseFrame(harness.controller, harness.detector, <Pose>[
          _plankPose(),
        ]);
        harness.clock.advance(const Duration(milliseconds: 100));
        await _analyzePoseFrame(harness.controller, harness.detector, <Pose>[
          _plankPose(),
        ]);
        harness.clock.advance(const Duration(seconds: 1));
        await _analyzePoseFrame(harness.controller, harness.detector, <Pose>[
          _plankPose(),
        ]);
      });
      await tester.pump();

      state = harness.container.read(workoutControllerProvider);
      expect(state.currentHoldSeconds, closeTo(1.0, 0.001));
      expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
    },
  );

  testWidgets(
    'screen keeps the same autoDispose lifecycle owner across rebuilds and '
    'save flow',
    (tester) async {
      final harness = await _pumpLiveAnalysisScreen(
        tester,
        exerciseType: ExerciseType.squat,
        config: _squatConfig(),
        showFinishButton: true,
      );
      addTearDown(harness.dispose);

      final initialOwner = harness.container.read(
        workoutSessionLifecycleControllerProvider,
      );
      expect(initialOwner.currentStateSnapshot().hasSavedSession, isFalse);

      await tester.longPress(
        find.byKey(const ValueKey<String>('live-performance-header')),
      );
      await tester.pump();
      await tester.longPress(
        find.byKey(const ValueKey<String>('live-performance-header')),
      );
      await tester.pump();

      final rebuiltOwner = harness.container.read(
        workoutSessionLifecycleControllerProvider,
      );
      expect(rebuiltOwner, same(initialOwner));

      await tester.runAsync(() async {
        await _completeCleanRangeRepOnScreen(
          harness.controller,
          harness.detector,
          harness.clock,
        );
      });
      await tester.pump();

      final snapshotSubscription = harness.container
          .listen<AsyncValue<UserSessionsSnapshot>>(
            userSessionsSnapshotProvider,
            (previous, next) {},
            fireImmediately: true,
          );
      addTearDown(snapshotSubscription.close);
      await tester.pump();
      expect(harness.sessionRepository.listSessionsCallCount, 1);

      final initialPushCount = harness.navigationObserver.pushCount;
      await _requestSaveAndFinish(tester);
      await _pumpUntilRoutePush(
        tester,
        harness.navigationObserver,
        initialPushCount + 1,
      );

      final persistedOwner = harness.container.read(
        workoutSessionLifecycleControllerProvider,
      );
      final session = harness.sessionRepository.savedSessions.single;
      expect(persistedOwner, same(initialOwner));
      expect(persistedOwner.currentStateSnapshot().hasSavedSession, isTrue);
      expect(persistedOwner.currentStateSnapshot().isFinishing, isTrue);
      expect(session.ownerId, 'test-user');
      expect(harness.sessionRepository.savedSessions, hasLength(1));
      expect(harness.sessionRepository.listSessionsCallCount, 2);
      expect(harness.container.read(completedSessionProvider), same(session));
    },
  );

  testWidgets(
    'back on an active session opens the exit dialog and return keeps analysis open',
    (tester) async {
      final harness = await _pumpLiveAnalysisScreen(
        tester,
        exerciseType: ExerciseType.squat,
        config: _squatConfig(),
        showFinishButton: true,
        pushFromLauncher: true,
      );
      addTearDown(harness.dispose);

      await tester.runAsync(() async {
        await _completeCleanRangeRepOnScreen(
          harness.controller,
          harness.detector,
          harness.clock,
        );
      });
      await tester.pump();

      expect(
        harness.container
            .read(workoutSessionLifecycleControllerProvider)
            .hasSavableProgress,
        isTrue,
      );

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('live-exit-dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('live-exit-return-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('live-exit-save-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('live-exit-discard-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('live-exit-return-button')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('live-exit-dialog')),
        findsNothing,
      );
      expect(find.text('Bitir'), findsOneWidget);
      expect(harness.sessionRepository.saveCallCount, 0);
      expect(harness.sessionRepository.savedSessions, isEmpty);
    },
  );

  testWidgets('back save action finishes the session exactly once', (
    tester,
  ) async {
    final harness = await _pumpLiveAnalysisScreen(
      tester,
      exerciseType: ExerciseType.squat,
      config: _squatConfig(),
      showFinishButton: true,
      pushFromLauncher: true,
    );
    addTearDown(harness.dispose);

    await tester.runAsync(() async {
      await _completeCleanRangeRepOnScreen(
        harness.controller,
        harness.detector,
        harness.clock,
      );
    });
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    final pushCountAfterDialog = harness.navigationObserver.pushCount;

    await tester.tap(
      find.byKey(const ValueKey<String>('live-exit-save-button')),
    );
    await tester.pump();
    await _pumpUntilRoutePush(
      tester,
      harness.navigationObserver,
      pushCountAfterDialog + 1,
    );

    expect(harness.sessionRepository.saveCallCount, 1);
    expect(harness.sessionRepository.savedSessions, hasLength(1));
  });

  testWidgets('exit without saving closes live route without persistence', (
    tester,
  ) async {
    final harness = await _pumpLiveAnalysisScreen(
      tester,
      exerciseType: ExerciseType.squat,
      config: _squatConfig(),
      showFinishButton: true,
      pushFromLauncher: true,
    );
    addTearDown(harness.dispose);

    await tester.runAsync(() async {
      await _completeCleanRangeRepOnScreen(
        harness.controller,
        harness.detector,
        harness.clock,
      );
    });
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('live-exit-discard-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('open-live-analysis')),
      findsOneWidget,
    );
    expect(harness.sessionRepository.saveCallCount, 0);
    expect(harness.sessionRepository.savedSessions, isEmpty);
  });

  testWidgets('back with no savable progress exits without showing a dialog', (
    tester,
  ) async {
    final harness = await _pumpLiveAnalysisScreen(
      tester,
      exerciseType: ExerciseType.squat,
      config: _squatConfig(),
      showFinishButton: true,
      pushFromLauncher: true,
    );
    addTearDown(harness.dispose);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('live-exit-dialog')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('open-live-analysis')),
      findsOneWidget,
    );
    expect(harness.sessionRepository.saveCallCount, 0);
  });

  testWidgets('back while saving does not start a second finish operation', (
    tester,
  ) async {
    final harness = await _pumpLiveAnalysisScreen(
      tester,
      exerciseType: ExerciseType.squat,
      config: _squatConfig(),
      showFinishButton: true,
      pushFromLauncher: true,
    );
    addTearDown(harness.dispose);

    await tester.runAsync(() async {
      await _completeCleanRangeRepOnScreen(
        harness.controller,
        harness.detector,
        harness.clock,
      );
    });
    await tester.pump();

    harness.sessionRepository.saveCompleter = Completer<void>();
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('live-exit-save-button')),
    );
    await tester.pump();

    expect(harness.sessionRepository.saveCallCount, 1);
    expect(
      harness.container
          .read(workoutSessionLifecycleControllerProvider)
          .isFinishing,
      isTrue,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('live-exit-dialog')),
      findsNothing,
    );
    expect(harness.sessionRepository.saveCallCount, 1);

    final pushCountBeforeSaveCompletes = harness.navigationObserver.pushCount;
    harness.sessionRepository.saveCompleter!.complete();
    await _pumpUntilRoutePush(
      tester,
      harness.navigationObserver,
      pushCountBeforeSaveCompletes + 1,
    );

    expect(harness.sessionRepository.saveCallCount, 1);
    expect(harness.sessionRepository.savedSessions, hasLength(1));
  });

  testWidgets(
    'successful finish keeps finishing true and camera stopped until summary '
    'is dismissed',
    (tester) async {
      final harness = await _pumpLiveAnalysisScreen(
        tester,
        exerciseType: ExerciseType.squat,
        config: _squatConfig(),
        showFinishButton: true,
      );
      addTearDown(harness.dispose);

      await tester.runAsync(() async {
        await _completeCleanRangeRepOnScreen(
          harness.controller,
          harness.detector,
          harness.clock,
        );
      });
      await tester.pump();

      final sessionLifecycle = harness.container.read(
        workoutSessionLifecycleControllerProvider,
      );
      final initialPushCount = harness.navigationObserver.pushCount;

      await _requestSaveAndFinish(tester);
      await _pumpUntilRoutePush(
        tester,
        harness.navigationObserver,
        initialPushCount + 1,
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(sessionLifecycle.currentStateSnapshot().isFinishing, isTrue);
      expect(sessionLifecycle.currentStateSnapshot().hasSavedSession, isTrue);
      expect(harness.cameraController!.stopImageStreamCallCount, 2);
      expect(harness.cameraController!.startImageStreamCallCount, 1);
      expect(harness.cameraController!.value.isStreamingImages, isFalse);

      harness.navigationObserver.lastPushedRoute!.navigator!.pop();
      await tester.pumpAndSettle();

      expect(sessionLifecycle.currentStateSnapshot().isFinishing, isFalse);
      expect(sessionLifecycle.currentStateSnapshot().hasSavedSession, isTrue);
      expect(harness.cameraController!.startImageStreamCallCount, 2);
      expect(harness.cameraController!.value.isStreamingImages, isTrue);
    },
  );

  testWidgets(
    'retry preserves the completed session and starts a clean session with a new id',
    (tester) async {
      final harness = await _pumpLiveAnalysisScreen(
        tester,
        exerciseType: ExerciseType.squat,
        config: _squatConfig(),
        showFinishButton: true,
      );
      addTearDown(harness.dispose);

      await tester.runAsync(() async {
        await _completeCleanRangeRepOnScreen(
          harness.controller,
          harness.detector,
          harness.clock,
        );
      });
      await tester.pump();

      expect(harness.container.read(workoutControllerProvider).repCount, 1);
      final initialPushCount = harness.navigationObserver.pushCount;

      await _requestSaveAndFinish(tester);
      await _pumpUntilRoutePush(
        tester,
        harness.navigationObserver,
        initialPushCount + 1,
      );

      expect(harness.sessionRepository.savedSessions, hasLength(1));
      expect(harness.container.read(completedSessionProvider), isNotNull);
      expect(
        harness.container.read(completedSessionMetricsProvider),
        isNotNull,
      );

      final firstSessionId = harness.sessionRepository.savedSessions.single.id;

      await tester.tap(find.text('Aynı Hareketi Tekrarla'));
      await tester.pumpAndSettle();

      expect(harness.sessionRepository.savedSessions, hasLength(1));
      expect(harness.sessionRepository.deleteCallCount, 0);
      expect(harness.sessionRepository.savedSessions.single.id, firstSessionId);

      final restartedState = harness.container.read(workoutControllerProvider);
      final restartedLifecycle = harness.container
          .read(workoutSessionLifecycleControllerProvider)
          .currentStateSnapshot();

      expect(restartedState.repCount, 0);
      expect(restartedState.lastRepScore, 0);
      expect(
        harness.container.read(workoutLiveMetricsProvider).isEmpty,
        isTrue,
      );
      expect(harness.container.read(completedSessionProvider), isNull);
      expect(harness.container.read(completedSessionMetricsProvider), isNull);
      expect(restartedLifecycle.activeSessionExercise, ExerciseType.squat);
      expect(restartedLifecycle.hasSavedSession, isFalse);
      expect(restartedLifecycle.isFinishing, isFalse);

      final restartedController = harness.container.read(
        workoutControllerProvider.notifier,
      );
      await tester.runAsync(() async {
        await _completeCleanRangeRepOnScreen(
          restartedController,
          harness.detector,
          harness.clock,
        );
      });
      await tester.pump();

      final secondPushCount = harness.navigationObserver.pushCount;
      await _requestSaveAndFinish(tester);
      await _pumpUntilRoutePush(
        tester,
        harness.navigationObserver,
        secondPushCount + 1,
      );

      expect(harness.sessionRepository.savedSessions, hasLength(2));
      expect(harness.sessionRepository.deleteCallCount, 0);
      expect(
        harness.sessionRepository.savedSessions.map((session) => session.id),
        contains(firstSessionId),
      );
      expect(
        harness.sessionRepository.savedSessions
            .map((session) => session.id)
            .toSet(),
        hasLength(2),
      );
    },
  );

  testWidgets(
    'finishing a completed range-rep session saves the production rep summary',
    (tester) async {
      final harness = await _pumpLiveAnalysisScreen(
        tester,
        exerciseType: ExerciseType.squat,
        config: _squatConfig(),
        showFinishButton: true,
      );
      addTearDown(harness.dispose);

      await tester.runAsync(() async {
        await _completeCleanRangeRepOnScreen(
          harness.controller,
          harness.detector,
          harness.clock,
        );
      });
      await tester.pump();

      final state = harness.container.read(workoutControllerProvider);
      expect(state.repCount, 1);
      expect(state.calibrationMetrics.lastRangeRepValidatedRepIndex, 1);
      expect(state.calibrationMetrics.lastRangeRepValidationStatus, 'valid');
      expect(find.text('Bitir'), findsOneWidget);

      final snapshotSubscription = harness.container
          .listen<AsyncValue<UserSessionsSnapshot>>(
            userSessionsSnapshotProvider,
            (previous, next) {},
            fireImmediately: true,
          );
      addTearDown(snapshotSubscription.close);
      await tester.pump();
      expect(harness.sessionRepository.listSessionsCallCount, 1);
      final initialPushCount = harness.navigationObserver.pushCount;

      await _requestSaveAndFinish(tester);
      await _pumpUntilRoutePush(
        tester,
        harness.navigationObserver,
        initialPushCount + 1,
      );

      expect(harness.sessionRepository.savedSessions, hasLength(1));
      final session = harness.sessionRepository.savedSessions.single;
      final rep = session.reps!.single;

      expect(session.ownerId, 'test-user');
      expect(session.exerciseType, ExerciseType.squat.id);
      expect(session.analysisKind, EngineKind.rangeRep.name);
      expect(session.totalReps, 1);
      expect(session.validReps, 1);
      expect(session.invalidReps, 0);
      expect(session.formWarningCount, 0);
      expect(session.reps, hasLength(1));
      expect(rep.repIndex, 1);
      expect(rep.validationStatus, 'valid');
      expect(rep.validationReasons, isEmpty);
      expect(rep.completedPhaseSequence, isTrue);
      expect(rep.selectedSideLabel, 'left');
      expect(harness.container.read(completedSessionProvider), same(session));
      expect(harness.sessionRepository.listSessionsCallCount, 2);
      expect(harness.navigationObserver.pushCount, initialPushCount + 1);
    },
  );

  testWidgets(
    'finishing an active hold session saves the collected hold totals',
    (tester) async {
      final harness = await _pumpLiveAnalysisScreen(
        tester,
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
        showFinishButton: true,
      );
      addTearDown(harness.dispose);

      await tester.runAsync(() async {
        await _establishVisibleHoldOnScreen(
          harness.controller,
          harness.detector,
          harness.clock,
        );
      });
      await tester.pump();

      final state = harness.container.read(workoutControllerProvider);
      expect(state.isHolding, isTrue);
      expect(state.currentHoldSeconds, closeTo(5.0, 0.001));
      expect(find.text('Bitir'), findsOneWidget);

      final snapshotSubscription = harness.container
          .listen<AsyncValue<UserSessionsSnapshot>>(
            userSessionsSnapshotProvider,
            (previous, next) {},
            fireImmediately: true,
          );
      addTearDown(snapshotSubscription.close);
      await tester.pump();
      expect(harness.sessionRepository.listSessionsCallCount, 1);
      final initialPushCount = harness.navigationObserver.pushCount;

      await _requestSaveAndFinish(tester);
      await _pumpUntilRoutePush(
        tester,
        harness.navigationObserver,
        initialPushCount + 1,
      );

      expect(harness.sessionRepository.savedSessions, hasLength(1));
      final session = harness.sessionRepository.savedSessions.single;

      expect(session.ownerId, 'test-user');
      expect(session.exerciseType, ExerciseType.plank.id);
      expect(session.analysisKind, EngineKind.hold.name);
      expect(session.totalReps, 0);
      expect(session.validReps, 0);
      expect(session.invalidReps, 0);
      expect(session.averageScore, 0);
      expect(session.bestScore, 0);
      expect(session.worstScore, 0);
      expect(session.totalHoldSeconds, closeTo(5.0, 0.001));
      expect(session.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(session.formBreakCount, 0);
      expect(session.reps, isNull);
      expect(harness.container.read(completedSessionProvider), same(session));
      expect(harness.sessionRepository.listSessionsCallCount, 2);
      expect(harness.navigationObserver.pushCount, initialPushCount + 1);
    },
  );

  testWidgets(
    'finishing a completed sit-up session preserves sit_up and rangeRep persistence',
    (tester) async {
      final harness = await _pumpLiveAnalysisScreen(
        tester,
        exerciseType: ExerciseType.sitUp,
        config: _sitUpConfig(),
        showFinishButton: true,
      );
      addTearDown(harness.dispose);

      await tester.runAsync(() async {
        await _completeCleanSitUpRepOnScreen(
          harness.controller,
          harness.detector,
          harness.clock,
        );
      });
      await tester.pump();

      final state = harness.container.read(workoutControllerProvider);
      expect(state.repCount, 1);
      expect(state.rangeRepAnalysis, isNotNull);
      expect(find.text('Bitir'), findsOneWidget);

      final initialPushCount = harness.navigationObserver.pushCount;
      await _requestSaveAndFinish(tester);
      await _pumpUntilRoutePush(
        tester,
        harness.navigationObserver,
        initialPushCount + 1,
      );

      expect(harness.sessionRepository.savedSessions, hasLength(1));
      final session = harness.sessionRepository.savedSessions.single;
      final rep = session.reps!.single;

      expect(session.exerciseType, ExerciseType.sitUp.id);
      expect(session.analysisKind, EngineKind.rangeRep.name);
      expect(session.totalReps, 1);
      expect(rep.validationStatus, 'valid');
      expect(rep.completedPhaseSequence, isTrue);
      expect(rep.score, inInclusiveRange(0, 100));
    },
  );

  testWidgets(
    'finishing a completed biceps curl session preserves biceps_curl and rangeRep persistence',
    (tester) async {
      final harness = await _pumpLiveAnalysisScreen(
        tester,
        exerciseType: ExerciseType.bicepsCurl,
        config: _bicepsConfig(),
        showFinishButton: true,
      );
      addTearDown(harness.dispose);

      await tester.runAsync(() async {
        await _completeCleanBicepsCurlRepOnScreen(
          harness.controller,
          harness.detector,
          harness.clock,
        );
      });
      await tester.pump();

      final state = harness.container.read(workoutControllerProvider);
      expect(state.repCount, 1);
      expect(state.rangeRepAnalysis, isNotNull);
      expect(find.text('Bitir'), findsOneWidget);

      final initialPushCount = harness.navigationObserver.pushCount;
      await _requestSaveAndFinish(tester);
      await _pumpUntilRoutePush(
        tester,
        harness.navigationObserver,
        initialPushCount + 1,
      );

      expect(harness.sessionRepository.savedSessions, hasLength(1));
      final session = harness.sessionRepository.savedSessions.single;
      final rep = session.reps!.single;

      expect(session.exerciseType, ExerciseType.bicepsCurl.id);
      expect(session.analysisKind, EngineKind.rangeRep.name);
      expect(session.totalReps, 1);
      expect(rep.validationStatus, 'valid');
      expect(rep.completedPhaseSequence, isTrue);
      expect(rep.score, inInclusiveRange(0, 100));
      expect(rep.selectedSideLabel, isNull);
    },
  );

  testWidgets('developer workout UI follows the compile-time flag', (
    tester,
  ) async {
    final harness = await _pumpLiveAnalysisScreen(
      tester,
      exerciseType: ExerciseType.sitUp,
      config: _sitUpConfig(),
      showFinishButton: true,
    );
    addTearDown(harness.dispose);

    harness.container
        .read(workoutLiveMetricsProvider.notifier)
        .publish(angleDegrees: 90);
    await tester.pump();

    final performanceHeader = find.byKey(
      const ValueKey<String>('live-performance-header'),
    );
    final headerGesture = tester.widget<GestureDetector>(performanceHeader);

    expect(
      find.byKey(const ValueKey<String>('live-diagnostics-button')),
      workoutDeveloperUiEnabled ? findsOneWidget : findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('live-canonical-metrics-bar')),
      workoutDeveloperUiEnabled ? findsOneWidget : findsNothing,
    );
    expect(
      headerGesture.onLongPress,
      workoutDeveloperUiEnabled ? isNotNull : isNull,
    );

    if (!workoutDeveloperUiEnabled) {
      expect(find.text('primary/current'), findsNothing);
      expect(find.text('form/current'), findsNothing);
      return;
    }

    await tester.longPress(performanceHeader);
    await tester.pump();

    expect(find.text('primary/current'), findsOneWidget);
    expect(find.text('form/current'), findsOneWidget);
    expect(find.text('knee/current'), findsNothing);
    expect(find.text('back-angle'), findsNothing);
  });
}

class _FakePoseDetector implements PoseDetector {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControllerTimeline {
  DateTime current = DateTime.utc(2030, 1, 1);

  DateTime advance(Duration duration) {
    current = current.add(duration);
    return current;
  }
}

Future<void> _driveUntilPhase(
  ProviderContainer container,
  WorkoutController controller,
  _ControllerTimeline timeline, {
  required double primaryAngle,
  required String expectedPhase,
  double formMetric = 170,
  int maxFrames = 12,
  Duration frameSpacing = const Duration(milliseconds: 50),
}) async {
  for (var index = 0; index < maxFrames; index++) {
    controller.processExerciseMetricsForTesting(
      metrics: _validMetrics(
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      now: timeline.current,
    );
    if (container.read(workoutControllerProvider).currentPhase ==
        expectedPhase) {
      return;
    }
    if (index == maxFrames - 1) {
      break;
    }
    await Future<void>.delayed(frameSpacing);
    timeline.advance(frameSpacing);
  }

  throw TestFailure(
    'Expected phase $expectedPhase for primaryAngle $primaryAngle',
  );
}

Future<void> _requestSaveAndFinish(WidgetTester tester) async {
  await tester.tap(find.text('Bitir'));
  await tester.pump();

  expect(
    find.byKey(const ValueKey<String>('live-exit-dialog')),
    findsOneWidget,
  );
  await tester.tap(find.byKey(const ValueKey<String>('live-exit-save-button')));
  await tester.pump();
}

Future<void> _pumpUntilRoutePush(
  WidgetTester tester,
  _TestNavigatorObserver navigationObserver,
  int expectedPushCount,
) async {
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (navigationObserver.pushCount >= expectedPushCount) {
      return;
    }
  }

  throw TestFailure('Workout summary route was not pushed.');
}

Future<void> _pumpFrames(
  WorkoutController controller,
  _ControllerTimeline timeline, {
  required double primaryAngle,
  double formMetric = 170,
  int frameCount = 6,
  Duration frameSpacing = const Duration(milliseconds: 50),
}) async {
  for (var index = 0; index < frameCount; index++) {
    controller.processExerciseMetricsForTesting(
      metrics: _validMetrics(
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      now: timeline.current,
    );
    if (index == frameCount - 1) {
      break;
    }
    await Future<void>.delayed(frameSpacing);
    timeline.advance(frameSpacing);
  }
}

ExerciseMetrics _validMetrics({
  required double primaryAngle,
  double formMetric = 170,
}) {
  final left = RangeRepSideMetrics(
    side: RangeRepSide.left,
    primaryAngle: primaryAngle,
    formMetric: formMetric,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    sideConfidence: 1,
    formSignals: RangeRepFormSignals(
      torsoAngle: formMetric,
      depthMetric: primaryAngle,
      alignmentMetric: formMetric,
      lockoutMetric: primaryAngle,
    ),
  );
  return ExerciseMetrics(
    primaryAngle: primaryAngle,
    formMetric: formMetric,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    hasPose: true,
    landmarks: const <PoseLandmark>[],
    leftRangeRepMetrics: left,
    rightRangeRepMetrics: const RangeRepSideMetrics.unavailable(
      RangeRepSide.right,
    ),
  );
}

ExerciseConfig _squatConfig() {
  return buildSquatConfig();
}

ExerciseConfig _plankConfig() {
  return buildPlankConfig();
}

ExerciseConfig _sitUpConfig() {
  return loadExerciseConfig('assets/config/exercises/sit_up.json');
}

ExerciseConfig _bicepsConfig() {
  return loadExerciseConfig('assets/config/exercises/biceps_curl.json');
}

Pose _plankPose({double defaultLikelihood = 0.95}) {
  return buildPlankPose(defaultLikelihood: defaultLikelihood);
}

Pose _squatPose({required double angle, double defaultLikelihood = 0.95}) {
  return buildSquatPose(angle: angle, defaultLikelihood: defaultLikelihood);
}

Pose _sitUpPose({required double primaryAngle, double formAngle = 90}) {
  return buildSitUpPose(primaryAngle: primaryAngle, formAngle: formAngle);
}

Pose _bicepsCurlPose({
  required double leftPrimaryAngle,
  double? rightPrimaryAngle,
  double leftUpperArmDriftAngle = 20,
  double? rightUpperArmDriftAngle,
}) {
  return buildBicepsCurlPose(
    leftPrimaryAngle: leftPrimaryAngle,
    rightPrimaryAngle: rightPrimaryAngle,
    leftUpperArmDriftAngle: leftUpperArmDriftAngle,
    rightUpperArmDriftAngle: rightUpperArmDriftAngle,
  );
}

class _FakeWorkoutController extends WorkoutController {
  _FakeWorkoutController(this.initialState);

  final WorkoutState initialState;
  int manualPauseCallCount = 0;
  int manualResumeCallCount = 0;

  @override
  WorkoutState build() => initialState;

  @override
  void handleManualPause() {
    manualPauseCallCount += 1;
  }

  @override
  void handleManualResume() {
    manualResumeCallCount += 1;
  }

  void publish(WorkoutState next) {
    state = next;
  }
}

class _FakeLiveTrackingController extends LiveTrackingController {
  @override
  LiveTrackingState build() => const LiveTrackingState.tracking();

  void publish(LiveTrackingState next) {
    state = next;
  }
}

class _LiveScreenHarness {
  const _LiveScreenHarness({
    required this.container,
    required this.controller,
    required this.detector,
    required this.clock,
    required this.sessionRepository,
    required this.cameraController,
    required this.navigationObserver,
  });

  final ProviderContainer container;
  final WorkoutController controller;
  final _QueuedPoseDetector detector;
  final _FakeClock clock;
  final _FakeSessionRepository sessionRepository;
  final _FakeCameraController? cameraController;
  final _TestNavigatorObserver navigationObserver;

  Future<void> dispose() async {
    await cameraController?.dispose();
    container.dispose();
  }
}

Future<_LiveScreenHarness> _pumpLiveAnalysisScreen(
  WidgetTester tester, {
  required ExerciseType exerciseType,
  required ExerciseConfig config,
  bool showFinishButton = false,
  bool pushFromLauncher = false,
}) async {
  final detector = _QueuedPoseDetector();
  final clock = _FakeClock();
  final sessionRepository = _FakeSessionRepository();
  final cameraController = showFinishButton ? _FakeCameraController() : null;
  final navigationObserver = _TestNavigatorObserver();
  final container = ProviderContainer(
    overrides: <Override>[
      selectedExerciseProvider.overrideWith((ref) => exerciseType),
      activeAnalysisExerciseProvider.overrideWithValue(exerciseType),
      exerciseConfigProvider.overrideWith((ref) => config),
      poseDetectorProvider.overrideWith((ref) => detector),
      preparationPoseDetectorProvider.overrideWith(
        (ref) => _QueuedPoseDetector(),
      ),
      workoutClockProvider.overrideWithValue(clock.now),
      authRepositoryProvider.overrideWithValue(
        const _FakeAuthRepository(currentUserId: 'test-user'),
      ),
      sessionRepositoryProvider.overrideWithValue(sessionRepository),
      cameraProvider.overrideWith((ref) async {
        if (cameraController != null) {
          return cameraController;
        }

        throw CameraException('test', 'camera unavailable');
      }),
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
        home: pushFromLauncher
            ? Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const ValueKey<String>('open-live-analysis'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LiveAnalysisScreen(),
                          ),
                        );
                      },
                      child: const Text('Open live analysis'),
                    ),
                  ),
                ),
              )
            : const LiveAnalysisScreen(),
        navigatorObservers: <NavigatorObserver>[navigationObserver],
      ),
    ),
  );
  await tester.pump();
  if (pushFromLauncher) {
    await tester.tap(find.byKey(const ValueKey<String>('open-live-analysis')));
    await tester.pump();
  }
  await tester.pump();

  return _LiveScreenHarness(
    container: container,
    controller: container.read(workoutControllerProvider.notifier),
    detector: detector,
    clock: clock,
    sessionRepository: sessionRepository,
    cameraController: cameraController,
    navigationObserver: navigationObserver,
  );
}

Future<void> _establishVisibleHoldOnScreen(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
) async {
  await _analyzePoseFrame(controller, detector, <Pose>[_plankPose()]);
  clock.advance(const Duration(milliseconds: 100));
  await _analyzePoseFrame(controller, detector, <Pose>[_plankPose()]);
  clock.advance(const Duration(seconds: 5));
  await _analyzePoseFrame(controller, detector, <Pose>[_plankPose()]);
}

Future<void> _analyzePoseFrame(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  List<Pose> poses,
) async {
  await analyzeFrame(controller, detector, poses);
}

Future<void> _completeCleanRangeRepOnScreen(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
) async {
  await _analyzePoseFrame(controller, detector, <Pose>[_squatPose(angle: 170)]);
  clock.advance(const Duration(milliseconds: 120));
  await _analyzePoseFrame(controller, detector, <Pose>[_squatPose(angle: 170)]);
  clock.advance(const Duration(milliseconds: 120));
  await _analyzePoseFrame(controller, detector, <Pose>[_squatPose(angle: 170)]);
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _squatPose(angle: 140),
    expectedPhase: 'DESCENDING',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _squatPose(angle: 90),
    expectedPhase: 'PEAK',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _squatPose(angle: 110),
    expectedPhase: 'ASCENDING',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _squatPose(angle: 170),
    expectedPhase: 'NEUTRAL',
    spacing: const Duration(milliseconds: 120),
  );
}

Future<void> _completeCleanSitUpRepOnScreen(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
) async {
  await _analyzePoseFrame(controller, detector, <Pose>[
    _sitUpPose(primaryAngle: 125, formAngle: 90),
  ]);
  clock.advance(const Duration(milliseconds: 120));
  await _analyzePoseFrame(controller, detector, <Pose>[
    _sitUpPose(primaryAngle: 125, formAngle: 90),
  ]);
  clock.advance(const Duration(milliseconds: 120));
  await _analyzePoseFrame(controller, detector, <Pose>[
    _sitUpPose(primaryAngle: 125, formAngle: 90),
  ]);
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _sitUpPose(primaryAngle: 108, formAngle: 90),
    expectedPhase: 'DESCENDING',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _sitUpPose(primaryAngle: 68, formAngle: 90),
    expectedPhase: 'PEAK',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _sitUpPose(primaryAngle: 90, formAngle: 90),
    expectedPhase: 'PEAK',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _sitUpPose(primaryAngle: 92, formAngle: 90),
    expectedPhase: 'ASCENDING',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _sitUpPose(primaryAngle: 121, formAngle: 90),
    expectedPhase: 'NEUTRAL',
    spacing: const Duration(milliseconds: 120),
  );
}

Future<void> _completeCleanBicepsCurlRepOnScreen(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
) async {
  await _analyzePoseFrame(controller, detector, <Pose>[
    _bicepsCurlPose(leftPrimaryAngle: 160, rightPrimaryAngle: 162),
  ]);
  clock.advance(const Duration(milliseconds: 120));
  await _analyzePoseFrame(controller, detector, <Pose>[
    _bicepsCurlPose(leftPrimaryAngle: 160, rightPrimaryAngle: 162),
  ]);
  clock.advance(const Duration(milliseconds: 120));
  await _analyzePoseFrame(controller, detector, <Pose>[
    _bicepsCurlPose(leftPrimaryAngle: 160, rightPrimaryAngle: 162),
  ]);
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _bicepsCurlPose(leftPrimaryAngle: 134, rightPrimaryAngle: 136),
    expectedPhase: 'DESCENDING',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _bicepsCurlPose(leftPrimaryAngle: 72, rightPrimaryAngle: 74),
    expectedPhase: 'PEAK',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _bicepsCurlPose(leftPrimaryAngle: 98, rightPrimaryAngle: 100),
    expectedPhase: 'ASCENDING',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _bicepsCurlPose(leftPrimaryAngle: 160, rightPrimaryAngle: 158),
    expectedPhase: 'NEUTRAL',
    spacing: const Duration(milliseconds: 120),
  );
}

Future<void> _driveRangeRepPoseUntilPhase(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock, {
  required Pose pose,
  required String expectedPhase,
  required Duration spacing,
  int maxFrames = 12,
}) async {
  for (var index = 0; index < maxFrames; index++) {
    await _analyzePoseFrame(controller, detector, <Pose>[pose]);
    if (controller.state.currentPhase == expectedPhase) {
      return;
    }
    if (index < maxFrames - 1) {
      clock.advance(spacing);
    }
  }

  throw TestFailure(
    'Expected phase $expectedPhase, got ${controller.state.currentPhase}',
  );
}

SetupReadinessSnapshot _readyReadinessSnapshot() {
  final now = DateTime.utc(2026, 7, 26, 12);
  return SetupReadinessSnapshot(
    phase: SetupReadinessPhase.ready,
    evidence: const SetupReadinessEvidence(),
    enteredAt: now,
    updatedAt: now,
    diagnostics: const SetupReadinessDiagnosticsSnapshot(
      rawPhase: SetupReadinessPhase.ready,
      framingStatus: null,
      cameraViewStatus: null,
      startPoseStatus: null,
      stableEvidenceDuration: Duration(seconds: 1),
      temporaryLossDuration: Duration.zero,
      stabilityProgress: 1,
      confidence: 1,
    ),
  );
}

class _QueuedPoseDetector extends TestQueuedPoseDetector {}

class _FakeClock extends TestFakeClock {}

class _FakeCameraController extends CameraController {
  _FakeCameraController({
    DeviceOrientation deviceOrientation = DeviceOrientation.portraitUp,
  }) : super(
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
      deviceOrientation: deviceOrientation,
      isStreamingImages: true,
    );
  }

  int startImageStreamCallCount = 0;
  int stopImageStreamCallCount = 0;

  void setDeviceOrientation(DeviceOrientation orientation) {
    value = value.copyWith(deviceOrientation: orientation);
  }

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

class _FakeSessionRepository implements SessionRepository {
  final List<WorkoutSession> savedSessions = <WorkoutSession>[];
  var listSessionsCallCount = 0;
  var saveCallCount = 0;
  var deleteCallCount = 0;
  Completer<void>? saveCompleter;

  @override
  Future<void> saveSession(WorkoutSession session) async {
    saveCallCount += 1;
    final completer = saveCompleter;
    if (completer != null) {
      await completer.future;
      if (identical(saveCompleter, completer)) {
        saveCompleter = null;
      }
    }
    savedSessions.add(session);
  }

  @override
  Future<WorkoutSession?> getSessionById({
    required String ownerId,
    required String sessionId,
  }) async {
    return null;
  }

  @override
  Future<List<WorkoutRep>> listSessionReps({
    required String ownerId,
    required String sessionId,
  }) async {
    return const <WorkoutRep>[];
  }

  @override
  Future<List<WorkoutSession>> listSessions({
    required String ownerId,
    int limit = 20,
    String? exerciseType,
    WorkoutSession? startAfter,
  }) async {
    listSessionsCallCount += 1;
    return List<WorkoutSession>.unmodifiable(savedSessions);
  }

  @override
  Future<void> deleteSession({
    required String ownerId,
    required String sessionId,
  }) async {
    deleteCallCount += 1;
    savedSessions.removeWhere(
      (session) => session.ownerId == ownerId && session.id == sessionId,
    );
  }

  @override
  Future<void> deleteAllSessions({required String ownerId}) async {}
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository({required this.currentUserId});

  @override
  final String? currentUserId;

  @override
  AuthUser? get currentUser => currentUserId == null
      ? null
      : AuthUser(
          uid: currentUserId!,
          email: null,
          displayName: null,
          isAnonymous: true,
        );

  @override
  Stream<AuthUser?> authStateChanges() => Stream<AuthUser?>.value(currentUser);

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteCurrentUser() async {}
}

class _TestNavigatorObserver extends NavigatorObserver {
  var pushCount = 0;
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! DialogRoute<dynamic>) {
      pushCount += 1;
      lastPushedRoute = route;
    }
    super.didPush(route, previousRoute);
  }
}

class _FakeWakelockPlusPlatform extends WakelockPlusPlatformInterface {
  var _enabled = false;

  @override
  bool get isMock => true;

  @override
  Future<void> toggle({required bool enable}) async {
    _enabled = enable;
  }

  @override
  Future<bool> get enabled async => _enabled;
}
