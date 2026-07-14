import '../domain/hold_diagnostics.dart';
import '../domain/models/hold_side.dart';
import 'engine_kind.dart';

bool shouldLockHoldSideSelection({
  required EngineKind engineKind,
  required HoldSide? selectedSide,
  required HoldDiagnosticsSnapshot diagnostics,
}) {
  if (engineKind != EngineKind.hold || selectedSide == null) {
    return false;
  }

  return diagnostics.isHolding || diagnostics.isVisibilitySuspended;
}
