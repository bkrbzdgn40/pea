import '../range_rep_diagnostics.dart';
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
    this.confirmedTransition,
    List<RangeRepPhase> observedRepPhases = const <RangeRepPhase>[],
  }) : observedRepPhases = List<RangeRepPhase>.unmodifiable(observedRepPhases);

  final bool wasArmedAtFrameStart;
  final bool isArmedAfterUpdate;
  final bool repStarted;
  final bool repAborted;
  final RangeRepCompletedRepDetectionData? completedRepDetectionData;
  final RangeRepCompletedRepCoreData? completedRepCoreData;
  final RangeRepConfirmedTransition? confirmedTransition;
  final List<RangeRepPhase> observedRepPhases;

  bool get didCompleteRep => completedRepDetectionData != null;
}
