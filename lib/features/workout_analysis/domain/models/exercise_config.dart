import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'hold_contract.dart';
import 'hold_side.dart';
import 'range_rep_contract.dart';

class PoseAngleLandmarks {
  const PoseAngleLandmarks({
    required this.first,
    required this.middle,
    required this.last,
  }) : assert(first != middle),
       assert(first != last),
       assert(middle != last);

  final PoseLandmarkType first;
  final PoseLandmarkType middle;
  final PoseLandmarkType last;
}

class RangeRepScoreWeightsConfig {
  const RangeRepScoreWeightsConfig({
    this.depthWeight,
    this.postureWeight,
    this.stabilityWeight,
    this.descentControlWeight,
    this.ascentControlWeight,
    this.consistencyWeight,
  });

  final double? depthWeight;
  final double? postureWeight;
  final double? stabilityWeight;
  final double? descentControlWeight;
  final double? ascentControlWeight;
  final double? consistencyWeight;

  factory RangeRepScoreWeightsConfig.fromMap(Map<String, dynamic> map) {
    return _fromReader(
      _StrictConfigMapReader.root('RangeRepScoreWeightsConfig', map),
    );
  }

  static RangeRepScoreWeightsConfig _fromReader(_StrictConfigMapReader reader) {
    return RangeRepScoreWeightsConfig(
      depthWeight: reader.optionalDouble('depthWeight'),
      postureWeight: reader.optionalDouble('postureWeight'),
      stabilityWeight: reader.optionalDouble('stabilityWeight'),
      descentControlWeight: reader.optionalDouble('descentControlWeight'),
      ascentControlWeight: reader.optionalDouble('ascentControlWeight'),
      consistencyWeight: reader.optionalDouble('consistencyWeight'),
    );
  }
}

class RangeRepPhaseQualityConfig {
  const RangeRepPhaseQualityConfig({
    this.minDescendingMillis,
    this.minAscendingMillis,
  });

  final int? minDescendingMillis;
  final int? minAscendingMillis;

  factory RangeRepPhaseQualityConfig.fromMap(Map<String, dynamic> map) {
    return _fromReader(
      _StrictConfigMapReader.root('RangeRepPhaseQualityConfig', map),
    );
  }

  static RangeRepPhaseQualityConfig _fromReader(_StrictConfigMapReader reader) {
    return RangeRepPhaseQualityConfig(
      minDescendingMillis: reader.optionalInt('minDescendingMillis'),
      minAscendingMillis: reader.optionalInt('minAscendingMillis'),
    );
  }
}

enum RangeRepSignalSource { primaryMetric }

class RangeRepSignalDefinition {
  const RangeRepSignalDefinition.angle(this.angle) : source = null;

  const RangeRepSignalDefinition.source(this.source) : angle = null;

  final PoseAngleLandmarks? angle;
  final RangeRepSignalSource? source;
}

class RangeRepSignalExtractionConfig {
  const RangeRepSignalExtractionConfig({
    this.postureAngle,
    this.depthMetric,
    this.alignmentMetric,
    this.stabilityMetric,
    this.endRangeMetric,
    this.bottomControlMetric,
  });

  final RangeRepSignalDefinition? postureAngle;
  final RangeRepSignalDefinition? depthMetric;
  final RangeRepSignalDefinition? alignmentMetric;
  final RangeRepSignalDefinition? stabilityMetric;
  final RangeRepSignalDefinition? endRangeMetric;
  final RangeRepSignalDefinition? bottomControlMetric;

  RangeRepSignalDefinition? definitionFor(RangeRepSignal signal) {
    switch (signal) {
      case RangeRepSignal.primaryMetric:
      case RangeRepSignal.formMetric:
        return null;
      case RangeRepSignal.postureAngle:
        return postureAngle;
      case RangeRepSignal.depthMetric:
        return depthMetric;
      case RangeRepSignal.alignmentMetric:
        return alignmentMetric;
      case RangeRepSignal.stabilityMetric:
        return stabilityMetric;
      case RangeRepSignal.endRangeMetric:
        return endRangeMetric;
      case RangeRepSignal.bottomControlMetric:
        return bottomControlMetric;
    }
  }
}

