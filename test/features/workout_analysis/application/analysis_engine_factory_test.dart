import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_signal_role.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/alternating_rep_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_frame.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/stability_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hollow_hold_variation.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  const factory = AnalysisEngineFactory();
  final squatConfig = ExerciseConfig(
    name: 'Squat',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160.0,
    thresholdActive: 150.0,
    thresholdPeak: 95.0,
  );
  final pushUpConfig = ExerciseConfig(
    name: 'Push-Up',
    primaryJoint: PoseLandmarkType.leftElbow,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftWrist,
    thresholdNeutral: 165.0,
    thresholdActive: 135.0,
    thresholdPeak: 95.0,
  );
  final sitUpConfig = ExerciseConfig(
    name: 'Sit-up',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftKnee,
    thresholdNeutral: 160.0,
    thresholdActive: 130.0,
    thresholdPeak: 90.0,
  );
  final lyingLegRaiseConfig = ExerciseConfig(
    name: 'Lying Leg Raise',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftKnee,
    thresholdNeutral: 160.0,
    thresholdActive: 145.0,
    thresholdPeak: 105.0,
  );
  final lungeConfig = ExerciseConfig(
    name: 'Stationary Lunge',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160.0,
    thresholdActive: 145.0,
    thresholdPeak: 115.0,
  );
  final plankConfig = _holdConfig();
  final hollowHoldConfig = _hollowHoldConfig();

  group('AnalysisEngineFactory', () {
    test('rejects range-rep creation without a contract', () {
      expect(
        () => factory.create(
          engineKind: EngineKind.rangeRep,
          config: squatConfig,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('rangeRepContract'),
          ),
        ),
      );
    });

    test('accepts the squat range-rep contract', () {
      final RangeRepAnalysisEngine engine = factory.createRangeRep(
        config: squatConfig,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(engine, isA<RangeRepEngine>());
    });

    test('accepts the push-up range-rep contract', () {
      final RangeRepAnalysisEngine engine = factory.createRangeRep(
        config: pushUpConfig,
        rangeRepContract: RangeRepContracts.pushUp,
      );

      expect(engine, isA<RangeRepEngine>());
    });

    test('accepts the sit-up range-rep contract', () {
      final RangeRepAnalysisEngine engine = factory.createRangeRep(
        config: sitUpConfig,
        rangeRepContract: RangeRepContracts.sitUp,
      );

      expect(engine, isA<RangeRepEngine>());
    });

    test(
      'existing range-rep exercises share the configurable rep lifecycle',
      () {
        final scenarios =
            <
              ({
                ExerciseConfig config,
                RangeRepContract contract,
                double neutral,
                double active,
                double peak,
                double returning,
              })
            >[
              (
                config: squatConfig,
                contract: RangeRepContracts.squat,
                neutral: 170,
                active: 140,
                peak: 90,
                returning: 110,
              ),
              (
                config: pushUpConfig,
                contract: RangeRepContracts.pushUp,
                neutral: 175,
                active: 125,
                peak: 85,
                returning: 110,
              ),
              (
                config: sitUpConfig,
                contract: RangeRepContracts.sitUp,
                neutral: 170,
                active: 120,
                peak: 80,
                returning: 105,
              ),
            ];

        for (final scenario in scenarios) {
          final clock = _RangeRepTestClock();
          final engine = factory.createRangeRep(
            config: scenario.config,
            rangeRepContract: scenario.contract,
            now: clock.now,
          );

          _confirmRangeRepMetric(clock, engine, scenario.neutral, 120);
          _confirmRangeRepMetric(clock, engine, scenario.active, 100);
          _confirmRangeRepMetric(clock, engine, scenario.peak, 100);
          _confirmRangeRepMetric(clock, engine, scenario.returning, 100);
          _confirmRangeRepMetric(clock, engine, scenario.neutral, 120);

          expect(
            engine.repCount,
            1,
            reason:
                '${scenario.config.name} should complete through the shared '
                'generic repetition lifecycle.',
          );
        }
      },
    );

    test(
      'lying leg raise accepts a literal peak crossing across sparse sampling',
      () {
        final clock = _RangeRepTestClock();
        final engine = factory.createRangeRep(
          config: lyingLegRaiseConfig,
          rangeRepContract: RangeRepContracts.lyingLegRaise,
          now: clock.now,
        );

        _confirmRangeRepMetric(clock, engine, 170, 120);
        _confirmRangeRepMetric(clock, engine, 140, 100);

        engine.updateDetectionFrame(primaryMetric: 104);
        clock.advance(const Duration(milliseconds: 100));
        engine.updateDetectionFrame(primaryMetric: 110);

        _confirmRangeRepMetric(clock, engine, 120, 100);
        _confirmRangeRepMetric(clock, engine, 170, 120);

        expect(engine.repCount, 1);
      },
    );

    test('lying leg raise still rejects a shallow 109-degree partial', () {
      final clock = _RangeRepTestClock();
      final engine = factory.createRangeRep(
        config: lyingLegRaiseConfig,
        rangeRepContract: RangeRepContracts.lyingLegRaise,
        now: clock.now,
      );

      _confirmRangeRepMetric(clock, engine, 170, 120);
      _confirmRangeRepMetric(clock, engine, 140, 100);
      _confirmRangeRepMetric(clock, engine, 109, 100);
      _confirmRangeRepMetric(clock, engine, 120, 100);
      _confirmRangeRepMetric(clock, engine, 170, 120);

      expect(engine.repCount, 0);
    });

    test('Day 11 range-rep exercises use the shared increasing lifecycle', () {
      final scenarios =
          <
            ({
              ExerciseConfig config,
              RangeRepContract contract,
              double neutral,
              double active,
              double peak,
              double returning,
            })
          >[
            (
              config: _increasingRangeRepConfig(
                name: 'Calf Raise',
                neutral: 85,
                active: 100,
                peak: 115,
              ),
              contract: RangeRepContracts.calfRaise,
              neutral: 80,
              active: 105,
              peak: 120,
              returning: 100,
            ),
            (
              config: _increasingRangeRepConfig(
                name: 'Front Raise',
                neutral: 15,
                active: 35,
                peak: 80,
              ),
              contract: RangeRepContracts.frontRaise,
              neutral: 10,
              active: 45,
              peak: 90,
              returning: 50,
            ),
            (
              config: _increasingRangeRepConfig(
                name: 'Glute Bridge',
                neutral: 105,
                active: 125,
                peak: 155,
              ),
              contract: RangeRepContracts.gluteBridge,
              neutral: 100,
              active: 135,
              peak: 160,
              returning: 130,
            ),
            (
              config: _increasingRangeRepConfig(
                name: 'Jumping Jack',
                neutral: 20,
                active: 55,
                peak: 135,
              ),
              contract: RangeRepContracts.jumpingJack,
              neutral: 15,
              active: 70,
              peak: 145,
              returning: 70,
            ),
          ];

      for (final scenario in scenarios) {
        final clock = _RangeRepTestClock();
        final engine = factory.createRangeRep(
          config: scenario.config,
          rangeRepContract: scenario.contract,
          now: clock.now,
        );

        final initialNeutralMillis =
            scenario
                    .contract
                    .initialNeutralConfirmationDuration
                    .inMilliseconds >
                120
            ? scenario
                  .contract
                  .initialNeutralConfirmationDuration
                  .inMilliseconds
            : 120;
        _confirmRangeRepMetric(
          clock,
          engine,
          scenario.neutral,
          initialNeutralMillis,
        );
        _confirmRangeRepMetric(clock, engine, scenario.active, 100);
        _confirmRangeRepMetric(clock, engine, scenario.peak, 100);
        _confirmRangeRepMetric(clock, engine, scenario.returning, 100);
        _confirmRangeRepMetric(clock, engine, scenario.neutral, 120);

        expect(engine.repCount, 1, reason: scenario.config.name);
      }
    });

    test('rejects hold creation without a contract', () {
      expect(
        () => factory.create(engineKind: EngineKind.hold, config: plankConfig),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('holdContract'),
          ),
        ),
      );
    });

    test('rejects hold creation without holdSignals config', () {
      expect(
        () => factory.create(
          engineKind: EngineKind.hold,
          config: _holdConfig(includeHoldSignals: false),
          holdContract: HoldContracts.plankFamily,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('holdSignals'),
          ),
        ),
      );
    });

    test(
      'creates Hollow Hold engine using variation-owned required signals',
      () {
        final engine = factory.create(
          engineKind: EngineKind.hold,
          config: _hollowHoldConfig(),
          holdContract: HoldContracts.hollowHoldForVariation(
            HollowHoldVariation.tuck,
          ),
        );

        expect(engine, isA<HoldEngine>());
      },
    );

    test('rejects hollow hold creation without hollowHoldPosture config', () {
      expect(
        () => factory.create(
          engineKind: EngineKind.hold,
          config: _hollowHoldConfig(includeHollowHoldPosture: false),
          holdContract: HoldContracts.hollowHold,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('hollowHoldPosture'),
          ),
        ),
      );
    });

    test(
      'rejects plank hold creation when the contract is missing extension',
      () {
        expect(
          () => factory.createHold(
            config: plankConfig,
            holdContract: HoldContract(
              family: HoldAnalysisFamily.plank,
              requiredSignals: const <HoldSignal>{
                HoldSignal.alignment,
                HoldSignal.support,
              },
              signalRoles: _testHoldSignalRoles(const <HoldSignal>{
                HoldSignal.alignment,
                HoldSignal.support,
              }),
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains(HoldSignal.extension.name),
            ),
          ),
        );
      },
    );

    for (final scenario in <({HoldSignal signal, ExerciseConfig config})>[
      (
        signal: HoldSignal.alignment,
        config: _holdConfig(missingSignals: <HoldSignal>{HoldSignal.alignment}),
      ),
      (
        signal: HoldSignal.support,
        config: _holdConfig(missingSignals: <HoldSignal>{HoldSignal.support}),
      ),
      (
        signal: HoldSignal.extension,
        config: _holdConfig(missingSignals: <HoldSignal>{HoldSignal.extension}),
      ),
    ]) {
      test('rejects hold creation when ${scenario.signal.name} is missing', () {
        expect(
          () => factory.create(
            engineKind: EngineKind.hold,
            config: scenario.config,
            holdContract: HoldContracts.plankFamily,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains(scenario.signal.name),
            ),
          ),
        );
      });
    }

    for (final scenario in <({HoldSignal signal, ExerciseConfig config})>[
      (
        signal: HoldSignal.compression,
        config: _hollowHoldConfig(
          missingSignals: <HoldSignal>{HoldSignal.compression},
        ),
      ),
      (
        signal: HoldSignal.armExtension,
        config: _hollowHoldConfig(
          missingSignals: <HoldSignal>{HoldSignal.armExtension},
        ),
      ),
      (
        signal: HoldSignal.kneeExtension,
        config: _hollowHoldConfig(
          missingSignals: <HoldSignal>{HoldSignal.kneeExtension},
        ),
      ),
    ]) {
      test(
        'rejects hollow hold creation when ${scenario.signal.name} is missing',
        () {
          expect(
            () => factory.create(
              engineKind: EngineKind.hold,
              config: scenario.config,
              holdContract: HoldContracts.hollowHold,
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                contains(scenario.signal.name),
              ),
            ),
          );
        },
      );
    }

    test('creates a hold engine for a valid plank contract and config', () {
      final HoldAnalysisEngine engine = factory.createHold(
        config: plankConfig,
        holdContract: HoldContracts.plankFamily,
      );

      expect(engine, isA<HoldEngine>());
    });

    test(
      'hold factory composition exposes the supplemental stability engine',
      () {
        final HoldAnalysisEngine engine = factory.createHold(
          config: plankConfig,
          holdContract: HoldContracts.plankFamily,
        );

        expect(engine, isA<StabilityMetricsSource<HoldSignal>>());
      },
    );

    test(
      'creates a hold engine for a valid hollow hold contract and config',
      () {
        final HoldAnalysisEngine engine = factory.createHold(
          config: hollowHoldConfig,
          holdContract: HoldContracts.hollowHold,
        );

        expect(engine, isA<HoldEngine>());
      },
    );

    test('creates a hold engine for the Day 11 side plank contract', () {
      final HoldAnalysisEngine engine = factory.createHold(
        config: plankConfig,
        holdContract: HoldContracts.sidePlank,
      );

      expect(engine, isA<HoldEngine>());
    });

    test('creates a hold engine for a valid wall sit contract and config', () {
      final HoldAnalysisEngine engine = factory.createHold(
        config: _wallSitConfig(),
        holdContract: HoldContracts.wallSit,
      );

      expect(engine, isA<HoldEngine>());
      expect(
        engine.diagnosticsSnapshot.targetSignalValues.valueFor(
          HoldSignal.kneeFlexion,
        ),
        100.0,
      );
    });

    test(
      'side plank stacking validates support without changing stability inputs',
      () {
        final HoldAnalysisEngine engine = factory.createHold(
          config: plankConfig,
          holdContract: HoldContracts.sidePlank,
        );
        final stabilitySource = engine as StabilityMetricsSource<HoldSignal>;
        final frame = AnalysisFrame(
          primaryMetric: 170.0,
          formMetric: 170.0,
          holdSignalValues: HoldSignalValues(
            values: <HoldSignal, double>{
              HoldSignal.alignment: 170.0,
              HoldSignal.support: 90.0,
              HoldSignal.supportStacking: 1.0,
              HoldSignal.extension: 170.0,
            },
          ),
        );

        engine.update(frame);
        engine.update(frame);

        expect(engine.diagnosticsSnapshot.isHolding, isTrue);
        expect(
          engine.diagnosticsSnapshot.targetSignalValues.valueFor(
            HoldSignal.supportStacking,
          ),
          closeTo(1 / 1.41421356237, 0.001),
        );
        expect(
          stabilitySource.currentStability?.signalSummaries.keys,
          containsAll(<HoldSignal>[
            HoldSignal.alignment,
            HoldSignal.support,
            HoldSignal.extension,
          ]),
        );
        expect(
          stabilitySource.currentStability?.signalSummaries.keys,
          isNot(contains(HoldSignal.supportStacking)),
        );
      },
    );

    test('factory wiring injects the plank posture policy targets', () {
      final HoldAnalysisEngine engine = factory.createHold(
        config: plankConfig,
        holdContract: HoldContracts.plankFamily,
      );

      expect(engine.diagnosticsSnapshot.bodyLineTargetAngle, 168.0);

      engine.update(
        AnalysisFrame(
          primaryMetric: 170.0,
          formMetric: 170.0,
          bodyLineAngle: 170.0,
          armSupportAngle: 90.0,
          legExtensionAngle: 170.0,
        ),
      );

      expect(engine.diagnosticsSnapshot.bodyLineTargetAngle, 166.0);
    });

    test('factory wiring injects the hollow hold posture policy targets', () {
      final HoldAnalysisEngine engine = factory.createHold(
        config: hollowHoldConfig,
        holdContract: HoldContracts.hollowHold,
      );

      expect(
        engine.diagnosticsSnapshot.targetSignalValues.valueFor(
          HoldSignal.compression,
        ),
        165.0,
      );
      expect(
        engine.diagnosticsSnapshot.targetSignalValues.valueFor(
          HoldSignal.armExtension,
        ),
        135.0,
      );
      expect(
        engine.diagnosticsSnapshot.targetSignalValues.valueFor(
          HoldSignal.kneeExtension,
        ),
        165.0,
      );

      engine.update(
        AnalysisFrame(
          primaryMetric: 150.0,
          formMetric: 150.0,
          holdSignalValues: HoldSignalValues(
            values: <HoldSignal, double>{
              HoldSignal.compression: 150.0,
              HoldSignal.armExtension: 160.0,
              HoldSignal.kneeExtension: 170.0,
            },
          ),
        ),
      );

      expect(
        engine.diagnosticsSnapshot.targetSignalValues.valueFor(
          HoldSignal.compression,
        ),
        169.0,
      );
    });

    test('generic hold creation keeps the plank hold engine path', () {
      final AnalysisEngine engine = factory.create(
        engineKind: EngineKind.hold,
        config: plankConfig,
        holdContract: HoldContracts.plankFamily,
      );

      expect(engine, isA<HoldEngine>());
      expect(engine, isA<HoldAnalysisEngine>());
    });

    test('generic hold creation keeps the hollow hold engine path', () {
      final AnalysisEngine engine = factory.create(
        engineKind: EngineKind.hold,
        config: hollowHoldConfig,
        holdContract: HoldContracts.hollowHold,
      );

      expect(engine, isA<HoldEngine>());
      expect(engine, isA<HoldAnalysisEngine>());
    });

    test('runs the lunge family through the alternating-rep engine', () {
      final clock = _RangeRepTestClock();
      final engine = factory.createAlternatingRep(
        config: lungeConfig,
        rangeRepContract: RangeRepContracts.stationaryLunge,
        minimumRom: 20.0,
        now: clock.now,
      );

      _confirmAlternatingMetrics(
        clock,
        engine,
        left: 170,
        right: 170,
        milliseconds: 120,
      );
      _confirmAlternatingMetrics(
        clock,
        engine,
        left: 135,
        right: 170,
        milliseconds: 100,
      );
      _confirmAlternatingMetrics(
        clock,
        engine,
        left: 100,
        right: 170,
        milliseconds: 100,
      );
      _confirmAlternatingMetrics(
        clock,
        engine,
        left: 130,
        right: 170,
        milliseconds: 100,
      );
      _confirmAlternatingMetrics(
        clock,
        engine,
        left: 170,
        right: 170,
        milliseconds: 120,
      );

      expect(engine, isA<AlternatingRepEngine>());
      expect(engine.leftRepCount, 1);
      expect(engine.rightRepCount, 0);
      expect(engine.lastCompletedSide, AlternatingRepSide.left);
    });

    test(
      'generic creation keeps alternating-rep on the side-aware factory path',
      () {
        expect(
          () => factory.create(
            engineKind: EngineKind.alternatingRep,
            config: lungeConfig,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('side-aware'),
            ),
          ),
        );
      },
    );
  });
}

