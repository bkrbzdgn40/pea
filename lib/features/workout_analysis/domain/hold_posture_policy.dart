import 'models/exercise_config.dart';

class HoldPostureEvaluation {
  const HoldPostureEvaluation({
    required this.hasActivePosture,
    required this.hasCompleteMetrics,
    required this.bodyLineTargetAngle,
    required this.isBodyAligned,
    required this.isArmSupported,
    required this.areLegsExtended,
  });

  final bool hasActivePosture;
  final bool hasCompleteMetrics;
  final double bodyLineTargetAngle;
  final bool isBodyAligned;
  final bool isArmSupported;
  final bool areLegsExtended;

  bool get isValidHoldPosture =>
      hasCompleteMetrics && isBodyAligned && isArmSupported && areLegsExtended;

  bool get supportsGraceWindow =>
      hasCompleteMetrics && !isBodyAligned && isArmSupported && areLegsExtended;
}

class HoldPosturePolicy {
  const HoldPosturePolicy({required this.config});

  final HoldPostureConfig config;

  double bodyLineTargetAngle({required bool isHolding}) {
    return isHolding ? config.bodyLineSustainAngle : config.bodyLineEntryAngle;
  }

  HoldPostureEvaluation evaluate({
    required double? bodyLineAngle,
    required double? armSupportAngle,
    required double? legExtensionAngle,
    required bool isHolding,
  }) {
    final targetAngle = bodyLineTargetAngle(isHolding: isHolding);
    final hasCompleteMetrics =
        bodyLineAngle != null &&
        armSupportAngle != null &&
        legExtensionAngle != null;
    final hasActivePosture =
        bodyLineAngle != null && bodyLineAngle >= config.activePostureAngle;
    final isBodyAligned = hasCompleteMetrics && bodyLineAngle! >= targetAngle;
    final isArmSupported =
        hasCompleteMetrics &&
        armSupportAngle! >= config.armSupportMinAngle &&
        armSupportAngle! <= config.armSupportMaxAngle;
    final areLegsExtended =
        hasCompleteMetrics && legExtensionAngle! >= config.legExtensionMinAngle;

    return HoldPostureEvaluation(
      hasActivePosture: hasActivePosture,
      hasCompleteMetrics: hasCompleteMetrics,
      bodyLineTargetAngle: targetAngle,
      isBodyAligned: isBodyAligned,
      isArmSupported: isArmSupported,
      areLegsExtended: areLegsExtended,
    );
  }
}
