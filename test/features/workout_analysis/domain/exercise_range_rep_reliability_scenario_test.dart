import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_engine_frame_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_rep_summary.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const catalog = ExerciseCatalog();
  const factory = AnalysisEngineFactory();
  final definitions = catalog.definitions
      .where(
        (definition) => definition.analysisEngineKind == EngineKind.rangeRep,
      )
      .toList(growable: false);

  group('Range-rep deterministic reliability scenarios', () {
    test('covers all 22 catalog range-rep exercises', () {
      expect(definitions, hasLength(22));
    });

    test('freezes selected-side and bilateral reliability scope', () {
      expect(
        definitions
            .where(
              (definition) =>
                  definition.analysisRangeRepContract.sideMode ==
                  RangeRepSideMode.selectedSide,
            )
            .length,
        16,
      );
      expect(
        definitions
            .where(
              (definition) =>
                  definition.analysisRangeRepContract.sideMode ==
                  RangeRepSideMode.bilateral,
            )
            .length,
        6,
      );
    });

    for (final definition in definitions) {
      group(definition.id, () {
        late ExerciseConfig config;
        late RangeRepContract contract;
        late TestFakeClock clock;
        late RangeRepAnalysisEngine engine;
        late _RangeRepScenarioMetrics metrics;

        setUp(() {
          config = loadExerciseConfig(definition.analysisConfigAssetPath);
          contract = definition.analysisRangeRepContract;
          clock = TestFakeClock();
          engine = factory.createRangeRep(
            config: config,
            rangeRepContract: contract,
            now: clock.now,
          );
          metrics = _RangeRepScenarioMetrics.fromConfig(
            config: config,
            contract: contract,
          );
        });

        test('peak-position start cannot arm or create a phantom rep', () {
          _repeatMetric(
            engine: engine,
            clock: clock,
            metric: metrics.peak,
            repeats: 4,
          );

          expect(engine.repCount, 0);
          expect(engine.phaseLabel, rangeRepAwaitNeutralPhaseLabel);
        });

        test(
          'active-threshold jitter and wrong-direction motion stay at zero',
          () {
            _armAtNeutral(engine: engine, clock: clock, metrics: metrics);

            for (var index = 0; index < 6; index++) {
              engine.updateDetectionFrame(
                primaryMetric: index.isEven
                    ? metrics.activeJitterNear
                    : metrics.activeJitterFar,
              );
              clock.advance(const Duration(milliseconds: 40));
            }

            _repeatMetric(
              engine: engine,
              clock: clock,
              metric: metrics.wrongDirection,
              repeats: 3,
            );

            expect(engine.repCount, 0);
            expect(
              engine.detectionDiagnosticsSnapshot.hasActiveRepPhase,
              isFalse,
            );
          },
        );

        test('one complete lifecycle counts exactly one rep', () {
          final completion = _completeRep(
            engine: engine,
            clock: clock,
            metrics: metrics,
          );

          expect(engine.repCount, 1);
          expect(completion.completedRepDetectionData, isNotNull);
          expect(completion.completedRepDetectionData!.repIndex, 1);
          expect(completion.completedRepDetectionData!.primaryRom, isNotNull);
          expect(
            completion.completedRepDetectionData!.primaryRom!,
            greaterThan(0),
          );
        });

        test('partial active excursion that never reaches peak is aborted', () {
          _armAtNeutral(engine: engine, clock: clock, metrics: metrics);
          _confirmMetric(engine: engine, clock: clock, metric: metrics.active);

          final abort = _confirmMetric(
            engine: engine,
            clock: clock,
            metric: metrics.neutral,
          );

          expect(abort.repAborted, isTrue);
          expect(engine.repCount, 0);
          expect(
            engine.detectionDiagnosticsSnapshot.hasActiveRepPhase,
            isFalse,
          );
        });

        test('brief compatible visibility gap preserves the active rep', () {
          _armAtNeutral(engine: engine, clock: clock, metrics: metrics);
          _confirmMetric(engine: engine, clock: clock, metric: metrics.active);

          engine.beginBriefVisibilityGap();
          clock.advance(const Duration(milliseconds: 400));
          final recovery = engine.resumeAfterBriefVisibilityGap(
            primaryMetric: metrics.active,
          );

          expect(
            recovery.disposition,
            VisibilityGapResumeDisposition.compatible,
          );
          expect(
            recovery.appliedGapDuration,
            const Duration(milliseconds: 400),
          );

          _confirmMetric(engine: engine, clock: clock, metric: metrics.peak);
          _confirmMetric(
            engine: engine,
            clock: clock,
            metric: metrics.returning,
          );
          final completion = _confirmMetric(
            engine: engine,
            clock: clock,
            metric: metrics.neutral,
          );

          expect(engine.repCount, 1);
          expect(completion.completedRepDetectionData, isNotNull);
        });

        test('hard resync clears only the active rep context', () {
          _completeRep(engine: engine, clock: clock, metrics: metrics);
          expect(engine.repCount, 1);

          _confirmMetric(engine: engine, clock: clock, metric: metrics.active);
          expect(engine.detectionDiagnosticsSnapshot.hasActiveRepPhase, isTrue);

          engine.interrupt(reason: 'deterministic hard resync');

          expect(engine.repCount, 1);
          expect(engine.phaseLabel, rangeRepAwaitNeutralPhaseLabel);
          expect(
            engine.detectionDiagnosticsSnapshot.hasActiveRepPhase,
            isFalse,
          );

          _repeatMetric(
            engine: engine,
            clock: clock,
            metric: metrics.peak,
            repeats: 3,
          );
          expect(engine.repCount, 1);

          _completeRep(engine: engine, clock: clock, metrics: metrics);
          expect(engine.repCount, 2);
        });

        test(
          'reset clears session count and requires neutral reacquisition',
          () {
            _completeRep(engine: engine, clock: clock, metrics: metrics);
            expect(engine.repCount, 1);

            engine.reset();

            expect(engine.repCount, 0);
            expect(engine.phaseLabel, rangeRepAwaitNeutralPhaseLabel);

            _repeatMetric(
              engine: engine,
              clock: clock,
              metric: metrics.peak,
              repeats: 3,
            );
            expect(engine.repCount, 0);

            _completeRep(engine: engine, clock: clock, metrics: metrics);
            expect(engine.repCount, 1);
          },
        );

        test(
          'validation accepts sufficient ROM and rejects insufficient ROM',
          () {
            final validationConfig =
                definition.analysisRangeRepValidationConfig;
            final policy = RangeRepValidationPolicy(config: validationConfig);

            final validResult = policy.evaluate(
              _validationSummary(
                config: validationConfig,
                metrics: metrics,
                hasSufficientRom: true,
              ),
            );
            final insufficientRomResult = policy.evaluate(
              _validationSummary(
                config: validationConfig,
                metrics: metrics,
                hasSufficientRom: false,
              ),
            );

            expect(validResult.status, RangeRepValidationStatus.valid);
            expect(
              insufficientRomResult.status,
              RangeRepValidationStatus.invalid,
            );
            expect(
              insufficientRomResult.reasons,
              contains(RangeRepValidationReason.insufficientRom),
            );
          },
        );
      });
    }
  });
}