class HoldSignalExtractionConfig {
  const HoldSignalExtractionConfig({
    required this.referenceSide,
    this.alignment,
    this.support,
    this.extension,
  });

  final HoldSide referenceSide;
  final PoseAngleLandmarks? alignment;
  final PoseAngleLandmarks? support;
  final PoseAngleLandmarks? extension;

  PoseAngleLandmarks? definitionFor(HoldSignal signal) {
    switch (signal) {
      case HoldSignal.alignment:
        return alignment;
      case HoldSignal.support:
        return support;
      case HoldSignal.extension:
        return extension;
    }
  }
}

class HoldPostureConfig {
  const HoldPostureConfig({
    required this.activePostureAngle,
    required this.bodyLineEntryAngle,
    required this.bodyLineSustainAngle,
    required this.armSupportMinAngle,
    required this.armSupportMaxAngle,
    required this.legExtensionMinAngle,
    required this.breakGraceDuration,
  });

  final double activePostureAngle;
  final double bodyLineEntryAngle;
  final double bodyLineSustainAngle;
  final double armSupportMinAngle;
  final double armSupportMaxAngle;
  final double legExtensionMinAngle;
  final Duration breakGraceDuration;

  factory HoldPostureConfig.fromMap(Map<String, dynamic> map) {
    return _fromReader(_StrictConfigMapReader.root('HoldPostureConfig', map));
  }

  static HoldPostureConfig _fromReader(_StrictConfigMapReader reader) {
    return HoldPostureConfig(
      activePostureAngle: reader.requiredDouble('activePostureAngle'),
      bodyLineEntryAngle: reader.requiredDouble('bodyLineEntryAngle'),
      bodyLineSustainAngle: reader.requiredDouble('bodyLineSustainAngle'),
      armSupportMinAngle: reader.requiredDouble('armSupportMinAngle'),
      armSupportMaxAngle: reader.requiredDouble('armSupportMaxAngle'),
      legExtensionMinAngle: reader.requiredDouble('legExtensionMinAngle'),
      breakGraceDuration: Duration(
        milliseconds: reader.requiredInt('breakGraceMillis'),
      ),
    );
  }

  factory HoldPostureConfig.legacy(ExerciseConfig config) {
    return HoldPostureConfig(
      activePostureAngle: config.thresholdNeutral,
      bodyLineEntryAngle: config.thresholdActive,
      bodyLineSustainAngle: config.thresholdActive,
      armSupportMinAngle: 60.0,
      armSupportMaxAngle: 120.0,
      legExtensionMinAngle: 165.0,
      breakGraceDuration: const Duration(milliseconds: 300),
    );
  }
}

class ExerciseConfig {
  final String name;
  final PoseLandmarkType primaryJoint;
  final PoseLandmarkType joint1;
  final PoseLandmarkType joint2;

  final double thresholdNeutral;
  final double thresholdActive;
  final double thresholdPeak;

  final double idealDescentSeconds;
  final double idealAscentSeconds;
  final double formThreshold;
  final double targetMinAngle;
  final double tempoPenaltyPerSecond;
  final HoldPostureConfig? holdPosture;
  final HoldSignalExtractionConfig? holdSignals;
  final RangeRepScoreWeightsConfig? rangeRepScoreWeights;
  final RangeRepPhaseQualityConfig? rangeRepPhaseQuality;
  final RangeRepSignalExtractionConfig? rangeRepSignals;

  ExerciseConfig({
    required this.name,
    required this.primaryJoint,
    required this.joint1,
    required this.joint2,
    required this.thresholdNeutral,
    required this.thresholdActive,
    required this.thresholdPeak,
    this.idealDescentSeconds = 2.0,
    this.idealAscentSeconds = 1.0,
    this.formThreshold = 45.0,
    this.targetMinAngle = 70.0,
    this.tempoPenaltyPerSecond = 20.0,
    this.holdPosture,
    this.holdSignals,
    this.rangeRepScoreWeights,
    this.rangeRepPhaseQuality,
    this.rangeRepSignals,
  });

  HoldPostureConfig get resolvedHoldPosture {
    return holdPosture ?? HoldPostureConfig.legacy(this);
  }

