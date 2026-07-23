import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_frame.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const catalog = ExerciseCatalog();
  const factory = AnalysisEngineFactory();
  final definitions = catalog.definitions
      .where((definition) => definition.analysisEngineKind == EngineKind.hold)
      .toList(growable: false);

  group('Hold deterministic reliability scenarios', () {
    test('covers all 4 catalog hold exercises', () {
      expect(definitions, hasLength(4));
    });

    for (final definition in definitions) {
      group(definition.id, () {
        late ExerciseConfig config;
        late HoldContract contract;
        late TestFakeClock clock;
        late HoldAnalysisEngine engine;
        late HoldSignalValues validSignals;
        late HoldSignalValues invalidStartSignals;
        late HoldSignalValues graceEligibleSignals;
        late Duration breakGraceDuration;

        setUp(() {
          config = loadExerciseConfig(definition.analysisConfigAssetPath);
          contract = definition.analysisHoldContract;
          clock = TestFakeClock();
          engine = factory.createHold(
            config: config,
            holdContract: contract,
            now: clock.now,
          );
          validSignals = _validHoldSignals(config: config, contract: contract);
          invalidStartSignals = _invalidStartSignals(
            config: config,
            contract: contract,
          );
          graceEligibleSignals = _graceEligibleSignals(
            config: config,
            contract: contract,
          );
          breakGraceDuration = _breakGraceDuration(
            config: config,
            contract: contract,
          );
        });

        test('invalid starting posture never starts hidden hold time', () {
          engine.update(_holdFrame(invalidStartSignals));
          clock.advance(const Duration(seconds: 2));
          engine.update(_holdFrame(invalidStartSignals));

          expect(engine.diagnosticsSnapshot.isHolding, isFalse);
          expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
          expect(engine.diagnosticsSnapshot.bestHoldSeconds, 0.0);
        });

        test(
          'valid posture starts hold and accumulates deterministic time',
          () {
            engine.update(_holdFrame(validSignals));
            clock.advance(const Duration(seconds: 2));
            engine.update(_holdFrame(validSignals));

            expect(engine.diagnosticsSnapshot.isHolding, isTrue);
            expect(
              engine.diagnosticsSnapshot.currentHoldSeconds,
              closeTo(2.0, 0.001),
            );
          },
        );

        test('transient form break inside grace window preserves the hold', () {
          engine.update(_holdFrame(validSignals));
          clock.advance(const Duration(seconds: 1));
          engine.update(_holdFrame(validSignals));

          engine.update(_holdFrame(graceEligibleSignals));
          expect(engine.diagnosticsSnapshot.isFormBreakGraceActive, isTrue);
          expect(engine.diagnosticsSnapshot.isHolding, isTrue);

          final recoveryDelay = breakGraceDuration.inMilliseconds > 2
              ? breakGraceDuration - const Duration(milliseconds: 2)
              : Duration.zero;
          clock.advance(recoveryDelay);
          engine.update(_holdFrame(validSignals));

          expect(engine.diagnosticsSnapshot.isFormBreakGraceActive, isFalse);
          expect(engine.diagnosticsSnapshot.isHolding, isTrue);
          expect(engine.diagnosticsSnapshot.hadFormBreak, isFalse);
        });

        test(
          'persistent grace-eligible form break eventually ends the hold',
          () {
            engine.update(_holdFrame(validSignals));
            clock.advance(const Duration(seconds: 1));
            engine.update(_holdFrame(validSignals));

            engine.update(_holdFrame(graceEligibleSignals));
            clock.advance(breakGraceDuration);
            engine.update(_holdFrame(graceEligibleSignals));

            expect(engine.diagnosticsSnapshot.isHolding, isFalse);
            expect(engine.diagnosticsSnapshot.hadFormBreak, isTrue);
            expect(
              engine.diagnosticsSnapshot.bestHoldSeconds,
              closeTo(1.0, 0.001),
            );
          },
        );

        test('brief visibility gap resumes without counting hidden time', () {
          engine.update(_holdFrame(validSignals));
          clock.advance(const Duration(seconds: 2));
          engine.update(_holdFrame(validSignals));

          engine.beginVisibilityGap();
          clock.advance(const Duration(milliseconds: 500));
          final recovery = engine.resumeAfterVisibilityGap();
          engine.update(_holdFrame(validSignals));
          clock.advance(const Duration(seconds: 1));
          engine.update(_holdFrame(validSignals));

          expect(recovery.disposition, HoldVisibilityResumeDisposition.resumed);
          expect(engine.diagnosticsSnapshot.isHolding, isTrue);
          expect(
            engine.diagnosticsSnapshot.currentHoldSeconds,
            closeTo(3.0, 0.001),
          );
        });

        test(
          'visibility loss at freeze boundary ends hold without phantom time',
          () {
            engine.update(_holdFrame(validSignals));
            clock.advance(const Duration(seconds: 2));
            engine.update(_holdFrame(validSignals));

            engine.beginVisibilityGap();
            clock.advance(holdVisibilityGapGraceDuration);
            final recovery = engine.resumeAfterVisibilityGap();

            expect(recovery.disposition, HoldVisibilityResumeDisposition.ended);
            expect(engine.diagnosticsSnapshot.isHolding, isFalse);
            expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
            expect(
              engine.diagnosticsSnapshot.bestHoldSeconds,
              closeTo(2.0, 0.001),
            );

            engine.update(_holdFrame(validSignals));
            expect(engine.diagnosticsSnapshot.isHolding, isTrue);
            expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
          },
        );

        test('missing required signals stop the active hold safely', () {
          engine.update(_holdFrame(validSignals));
          clock.advance(const Duration(seconds: 1));
          engine.update(_holdFrame(validSignals));

          engine.update(_holdFrame(const HoldSignalValues.empty()));

          expect(engine.diagnosticsSnapshot.isHolding, isFalse);
          expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
          expect(
            engine.diagnosticsSnapshot.bestHoldSeconds,
            closeTo(1.0, 0.001),
          );
        });

        test('reset clears current and best hold state', () {
          engine.update(_holdFrame(validSignals));
          clock.advance(const Duration(seconds: 2));
          engine.update(_holdFrame(validSignals));

          engine.reset();

          expect(engine.diagnosticsSnapshot.isHolding, isFalse);
          expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
          expect(engine.diagnosticsSnapshot.bestHoldSeconds, 0.0);
          expect(engine.diagnosticsSnapshot.hadFormBreak, isFalse);

          engine.update(_holdFrame(validSignals));
          expect(engine.diagnosticsSnapshot.isHolding, isTrue);
          expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
        });
      });
    }
  });
}