Map<HoldSignal, Set<AnalysisSignalRole>> _testHoldSignalRoles(
  Iterable<HoldSignal> signals,
) {
  return <HoldSignal, Set<AnalysisSignalRole>>{
    for (final signal in signals)
      signal: <AnalysisSignalRole>{AnalysisSignalRole.detection},
  };
}

ExerciseConfig _increasingRangeRepConfig({
  required String name,
  required double neutral,
  required double active,
  required double peak,
}) {
  return ExerciseConfig(
    name: name,
    primaryJoint: PoseLandmarkType.leftShoulder,
    joint1: PoseLandmarkType.leftElbow,
    joint2: PoseLandmarkType.leftHip,
    thresholdNeutral: neutral,
    thresholdActive: active,
    thresholdPeak: peak,
  );
}

ExerciseConfig _holdConfig({
  bool includeHoldSignals = true,
  Set<HoldSignal> missingSignals = const <HoldSignal>{},
}) {
  final holdSignals = includeHoldSignals
      ? HoldSignalExtractionConfig(
          referenceSide: HoldSide.left,
          alignment: missingSignals.contains(HoldSignal.alignment)
              ? null
              : const PoseAngleLandmarks(
                  first: PoseLandmarkType.leftShoulder,
                  middle: PoseLandmarkType.leftHip,
                  last: PoseLandmarkType.leftAnkle,
                ),
          support: missingSignals.contains(HoldSignal.support)
              ? null
              : const PoseAngleLandmarks(
                  first: PoseLandmarkType.leftShoulder,
                  middle: PoseLandmarkType.leftElbow,
                  last: PoseLandmarkType.leftWrist,
                ),
          extension: missingSignals.contains(HoldSignal.extension)
              ? null
              : const PoseAngleLandmarks(
                  first: PoseLandmarkType.leftHip,
                  middle: PoseLandmarkType.leftKnee,
                  last: PoseLandmarkType.leftAnkle,
                ),
        )
      : null;

  return ExerciseConfig(
    name: 'Plank',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160.0,
    thresholdActive: 168.0,
    thresholdPeak: 0.0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160.0,
      bodyLineEntryAngle: 168.0,
      bodyLineSustainAngle: 166.0,
      armSupportMinAngle: 60.0,
      armSupportMaxAngle: 120.0,
      legExtensionMinAngle: 165.0,
      breakGraceDuration: Duration(milliseconds: 300),
    ),
    holdSignals: holdSignals,
  );
}

