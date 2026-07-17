import 'hold_contract.dart';
import 'hold_signal_values.dart';

class AnalysisFrame {
  AnalysisFrame({
    required this.primaryMetric,
    required this.formMetric,
    HoldSignalValues? holdSignalValues,
    double? bodyLineAngle,
    double? armSupportAngle,
    double? legExtensionAngle,
  }) : holdSignalValues =
           holdSignalValues ??
           HoldSignalValues.legacy(
             alignment: bodyLineAngle,
             support: armSupportAngle,
             extension: legExtensionAngle,
           );

  final double primaryMetric;
  final double formMetric;
  final HoldSignalValues holdSignalValues;

  double? get bodyLineAngle => holdSignalValues.valueFor(HoldSignal.alignment);

  double? get armSupportAngle => holdSignalValues.valueFor(HoldSignal.support);

  double? get legExtensionAngle =>
      holdSignalValues.valueFor(HoldSignal.extension);
}