AnalysisFrame _holdFrame(HoldSignalValues signals) {
  return AnalysisFrame(
    primaryMetric: 0.0,
    formMetric: 0.0,
    holdSignalValues: signals,
  );
}

HoldSignalValues _validHoldSignals({
  required ExerciseConfig config,
  required HoldContract contract,
}) {
  switch (contract.family) {
    case HoldAnalysisFamily.plank:
      final posture = config.resolvedHoldPosture;
      return HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.alignment: posture.bodyLineEntryAngle,
          HoldSignal.support:
              (posture.armSupportMinAngle + posture.armSupportMaxAngle) / 2.0,
          HoldSignal.extension: posture.legExtensionMinAngle,
        },
      );
    case HoldAnalysisFamily.sidePlank:
      final posture = config.resolvedHoldPosture;
      return HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.alignment: posture.bodyLineEntryAngle,
          HoldSignal.support:
              (posture.armSupportMinAngle + posture.armSupportMaxAngle) / 2.0,
          HoldSignal.supportStacking: 1.0,
          HoldSignal.extension: posture.legExtensionMinAngle,
        },
      );
    case HoldAnalysisFamily.hollowHold:
      final posture = config.hollowHoldPosture!;
      return HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.compression: posture.compressionEntryMaxAngle,
          if (contract.hollowHoldVariation!.requiresArmsOverhead)
            HoldSignal.armExtension: posture.armExtensionMinAngle,
          if (contract.hollowHoldVariation!.requiresStraightKnees)
            HoldSignal.kneeExtension: posture.kneeExtensionMinAngle,
        },
      );
    case HoldAnalysisFamily.wallSit:
      final posture = config.wallSitPosture!;
      return HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.kneeFlexion:
              (posture.kneeMinAngle + posture.kneeMaxAngle) / 2.0,
          HoldSignal.hipFlexion:
              (posture.hipMinAngle + posture.hipMaxAngle) / 2.0,
          HoldSignal.torsoAlignment: posture.torsoMinAngle,
        },
      );
  }
}