ExerciseConfig _wallSitConfig() {
  return ExerciseConfig(
    name: 'Wall Sit',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 130.0,
    thresholdActive: 120.0,
    thresholdPeak: 0.0,
    wallSitPosture: const WallSitPostureConfig(
      activeKneeMaxAngle: 130.0,
      kneeMinAngle: 80.0,
      kneeMaxAngle: 120.0,
      hipMinAngle: 70.0,
      hipMaxAngle: 120.0,
      torsoMinAngle: 155.0,
      breakGraceDuration: Duration(milliseconds: 500),
    ),
    holdSignals: HoldSignalExtractionConfig(
      referenceSide: HoldSide.left,
      definitions: const <HoldSignal, PoseAngleLandmarks>{
        HoldSignal.kneeFlexion: PoseAngleLandmarks(
          first: PoseLandmarkType.leftHip,
          middle: PoseLandmarkType.leftKnee,
          last: PoseLandmarkType.leftAnkle,
        ),
        HoldSignal.hipFlexion: PoseAngleLandmarks(
          first: PoseLandmarkType.leftShoulder,
          middle: PoseLandmarkType.leftHip,
          last: PoseLandmarkType.leftKnee,
        ),
        HoldSignal.torsoAlignment: PoseAngleLandmarks(
          first: PoseLandmarkType.leftEar,
          middle: PoseLandmarkType.leftShoulder,
          last: PoseLandmarkType.leftHip,
        ),
      },
    ),
  );
}

