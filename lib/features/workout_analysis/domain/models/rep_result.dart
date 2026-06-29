import '../enums/movement_phase.dart';

class RepResult {
  const RepResult({
    required this.index,
    required this.score,
    required this.isSuccessful,
    this.phase = MovementPhase.unknown,
  });

  final int index;
  final double score;
  final bool isSuccessful;
  final MovementPhase phase;
}
