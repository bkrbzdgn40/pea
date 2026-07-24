import '../range_rep_diagnostics.dart';
import '../tempo_engine.dart';
import 'range_rep_completed_rep_detection_data.dart';
import 'range_rep_confirmed_transition.dart';
import 'range_rep_contract.dart';

class RangeRepEngineFrameResult {
  RangeRepEngineFrameResult({
    required this.wasArmedAtFrameStart,
    required this.isArmedAfterUpdate,
    this.repStarted = false,
    this.repAborted = false,
    this.completedRepDetectionData,
    this.completedRepCoreData,
    RangeRepConfirmedTransition? confirmedTransition,
    List<RangeRepConfirmedTransition>? confirmedTransitions,
    this.completedTempo,
    List<RangeRepPhase> observedRepPhases = const <RangeRepPhase>[],
  }) : confirmedTransitions = List<RangeRepConfirmedTransition>.unmodifiable(
         confirmedTransitions ??
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
  final List<RangeRepConfirmedTransition> confirmedTransitions;
  final TempoRepResult? completedTempo;
  final List<RangeRepPhase> observedRepPhases;

  RangeRepConfirmedTransition? get confirmedTransition =>
      confirmedTransitions.isEmpty ? null : confirmedTransitions.last;

  bool get didCompleteRep => completedRepDetectionData != null;
}
