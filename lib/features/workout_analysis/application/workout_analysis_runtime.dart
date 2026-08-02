import '../domain/hold_analysis_engine.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/range_rep_analysis_engine.dart';
import '../domain/range_rep_validation_policy.dart';
import 'analysis_engine_factory.dart';
import 'common_frame_pose_pipeline.dart';
import 'engine_kind.dart';
import 'exercise_catalog.dart';
import 'exercise_definition.dart';
import 'exercise_definition_metadata.dart';
import 'hold_coordinator.dart';
import 'pose_acceptance_stabilizer.dart';
import 'prepared_exercise_analysis_context.dart';
import 'range_rep_coordinator.dart';
import 'range_rep_primary_metric_normalizer.dart';
import 'range_rep_temporal_continuity_tracker.dart';
import 'validated_rep_event_tracker.dart';
import 'workout_diagnostics.dart';
import 'workout_diagnostics_reporter.dart';

typedef WorkoutFramePosePipelineFactory =
    WorkoutFramePosePipeline Function({
      required PoseAcceptanceStabilizer poseAcceptanceStabilizer,
    });

typedef RangeRepCoordinatorFactory =
    RangeRepCoordinator Function({
      required RangeRepAnalysisEngine engine,
      required ExerciseConfig config,
      required RangeRepContract rangeRepContract,
      required RangeRepValidationConfig rangeRepValidationConfig,
    });

typedef HoldCoordinatorFactory =
    HoldCoordinator Function({
      required HoldAnalysisEngine engine,
      required ExerciseConfig config,
      required HoldContract holdContract,
    });

/// Runtime graph for one active exercise analysis build.
///
/// Riverpod may rebuild the same controller instance when the exercise changes.
/// Keeping the graph in one object makes that replacement explicit and avoids
/// a controller full of independently nullable engine fields.
class WorkoutAnalysisRuntime {
  WorkoutAnalysisRuntime({
    required this.activeExercise,
    required this.definition,
    required this.config,
    required this.engineKind,
    required this.rangeRepContract,
    required this.holdContract,
    required this.preparedAnalysisContext,
    required this.rangeRepEngine,
    required this.validatedRepEventTracker,
    required this.rangeRepCoordinator,
    required this.primaryMetricNormalizer,
    required this.rangeRepTemporalContinuityTracker,
    required this.holdCoordinator,
    required this.poseAcceptanceStabilizer,
    required this.framePosePipeline,
    required this.diagnosticsReporter,
    required this.fpsWindowStartedAt,
  });

  final ExerciseType activeExercise;
  final ExerciseDefinition definition;
  final ExerciseConfig config;
  final EngineKind engineKind;
  final RangeRepContract? rangeRepContract;
  final HoldContract? holdContract;
  final PreparedExerciseAnalysisContext preparedAnalysisContext;
  final RangeRepAnalysisEngine? rangeRepEngine;
  final ValidatedRepEventTracker? validatedRepEventTracker;
  final RangeRepCoordinator? rangeRepCoordinator;
  final RangeRepPrimaryMetricNormalizer? primaryMetricNormalizer;
  final RangeRepTemporalContinuityTracker? rangeRepTemporalContinuityTracker;
  final HoldCoordinator? holdCoordinator;
  final PoseAcceptanceStabilizer poseAcceptanceStabilizer;
  final WorkoutFramePosePipeline framePosePipeline;
  final WorkoutDiagnosticsReporter diagnosticsReporter;
  final DateTime fpsWindowStartedAt;

  RangeRepAnalysisEngine requireRangeRepEngine() {
    final engine = rangeRepEngine;
    if (engine == null) {
      throw StateError(
        'RangeRepAnalysisEngine is only available during range-rep analysis.',
      );
    }
    return engine;
  }

  RangeRepCoordinator requireRangeRepCoordinator() {
    final coordinator = rangeRepCoordinator;
    if (coordinator == null) {
      throw StateError(
        'RangeRepCoordinator is only available during range-rep analysis.',
      );
    }
    return coordinator;
  }

  HoldCoordinator requireHoldCoordinator() {
    final coordinator = holdCoordinator;
    if (coordinator == null) {
      throw StateError(
        'HoldCoordinator is only available during hold analysis.',
      );
    }
    return coordinator;
  }
}

class WorkoutAnalysisRuntimeFactory {
  const WorkoutAnalysisRuntimeFactory({
    this.engineFactory = const AnalysisEngineFactory(),
    this.exerciseCatalog = const ExerciseCatalog(),
  });

  final AnalysisEngineFactory engineFactory;
  final ExerciseCatalog exerciseCatalog;

