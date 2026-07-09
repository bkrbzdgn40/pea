import '../domain/models/calibration_snapshot.dart';
import '../domain/models/session_calibration_baseline.dart';

/// Aggregates compatible session calibration snapshots into a single baseline.
class SessionCalibrationBaselineAccumulator {
  String? _analysisKind;
  String? _selectedSideLabel;
  int _sampleCount = 0;
  final _RunningAverage _primaryMetricBaseline = _RunningAverage();
  final _RunningAverage _formMetricBaseline = _RunningAverage();
  final _RunningAverage _torsoAngleBaseline = _RunningAverage();
  final _RunningAverage _depthMetricBaseline = _RunningAverage();
  final _RunningAverage _alignmentMetricBaseline = _RunningAverage();
  final _RunningAverage _stabilityMetricBaseline = _RunningAverage();
  final _RunningAverage _lockoutMetricBaseline = _RunningAverage();
  final _RunningAverage _bottomControlMetricBaseline = _RunningAverage();

  bool addIfAccepted(CalibrationSnapshot snapshot) {
    if (_analysisKind == null) {
      _analysisKind = snapshot.analysisKind;
      _selectedSideLabel = snapshot.selectedSideLabel;
    } else if (!canAccept(snapshot)) {
      return false;
    }

    _sampleCount += 1;
    _primaryMetricBaseline.add(snapshot.primaryMetricBaseline);
    _formMetricBaseline.add(snapshot.formMetricBaseline);
    _torsoAngleBaseline.add(snapshot.torsoAngleBaseline);
    _depthMetricBaseline.add(snapshot.depthMetricBaseline);
    _alignmentMetricBaseline.add(snapshot.alignmentMetricBaseline);
    _stabilityMetricBaseline.add(snapshot.stabilityMetricBaseline);
    _lockoutMetricBaseline.add(snapshot.lockoutMetricBaseline);
    _bottomControlMetricBaseline.add(snapshot.bottomControlMetricBaseline);
    return true;
  }

  bool canAccept(CalibrationSnapshot snapshot) {
    return _analysisKind == null ||
        (snapshot.analysisKind == _analysisKind &&
            snapshot.selectedSideLabel == _selectedSideLabel);
  }

  SessionCalibrationBaseline? get baseline {
    final analysisKind = _analysisKind;
    if (analysisKind == null) {
      return null;
    }

    return SessionCalibrationBaseline(
      analysisKind: analysisKind,
      selectedSideLabel: _selectedSideLabel,
      sampleCount: _sampleCount,
      primaryMetricBaseline: _primaryMetricBaseline.value,
      formMetricBaseline: _formMetricBaseline.value,
      torsoAngleBaseline: _torsoAngleBaseline.value,
      depthMetricBaseline: _depthMetricBaseline.value,
      alignmentMetricBaseline: _alignmentMetricBaseline.value,
      stabilityMetricBaseline: _stabilityMetricBaseline.value,
      lockoutMetricBaseline: _lockoutMetricBaseline.value,
      bottomControlMetricBaseline: _bottomControlMetricBaseline.value,
    );
  }
}

class _RunningAverage {
  int _valueCount = 0;
  double? _value;

  double? get value => _value;

  void add(double? nextValue) {
    if (nextValue == null) {
      return;
    }

    _valueCount += 1;
    if (_value == null) {
      _value = nextValue;
      return;
    }

    _value = _value! + ((nextValue - _value!) / _valueCount);
  }
}