  RangeRepSignalExtractionConfig? get resolvedRangeRepSignals {
    return rangeRepSignals ??
        (_matchesLegacySquatRangeRepSignals
            ? _legacySquatRangeRepSignals
            : null);
  }

  bool get usesLegacyRangeRepSignalFallback {
    return rangeRepSignals == null && _matchesLegacySquatRangeRepSignals;
  }

  double resolveFormThreshold({double offset = 0.0}) {
    return (formThreshold + offset).clamp(0.0, 180.0).toDouble();
  }

  factory ExerciseConfig.fromMap(Map<String, dynamic> map) {
    final reader = _StrictConfigMapReader.root('ExerciseConfig', map);
    final holdPosture = _readHoldPostureOrNull(reader);
    final holdSignals = _readHoldSignalsOrNull(reader);
    final rangeRepScoreWeights = _readRangeRepScoreWeightsOrNull(reader);
    final rangeRepPhaseQuality = _readRangeRepPhaseQualityOrNull(reader);
    final rangeRepSignals = _readRangeRepSignalsOrNull(reader);

    return ExerciseConfig(
      name: reader.requiredString('name'),
      primaryJoint: reader.requiredPoseLandmark('primaryJoint'),
      joint1: reader.requiredPoseLandmark('joint1'),
      joint2: reader.requiredPoseLandmark('joint2'),
      thresholdNeutral: reader.requiredDouble(
        'thresholdNeutral',
        fallback: holdPosture?.activePostureAngle,
      ),
      thresholdActive: reader.requiredDouble(
        'thresholdActive',
        fallback: holdPosture?.bodyLineEntryAngle,
      ),
      thresholdPeak: reader.requiredDouble('thresholdPeak', fallback: 0.0),
      idealDescentSeconds: reader.requiredDouble(
        'idealDescentSeconds',
        fallback: 0.0,
      ),
      idealAscentSeconds: reader.requiredDouble(
        'idealAscentSeconds',
        fallback: 0.0,
      ),
      formThreshold: reader.requiredDouble('formThreshold', fallback: 0.0),
      targetMinAngle: reader.requiredDouble('targetMinAngle', fallback: 0.0),
      tempoPenaltyPerSecond: reader.requiredDouble(
        'tempoPenaltyPerSecond',
        fallback: 0.0,
      ),
      holdPosture: holdPosture,
      holdSignals: holdSignals,
      rangeRepScoreWeights: rangeRepScoreWeights,
      rangeRepPhaseQuality: rangeRepPhaseQuality,
      rangeRepSignals: rangeRepSignals,
    );
  }

  static HoldPostureConfig? _readHoldPostureOrNull(
    _StrictConfigMapReader reader,
  ) {
    final holdPostureReader = reader.optionalObject('holdPosture');
    if (holdPostureReader == null) {
      return null;
    }

    return HoldPostureConfig._fromReader(holdPostureReader);
  }

  static HoldSignalExtractionConfig? _readHoldSignalsOrNull(
    _StrictConfigMapReader reader,
  ) {
    final holdSignalsReader = reader.optionalObject('holdSignals');
    if (holdSignalsReader == null) {
      return null;
    }

    holdSignalsReader.expectOnlyKeys(const <String>{
      'referenceSide',
      'alignment',
      'support',
      'extension',
    });

    return HoldSignalExtractionConfig(
      referenceSide: holdSignalsReader.requiredEnumByName(
        'referenceSide',
        HoldSide.values,
        'HoldSide',
      ),
      alignment: holdSignalsReader.containsKey('alignment')
          ? holdSignalsReader
                .requiredObject('alignment')
                .requiredAngleLandmarks()
          : null,
      support: holdSignalsReader.containsKey('support')
          ? holdSignalsReader.requiredObject('support').requiredAngleLandmarks()
          : null,
      extension: holdSignalsReader.containsKey('extension')
          ? holdSignalsReader
                .requiredObject('extension')
                .requiredAngleLandmarks()
          : null,
    );
  }

  static RangeRepScoreWeightsConfig? _readRangeRepScoreWeightsOrNull(
    _StrictConfigMapReader reader,
  ) {
    final scoreWeightsReader = reader.optionalObject('rangeRepScoreWeights');
    if (scoreWeightsReader == null) {
      return null;
    }

    return RangeRepScoreWeightsConfig._fromReader(scoreWeightsReader);
  }

