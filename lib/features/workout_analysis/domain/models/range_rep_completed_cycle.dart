import '../generic_rep_engine.dart';
import '../range_rep_diagnostics.dart';
import '../range_rep_timing_trace.dart';
import '../tempo_engine.dart';
import 'range_rep_completed_rep_detection_data.dart';
import 'range_rep_confirmed_transition.dart';

/// Immutable facts emitted by the range-rep engine for one completed cycle.
///
/// This is the completion seam consumed by coordinator-level validation and
/// scoring. Compatibility fields remain available on the frame result while
/// callers migrate to this payload.
class RangeRepCompletedCycle {
  RangeRepCompletedCycle({
    required this.genericCompletedRep,
    required this.detectionData,
    required this.timingTrace,
    this.compatibilityCoreData,
    this.completedTempo,
    this.phaseQualityTelemetry,
    List<RangeRepConfirmedTransition> confirmedTransitions =
        const <RangeRepConfirmedTransition>[],
  }) : confirmedTransitions = List<RangeRepConfirmedTransition>.unmodifiable(
         confirmedTransitions,
       );

  final GenericRepCompletedRep genericCompletedRep;
  final RangeRepCompletedRepDetectionData detectionData;
  final RangeRepCompletedRepCoreData? compatibilityCoreData;
  final TempoRepResult? completedTempo;
  final RangeRepTimingTraceSnapshot? timingTrace;
  final RangeRepPhaseQualityTelemetry? phaseQualityTelemetry;
  final List<RangeRepConfirmedTransition> confirmedTransitions;
}
