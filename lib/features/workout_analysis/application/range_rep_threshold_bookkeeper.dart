import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/models/session_calibration_baseline.dart';
import 'range_rep_threshold_resolver.dart';

/// Keeps threshold resolution bookkeeping state out of the controller.
class RangeRepThresholdBookkeeper {
  RangeRepThresholdBookkeeper({
    required String analysisKind,
    required ExerciseConfig config,
    required RangeRepFormThresholdCalibrationPolicy
    formThresholdCalibrationPolicy,
    RangeRepThresholdResolver resolver = const RangeRepThresholdResolver(),
  }) : _analysisKind = analysisKind,
       _config = config,
       _formThresholdCalibrationPolicy = formThresholdCalibrationPolicy,
       _resolver = resolver;

  final String _analysisKind;
  final ExerciseConfig _config;
  final RangeRepFormThresholdCalibrationPolicy _formThresholdCalibrationPolicy;
  final RangeRepThresholdResolver _resolver;

  int _decisionCount = 0;
  int _appliedCount = 0;
  int _noBaselineCount = 0;
  int _insufficientSamplesCount = 0;
  int _missingFormBaselineCount = 0;
  int _sideMismatchCount = 0;
  int _offsetTooSmallCount = 0;

  int get decisionCount => _decisionCount;
  int get appliedCount => _appliedCount;
  int get noBaselineCount => _noBaselineCount;
  int get insufficientSamplesCount => _insufficientSamplesCount;
  int get missingFormBaselineCount => _missingFormBaselineCount;
  int get sideMismatchCount => _sideMismatchCount;
  int get offsetTooSmallCount => _offsetTooSmallCount;

  RangeRepThresholdResolution resolve({
    required double baseThreshold,
    required SessionCalibrationBaseline? sessionCalibrationBaseline,
    required String? selectedRangeRepSide,
  }) {
    final resolution = _resolver.resolve(
      analysisKind: _analysisKind,
      config: _config,
      baseThreshold: baseThreshold,
      formThresholdCalibrationPolicy: _formThresholdCalibrationPolicy,
      sessionCalibrationBaseline: sessionCalibrationBaseline,
      selectedRangeRepSide: selectedRangeRepSide,
    );

    _decisionCount++;
    switch (resolution.decisionReason) {
      case 'applied':
        _appliedCount++;
        break;
      case 'no_baseline':
        _noBaselineCount++;
        break;
      case 'insufficient_samples':
        _insufficientSamplesCount++;
        break;
      case 'missing_form_baseline':
        _missingFormBaselineCount++;
        break;
      case 'side_mismatch':
        _sideMismatchCount++;
        break;
      case 'offset_too_small':
        _offsetTooSmallCount++;
        break;
      case 'measurement_correction_only':
        // R28: correction candidates do not rewrite technique thresholds.
        break;
      case 'disabled_by_contract':
        // Intentional: diagnostics schema has no dedicated disabled counter.
        break;
    }

    return resolution;
  }
}