const Duration _confirmationStep = Duration(milliseconds: 120);

// Mirrors GenericRepEngineConfig.peakExitMargin so the deterministic fixture
// uses a distinct sample that can actually confirm the returning phase.
const double _genericPeakExitMargin = 8.0;

class _RangeRepScenarioMetrics {
  const _RangeRepScenarioMetrics({
    required this.neutral,
    required this.active,
    required this.peak,
    required this.returning,
    required this.wrongDirection,
    required this.activeJitterNear,
    required this.activeJitterFar,
  });

  factory _RangeRepScenarioMetrics.fromConfig({
    required ExerciseConfig config,
    required RangeRepContract contract,
  }) {
    switch (contract.primaryMetricDirection) {
      case RangeRepPrimaryMetricDirection.decreasingToPeak:
        return _RangeRepScenarioMetrics(
          neutral: config.thresholdNeutral + 10.0,
          active: config.thresholdActive - 5.0,
          peak: config.thresholdPeak - 10.0,
          returning:
              (config.thresholdNeutral +
                  config.thresholdPeak +
                  _genericPeakExitMargin) /
              2.0,
          wrongDirection: (config.thresholdNeutral + 25.0)
              .clamp(0.0, 180.0)
              .toDouble(),
          activeJitterNear: config.thresholdActive + 2.0,
          activeJitterFar: config.thresholdActive - 2.0,
        );
      case RangeRepPrimaryMetricDirection.increasingToPeak:
        return _RangeRepScenarioMetrics(
          neutral: config.thresholdNeutral - 10.0,
          active: config.thresholdActive + 5.0,
          peak: config.thresholdPeak + 10.0,
          returning:
              (config.thresholdNeutral +
                  config.thresholdPeak -
                  _genericPeakExitMargin) /
              2.0,
          wrongDirection: (config.thresholdNeutral - 25.0)
              .clamp(0.0, 180.0)
              .toDouble(),
          activeJitterNear: config.thresholdActive - 2.0,
          activeJitterFar: config.thresholdActive + 2.0,
        );
    }
  }