  WorkoutAnalysisRuntime create({
    required ExerciseType activeExercise,
    required ExerciseConfig config,
    required DateTime Function() clock,
    required WorkoutFramePosePipelineFactory framePosePipelineFactory,
    required RangeRepCoordinatorFactory rangeRepCoordinatorFactory,
    required HoldCoordinatorFactory holdCoordinatorFactory,
    required bool diagnosticsEnabled,
  }) {
    final definition = exerciseCatalog.definitionFor(activeExercise);
    final engineKind = definition.analysisEngineKind;
    final rangeRepContract = engineKind == EngineKind.rangeRep
        ? definition.analysisRangeRepContract
        : null;
    final holdContract = engineKind == EngineKind.hold
        ? definition.analysisHoldContract
        : null;

    RangeRepAnalysisEngine? rangeRepEngine;
    ValidatedRepEventTracker? validatedRepEventTracker;
    RangeRepCoordinator? rangeRepCoordinator;
    RangeRepPrimaryMetricNormalizer? primaryMetricNormalizer;
    RangeRepTemporalContinuityTracker? temporalContinuityTracker;
    HoldCoordinator? holdCoordinator;

    switch (engineKind) {
      case EngineKind.rangeRep:
        final contract =
            rangeRepContract ??
            (throw StateError(
              'Range-rep analysis requires a RangeRepContract.',
            ));
        final engine = engineFactory.createRangeRep(
          config: config,
          rangeRepContract: contract,
          now: clock,
        );
        rangeRepEngine = engine;
        validatedRepEventTracker =
            definition.usesAnalysisEngine(ExerciseAnalysisEngine.alternatingRep)
            ? ValidatedRepEventTracker()
            : null;
        primaryMetricNormalizer = RangeRepPrimaryMetricNormalizer(
          config: config,
          rangeRepContract: contract,
        );
        temporalContinuityTracker = RangeRepTemporalContinuityTracker();
        rangeRepCoordinator = rangeRepCoordinatorFactory(
          engine: engine,
          config: config,
          rangeRepContract: contract,
          rangeRepValidationConfig: definition.analysisRangeRepValidationConfig,
        );
        break;
      case EngineKind.hold:
        final contract =
            holdContract ??
            (throw StateError('Hold analysis requires a HoldContract.'));
        final engine = engineFactory.createHold(
          config: config,
          holdContract: contract,
          now: clock,
        );
        holdCoordinator = holdCoordinatorFactory(
          engine: engine,
          config: config,
          holdContract: contract,
        );
        break;
      case EngineKind.alternatingRep:
        engineFactory.create(
          engineKind: engineKind,
          config: config,
          rangeRepContract: rangeRepContract,
          holdContract: holdContract,
          now: clock,
        );
        throw StateError('Unreachable alternatingRep analysis wiring path.');
    }

    final preparedAnalysisContext = PreparedExerciseAnalysisContext.resolve(
      config: config,
      engineKind: engineKind,
      rangeRepContract: rangeRepContract,
      holdContract: holdContract,
    );

    // Preserve the original controller clock-call order. Some production-path
    // tests deliberately verify wall-clock semantics across rebuilds.
    final fpsWindowStartedAt = clock();
    final poseAcceptanceStabilizer = PoseAcceptanceStabilizer();
    final framePosePipeline = framePosePipelineFactory(
      poseAcceptanceStabilizer: poseAcceptanceStabilizer,
    );
    final diagnostics = WorkoutDiagnosticsAccumulator(
      sessionStartedAt: clock(),
      analysisKind: engineKind.name,
      exerciseType: activeExercise.id,
      configAssetPath: definition.analysisConfigAssetPath,
      cameraViewContract: definition.analysisCameraViewContract,
      rangeRepContract: rangeRepContract,
      holdContract: holdContract,
    );

    return WorkoutAnalysisRuntime(
      activeExercise: activeExercise,
      definition: definition,
      config: config,
      engineKind: engineKind,
      rangeRepContract: rangeRepContract,
      holdContract: holdContract,
      preparedAnalysisContext: preparedAnalysisContext,
      rangeRepEngine: rangeRepEngine,
      validatedRepEventTracker: validatedRepEventTracker,
      rangeRepCoordinator: rangeRepCoordinator,
      primaryMetricNormalizer: primaryMetricNormalizer,
      rangeRepTemporalContinuityTracker: temporalContinuityTracker,
      holdCoordinator: holdCoordinator,
      poseAcceptanceStabilizer: poseAcceptanceStabilizer,
      framePosePipeline: framePosePipeline,
      diagnosticsReporter: WorkoutDiagnosticsReporter(
        enabled: diagnosticsEnabled,
        accumulator: diagnostics,
      ),
      fpsWindowStartedAt: fpsWindowStartedAt,
    );
  }
}