  static RangeRepPhaseQualityConfig? _readRangeRepPhaseQualityOrNull(
    _StrictConfigMapReader reader,
  ) {
    final phaseQualityReader = reader.optionalObject('rangeRepPhaseQuality');
    if (phaseQualityReader == null) {
      return null;
    }

    return RangeRepPhaseQualityConfig._fromReader(phaseQualityReader);
  }

  static RangeRepSignalExtractionConfig? _readRangeRepSignalsOrNull(
    _StrictConfigMapReader reader,
  ) {
    final rangeRepSignalsReader = reader.optionalObject('rangeRepSignals');
    if (rangeRepSignalsReader == null) {
      return null;
    }

    rangeRepSignalsReader.expectOnlyKeys(const <String>{
      'postureAngle',
      'depthMetric',
      'alignmentMetric',
      'stabilityMetric',
      'endRangeMetric',
      'bottomControlMetric',
    });

    return RangeRepSignalExtractionConfig(
      postureAngle: _readRangeRepSignalDefinition(
        rangeRepSignalsReader,
        'postureAngle',
      ),
      depthMetric: _readRangeRepSignalDefinition(
        rangeRepSignalsReader,
        'depthMetric',
      ),
      alignmentMetric: _readRangeRepSignalDefinition(
        rangeRepSignalsReader,
        'alignmentMetric',
      ),
      stabilityMetric: _readRangeRepSignalDefinition(
        rangeRepSignalsReader,
        'stabilityMetric',
      ),
      endRangeMetric: _readRangeRepSignalDefinition(
        rangeRepSignalsReader,
        'endRangeMetric',
      ),
      bottomControlMetric: _readRangeRepSignalDefinition(
        rangeRepSignalsReader,
        'bottomControlMetric',
      ),
    );
  }

  static RangeRepSignalDefinition? _readRangeRepSignalDefinition(
    _StrictConfigMapReader reader,
    String signalName,
  ) {
    if (!reader.containsKey(signalName)) {
      return null;
    }

    final signalReader = reader.requiredObject(signalName);
    final keys = signalReader.keys;
    final hasSource = signalReader.containsKey('source');
    final hasAngleTriple =
        signalReader.containsKey('first') ||
        signalReader.containsKey('middle') ||
        signalReader.containsKey('last');

    if (hasSource && hasAngleTriple) {
      throw FormatException(
        '${signalReader.path} must declare either a source or an angle triple, '
        'not both.',
      );
    }

    if (hasSource) {
      if (keys.length != 1) {
        throw FormatException(
          '${signalReader.path} only supports the "source" key for alias '
          'definitions.',
        );
      }

      return RangeRepSignalDefinition.source(
        signalReader.requiredEnumByName(
          'source',
          RangeRepSignalSource.values,
          'RangeRepSignalSource',
        ),
      );
    }

    return RangeRepSignalDefinition.angle(
      signalReader.requiredAngleLandmarks(),
    );
  }

  bool get _matchesLegacySquatRangeRepSignals {
    return primaryJoint == PoseLandmarkType.leftKnee &&
        joint1 == PoseLandmarkType.leftHip &&
        joint2 == PoseLandmarkType.leftAnkle;
  }
}

const RangeRepSignalExtractionConfig _legacySquatRangeRepSignals =
    RangeRepSignalExtractionConfig(
      postureAngle: RangeRepSignalDefinition.angle(
        PoseAngleLandmarks(
          first: PoseLandmarkType.leftShoulder,
          middle: PoseLandmarkType.leftHip,
          last: PoseLandmarkType.leftKnee,
        ),
      ),
      depthMetric: RangeRepSignalDefinition.source(
        RangeRepSignalSource.primaryMetric,
      ),
      alignmentMetric: RangeRepSignalDefinition.angle(
        PoseAngleLandmarks(
          first: PoseLandmarkType.leftShoulder,
          middle: PoseLandmarkType.leftHip,
          last: PoseLandmarkType.leftAnkle,
        ),
      ),
      endRangeMetric: RangeRepSignalDefinition.angle(
        PoseAngleLandmarks(
          first: PoseLandmarkType.leftHip,
          middle: PoseLandmarkType.leftKnee,
          last: PoseLandmarkType.leftAnkle,
        ),
      ),
    );

