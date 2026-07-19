import '../range_rep_diagnostics.dart';
import 'range_rep_contract.dart';

class RangeRepEngineFrameResult {
  RangeRepEngineFrameResult({
    required this.wasArmedAtFrameStart,
    required this.isArmedAfterUpdate,
    this.repStarted = false,
    this.repAborted = false,
    this.completedRepCoreData,
    List<RangeRepPhase> observedRepPhases = const <RangeRepPhase>[],
  }) : observedRepPhases = List<RangeRepPhase>.unmodifiable(observedRepPhases);

  final bool wasArmedAtFrameStart;
  final bool isArmedAfterUpdate;
  final bool repStarted;
  final bool repAborted;
  final RangeRepCompletedRepCoreData? completedRepCoreData;
  final List<RangeRepPhase> observedRepPhases;

  bool get didCompleteRep => completedRepCoreData != null;
}