HoldSignalValues _invalidStartSignals({
  required ExerciseConfig config,
  required HoldContract contract,
}) {
  switch (contract.family) {
    case HoldAnalysisFamily.plank:
      final posture = config.resolvedHoldPosture;
      return HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.alignment: posture.activePostureAngle - 10.0,
          HoldSignal.support:
              (posture.armSupportMinAngle + posture.armSupportMaxAngle) / 2.0,
          HoldSignal.extension: posture.legExtensionMinAngle,
        },
      );
    case HoldAnalysisFamily.sidePlank:
      final posture = config.resolvedHoldPosture;
      return HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.alignment: posture.activePostureAngle - 10.0,
          HoldSignal.support:
              (posture.armSupportMinAngle + posture.armSupportMaxAngle) / 2.0,
          HoldSignal.supportStacking: 1.0,
          HoldSignal.extension: posture.legExtensionMinAngle,
        },
      );
    case HoldAnalysisFamily.hollowHold:
      final posture = config.hollowHoldPosture!;
      return HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.compression: posture.activePostureMaxAngle + 10.0,
          if (contract.hollowHoldVariation!.requiresArmsOverhead)
            HoldSignal.armExtension: posture.armExtensionMinAngle,
          if (contract.hollowHoldVariation!.requiresStraightKnees)
            HoldSignal.kneeExtension: posture.kneeExtensionMinAngle,
        },
      );
    case HoldAnalysisFamily.wallSit:
      final posture = config.wallSitPosture!;
      return HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.kneeFlexion: posture.activeKneeMaxAngle + 10.0,
          HoldSignal.hipFlexion:
              (posture.hipMinAngle + posture.hipMaxAngle) / 2.0,
          HoldSignal.torsoAlignment: posture.torsoMinAngle,
        },
      );
  }
}

HoldSignalValues _graceEligibleSignals({
  required ExerciseConfig config,
  required HoldContract contract,
}) {
  switch (contract.family) {
    case HoldAnalysisFamily.plank:
      final posture = config.resolvedHoldPosture;
      return HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.alignment:
              (posture.activePostureAngle + posture.bodyLineSustainAngle) / 2.0,
          HoldSignal.support:
              (posture.armSupportMinAngle + posture.armSupportMaxAngle) / 2.0,
          HoldSignal.extension: posture.legExtensionMinAngle,
        },
      );
    case HoldAnalysisFamily.sidePlank:
      final posture = config.resolvedHoldPosture;
      return HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.alignment:
              (posture.activePostureAngle + posture.bodyLineSustainAngle) / 2.0,
          HoldSignal.support:
              (posture.armSupportMinAngle + posture.armSupportMaxAngle) / 2.0,
          HoldSignal.supportStacking: 1.0,
          HoldSignal.extension: posture.legExtensionMinAngle,
        },
      );
    case HoldAnalysisFamily.hollowHold:
      final posture = config.hollowHoldPosture!;
      return HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.compression: posture.compressionSustainMaxAngle + 1.0,
          if (contract.hollowHoldVariation!.requiresArmsOverhead)
            HoldSignal.armExtension: posture.armExtensionMinAngle,
          if (contract.hollowHoldVariation!.requiresStraightKnees)
            HoldSignal.kneeExtension: posture.kneeExtensionMinAngle,
        },
      );
    case HoldAnalysisFamily.wallSit:
      final posture = config.wallSitPosture!;
      return HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.kneeFlexion:
              (posture.kneeMaxAngle + posture.activeKneeMaxAngle) / 2.0,
          HoldSignal.hipFlexion:
              (posture.hipMinAngle + posture.hipMaxAngle) / 2.0,
          HoldSignal.torsoAlignment: posture.torsoMinAngle,
        },
      );
  }
}

Duration _breakGraceDuration({
  required ExerciseConfig config,
  required HoldContract contract,
}) {
  switch (contract.family) {
    case HoldAnalysisFamily.plank:
    case HoldAnalysisFamily.sidePlank:
      return config.resolvedHoldPosture.breakGraceDuration;
    case HoldAnalysisFamily.hollowHold:
      return config.hollowHoldPosture!.breakGraceDuration;
    case HoldAnalysisFamily.wallSit:
      return config.wallSitPosture!.breakGraceDuration;
  }
}
