import '../range_rep_diagnostics.dart';
import '../tempo_engine.dart';
import 'range_rep_completed_cycle.dart';
import 'range_rep_completed_rep_detection_data.dart';
import 'range_rep_confirmed_transition.dart';
import 'range_rep_contract.dart';

class RangeRepEngineFrameResult {
  RangeRepEngineFrameResult({
    required this.wasArmedAtFrameStart,
    required this.isArmedAfterUpdate,
    this.repStarted = false,
    this.repAborted = false,
    RangeRepCompletedRepDetectionData? completedRepDetectionData,
    RangeRepCompletedRepCoreData? completedRepCoreData,
    RangeRepCompletedCycle? completedCycle,
    RangeRepConfirmedTransition? confirmedTransition,
    List<RangeRepConfirmedTransition>? confirmedTransitions,
    TempoRepResult? completedTempo,
    List<RangeRepPhase> observedRepPhases = const <RangeRepPhase>[],
  }) : completedCycle = completedCycle,
       completedRepDetectionData =
           completedRepDetectionData ?? completedCycle?.detectionData,
       completedRepCoreData =
           completedRepCoreData ?? completedCycle?.compatibilityCoreData,
       completedTempo = completedTempo ?? completedCycle?.completedTempo,
       confirmedTransitions = List<RangeRepConfirmedTransition>.unmodifiable(
         confirmedTransitions ??
             completedCycle?.confirmedTransitions ??
             (confirmedTransition == null
                 ? const <RangeRepConfirmedTransition>[]
                 : <RangeRepConfirmedTransition>[confirmedTransition]),
       ),
       observedRepPhases = List<RangeRepPhase>.unmodifiable(observedRepPhases);

  final bool wasArmedAtFrameStart;
  final bool isArmedAfterUpdate;
  final bool repStarted;
  final bool repAborted;
  final RangeRepCompletedRepDetectionData? completedRepDetectionData;
  final RangeRepCompletedRepCoreData? completedRepCoreData;
  final RangeRepCompletedCycle? completedCycle;
  final List<RangeRepConfirmedTransition> confirmedTransitions;
  final TempoRepResult? completedTempo;
  final List<RangeRepPhase> observedRepPhases;

  RangeRepConfirmedTransition? get confirmedTransition =>
      confirmedTransitions.isEmpty ? null : confirmedTransitions.last;

  bool get didCompleteRep => completedRepDetectionData != null;
}