ExerciseConfig _hollowHoldConfig({
  bool includeHoldSignals = true,
  bool includeHollowHoldPosture = true,
  Set<HoldSignal> missingSignals = const <HoldSignal>{},
}) {
  final holdSignals = includeHoldSignals
      ? HoldSignalExtractionConfig(
          referenceSide: HoldSide.left,
          compression: missingSignals.contains(HoldSignal.compression)
              ? null
              : const PoseAngleLandmarks(
                  first: PoseLandmarkType.leftShoulder,
                  middle: PoseLandmarkType.leftHip,
                  last: PoseLandmarkType.leftAnkle,
                ),
          armExtension: missingSignals.contains(HoldSignal.armExtension)
              ? null
              : const PoseAngleLandmarks(
                  first: PoseLandmarkType.leftHip,
                  middle: PoseLandmarkType.leftShoulder,
                  last: PoseLandmarkType.leftWrist,
                ),
          kneeExtension: missingSignals.contains(HoldSignal.kneeExtension)
              ? null
              : const PoseAngleLandmarks(
                  first: PoseLandmarkType.leftHip,
                  middle: PoseLandmarkType.leftKnee,
                  last: PoseLandmarkType.leftAnkle,
                ),
        )
      : null;

  return ExerciseConfig(
    name: 'Hollow Hold',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 170.0,
    thresholdActive: 165.0,
    thresholdPeak: 0.0,
    hollowHoldPosture: includeHollowHoldPosture
        ? const HollowHoldPostureConfig(
            activePostureMaxAngle: 170.0,
            compressionEntryMaxAngle: 165.0,
            compressionSustainMaxAngle: 169.0,
            armExtensionMinAngle: 135.0,
            kneeExtensionMinAngle: 165.0,
            breakGraceDuration: Duration(milliseconds: 300),
          )
        : null,
    holdSignals: holdSignals,
  );
}

void _confirmAlternatingMetrics(
  _RangeRepTestClock clock,
  AlternatingRepEngine engine, {
  required double left,
  required double right,
  required int milliseconds,
}) {
  engine.update(leftPrimaryMetric: left, rightPrimaryMetric: right);
  clock.advance(Duration(milliseconds: milliseconds));
  engine.update(leftPrimaryMetric: left, rightPrimaryMetric: right);
}

void _confirmRangeRepMetric(
  _RangeRepTestClock clock,
  RangeRepAnalysisEngine engine,
  double metric,
  int milliseconds,
) {
  engine.updateDetectionFrame(primaryMetric: metric);
  clock.advance(Duration(milliseconds: milliseconds));
  engine.updateDetectionFrame(primaryMetric: metric);
}

class _RangeRepTestClock {
  DateTime value = DateTime(2026, 1, 1);

  DateTime now() => value;

  void advance(Duration duration) {
    value = value.add(duration);
  }
}