class _StrictConfigMapReader {
  const _StrictConfigMapReader._(this.path, this._map);

  factory _StrictConfigMapReader.root(String path, Map<String, dynamic> map) {
    return _StrictConfigMapReader._(path, Map<String, dynamic>.from(map));
  }

  final String path;
  final Map<String, dynamic> _map;

  Set<String> get keys => _map.keys.toSet();

  bool containsKey(String key) => _map.containsKey(key);

  _StrictConfigMapReader? optionalObject(String key) {
    final value = _map[key];
    if (value == null) {
      return null;
    }

    return _objectFromValue(key, value);
  }

  _StrictConfigMapReader requiredObject(String key) {
    return _objectFromValue(key, _map[key]);
  }

  String requiredString(String key) {
    final value = _map[key];
    if (value is String) {
      return value;
    }

    throw FormatException('${_childPath(key)} must be a String.');
  }

  double requiredDouble(String key, {double? fallback}) {
    final value = _map[key];
    if (value == null) {
      if (fallback != null) {
        return fallback;
      }
      throw FormatException('${_childPath(key)} must be a number.');
    }

    return _parseDouble(key, value);
  }

  double? optionalDouble(String key) {
    final value = _map[key];
    if (value == null) {
      return null;
    }

    return _parseDouble(key, value);
  }

  int requiredInt(String key, {int? fallback}) {
    final value = _map[key];
    if (value == null) {
      if (fallback != null) {
        return fallback;
      }
      throw FormatException('${_childPath(key)} must be an integer.');
    }

    return _parseInt(key, value);
  }

  int? optionalInt(String key) {
    final value = _map[key];
    if (value == null) {
      return null;
    }

    return _parseInt(key, value);
  }

  PoseLandmarkType requiredPoseLandmark(String key) {
    return requiredEnumByName(key, PoseLandmarkType.values, 'PoseLandmarkType');
  }

  T requiredEnumByName<T extends Enum>(
    String key,
    List<T> values,
    String enumName,
  ) {
    final value = requiredString(key);
    try {
      return values.byName(value);
    } on ArgumentError {
      throw FormatException(
        'Unsupported $enumName for ${_childPath(key)}: $value',
      );
    }
  }

  void expectOnlyKeys(Set<String> allowedKeys) {
    final unexpectedKeys = _map.keys
        .where((key) => !allowedKeys.contains(key))
        .toList(growable: false);
    if (unexpectedKeys.isNotEmpty) {
      throw FormatException(
        'Unsupported key at $path: ${unexpectedKeys.first}',
      );
    }
  }

  PoseAngleLandmarks requiredAngleLandmarks() {
    const expectedKeys = <String>{'first', 'middle', 'last'};
    final presentKeys = keys;
    if (!presentKeys.containsAll(expectedKeys) ||
        presentKeys.length != expectedKeys.length) {
      throw FormatException(
        '$path must define exactly "first", "middle", and "last".',
      );
    }

    final first = requiredPoseLandmark('first');
    final middle = requiredPoseLandmark('middle');
    final last = requiredPoseLandmark('last');
    if (first == middle || first == last || middle == last) {
      throw FormatException('$path must define three distinct landmarks.');
    }

    return PoseAngleLandmarks(first: first, middle: middle, last: last);
  }

  _StrictConfigMapReader _objectFromValue(String key, Object? value) {
    if (value is! Map) {
      throw FormatException('${_childPath(key)} must be an object.');
    }

    return _StrictConfigMapReader._(
      _childPath(key),
      Map<String, dynamic>.from(value),
    );
  }

  double _parseDouble(String key, Object value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      try {
        return double.parse(value);
      } on FormatException {
        throw FormatException('${_childPath(key)} must be a number.');
      }
    }

    throw FormatException('${_childPath(key)} must be a number.');
  }

  int _parseInt(String key, Object value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      try {
        return int.parse(value);
      } on FormatException {
        throw FormatException('${_childPath(key)} must be an integer.');
      }
    }

    throw FormatException('${_childPath(key)} must be an integer.');
  }

  String _childPath(String key) => '$path.$key';
}