  final double neutral;
  final double active;
  final double peak;
  final double returning;
  final double wrongDirection;
  final double activeJitterNear;
  final double activeJitterFar;
}

void _armAtNeutral({
  required RangeRepAnalysisEngine engine,
  required TestFakeClock clock,
  required _RangeRepScenarioMetrics metrics,
}) {
  _confirmMetric(engine: engine, clock: clock, metric: metrics.neutral);
  expect(engine.phaseLabel, 'NEUTRAL');
}

RangeRepEngineFrameResult _completeRep({
  required RangeRepAnalysisEngine engine,
  required TestFakeClock clock,
  required _RangeRepScenarioMetrics metrics,
}) {
  if (engine.phaseLabel == rangeRepAwaitNeutralPhaseLabel) {
    _armAtNeutral(engine: engine, clock: clock, metrics: metrics);
  }

  _confirmMetric(engine: engine, clock: clock, metric: metrics.active);
  _confirmMetric(engine: engine, clock: clock, metric: metrics.peak);
  _confirmMetric(engine: engine, clock: clock, metric: metrics.returning);
  return _confirmMetric(engine: engine, clock: clock, metric: metrics.neutral);
}

RangeRepEngineFrameResult _confirmMetric({
  required RangeRepAnalysisEngine engine,
  required TestFakeClock clock,
  required double metric,
}) {
  engine.updateDetectionFrame(primaryMetric: metric);
  clock.advance(_confirmationStep);
  return engine.updateDetectionFrame(primaryMetric: metric);
}

void _repeatMetric({
  required RangeRepAnalysisEngine engine,
  required TestFakeClock clock,
  required double metric,
  required int repeats,
}) {
  for (var index = 0; index < repeats; index++) {
    engine.updateDetectionFrame(primaryMetric: metric);
    clock.advance(_confirmationStep);
  }
}

RangeRepRepSummary _validationSummary({
  required RangeRepValidationConfig config,
  required _RangeRepScenarioMetrics metrics,
  required bool hasSufficientRom,
}) {
  final minimumDelta = config.minAcceptableRomDelta;
  final primaryRom = minimumDelta == null
      ? (metrics.neutral - metrics.peak).abs()
      : hasSufficientRom
      ? minimumDelta + 5.0
      : (minimumDelta - 1.0).clamp(0.0, double.infinity).toDouble();
  final minAngle = minimumDelta == null
      ? hasSufficientRom
            ? config.minAcceptableRomAngle - 5.0
            : config.minAcceptableRomAngle + 1.0
      : metrics.neutral < metrics.peak
      ? metrics.neutral
      : metrics.peak;

  return RangeRepRepSummary(
    repIndex: 1,
    minAngle: minAngle,
    worstFormMetric: 180.0,
    descentDuration: Duration(milliseconds: config.minDescentMillis + 100),
    ascentDuration: Duration(milliseconds: config.minAscentMillis + 100),
    hadFormViolation: false,
    hadCoverageDrop: false,
    switchedSideDuringRep: false,
    completedPhaseSequence: true,
    startAngle: metrics.neutral,
    primaryRom: primaryRom,
  );
}
