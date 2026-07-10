import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'range_rep_contract.dart';

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
    double? readDoubleOrNull(String key) {
      final value = map[key];
      if (value == null) {
        return null;
      }
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.parse(value);
      }

      throw FormatException(
        'RangeRepScoreWeightsConfig.$key must be a number.',
      );
    }

    return RangeRepScoreWeightsConfig(
      depthWeight: readDoubleOrNull('depthWeight'),
      postureWeight: readDoubleOrNull('postureWeight'),
      stabilityWeight: readDoubleOrNull('stabilityWeight'),
      descentControlWeight: readDoubleOrNull('descentControlWeight'),
      ascentControlWeight: readDoubleOrNull('ascentControlWeight'),
      consistencyWeight: readDoubleOrNull('consistencyWeight'),
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
    int? readIntOrNull(String key) {
      final value = map[key];
      if (value == null) {
        return null;
      }
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.round();
      }
      if (value is String) {
        return int.parse(value);
      }

      throw FormatException(
        'RangeRepPhaseQualityConfig.$key must be an integer.',
      );
    }

    return RangeRepPhaseQualityConfig(
      minDescendingMillis: readIntOrNull('minDescendingMillis'),
      minAscendingMillis: readIntOrNull('minAscendingMillis'),
    );
  }
}

enum RangeRepSignalSource { primaryMetric }

class RangeRepAngleSignalConfig {
  const RangeRepAngleSignalConfig({
    required this.first,
    required this.middle,
    required this.last,
  });

  final PoseLandmarkType first;
  final PoseLandmarkType middle;
  final PoseLandmarkType last;
}

class RangeRepSignalDefinition {
  const RangeRepSignalDefinition.angle(this.angle) : source = null;

  const RangeRepSignalDefinition.source(this.source) : angle = null;

  final RangeRepAngleSignalConfig? angle;
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
    double readDouble(String key) {
      final value = map[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.parse(value);
      }

      throw FormatException('HoldPostureConfig.$key must be a number.');
    }

    int readInt(String key) {
      final value = map[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.round();
      }
      if (value is String) {
        return int.parse(value);
      }

      throw FormatException('HoldPostureConfig.$key must be an integer.');
    }

    return HoldPostureConfig(
      activePostureAngle: readDouble('activePostureAngle'),
      bodyLineEntryAngle: readDouble('bodyLineEntryAngle'),
      bodyLineSustainAngle: readDouble('bodyLineSustainAngle'),
      armSupportMinAngle: readDouble('armSupportMinAngle'),
      armSupportMaxAngle: readDouble('armSupportMaxAngle'),
      legExtensionMinAngle: readDouble('legExtensionMinAngle'),
      breakGraceDuration: Duration(milliseconds: readInt('breakGraceMillis')),
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
    PoseLandmarkType readLandmark(String key) {
      final value = map[key];
      if (value is! String) {
        throw FormatException('ExerciseConfig.$key must be a String.');
      }

      try {
        return PoseLandmarkType.values.byName(value);
      } on ArgumentError {
        throw FormatException('Unsupported PoseLandmarkType for $key: $value');
      }
    }

    double readDouble(String key, {double? fallback}) {
      final value = map[key];
      if (value == null) {
        if (fallback != null) {
          return fallback;
        }
        throw FormatException('ExerciseConfig.$key must be a number.');
      }
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.parse(value);
      }

      throw FormatException('ExerciseConfig.$key must be a number.');
    }

    HoldPostureConfig? readHoldPostureOrNull() {
      final value = map['holdPosture'];
      if (value == null) {
        return null;
      }
      if (value is! Map) {
        throw FormatException('ExerciseConfig.holdPosture must be an object.');
      }

      return HoldPostureConfig.fromMap(Map<String, dynamic>.from(value));
    }

    RangeRepScoreWeightsConfig? readRangeRepScoreWeightsOrNull() {
      final value = map['rangeRepScoreWeights'];
      if (value == null) {
        return null;
      }
      if (value is! Map) {
        throw FormatException(
          'ExerciseConfig.rangeRepScoreWeights must be an object.',
        );
      }

      return RangeRepScoreWeightsConfig.fromMap(
        Map<String, dynamic>.from(value),
      );
    }

    RangeRepPhaseQualityConfig? readRangeRepPhaseQualityOrNull() {
      final value = map['rangeRepPhaseQuality'];
      if (value == null) {
        return null;
      }
      if (value is! Map) {
        throw FormatException(
          'ExerciseConfig.rangeRepPhaseQuality must be an object.',
        );
      }

      return RangeRepPhaseQualityConfig.fromMap(
        Map<String, dynamic>.from(value),
      );
    }

    RangeRepSignalSource readRangeRepSignalSource(
      String key,
      String signalName,
    ) {
      final value = key;
      try {
        return RangeRepSignalSource.values.byName(value);
      } on ArgumentError {
        throw FormatException(
          'Unsupported RangeRepSignalSource for '
          'ExerciseConfig.rangeRepSignals.$signalName.source: $value',
        );
      }
    }

    RangeRepSignalDefinition? readRangeRepSignalDefinition(
      String signalName,
      Object? rawValue,
    ) {
      if (rawValue == null) {
        return null;
      }
      if (rawValue is! Map) {
        throw FormatException(
          'ExerciseConfig.rangeRepSignals.$signalName must be an object.',
        );
      }

      final map = Map<String, dynamic>.from(rawValue);
      final keys = map.keys.toSet();
      final hasSource = keys.contains('source');
      final hasAngleTriple =
          keys.contains('first') ||
          keys.contains('middle') ||
          keys.contains('last');

      if (hasSource && hasAngleTriple) {
        throw FormatException(
          'ExerciseConfig.rangeRepSignals.$signalName must declare either '
          'a source or an angle triple, not both.',
        );
      }

      if (hasSource) {
        if (keys.length != 1) {
          throw FormatException(
            'ExerciseConfig.rangeRepSignals.$signalName only supports the '
            '"source" key for alias definitions.',
          );
        }
        final source = map['source'];
        if (source is! String) {
          throw FormatException(
            'ExerciseConfig.rangeRepSignals.$signalName.source must be a String.',
          );
        }

        return RangeRepSignalDefinition.source(
          readRangeRepSignalSource(source, signalName),
        );
      }

      final expectedAngleKeys = <String>{'first', 'middle', 'last'};
      if (!keys.containsAll(expectedAngleKeys) || keys.length != 3) {
        throw FormatException(
          'ExerciseConfig.rangeRepSignals.$signalName must define exactly '
          '"first", "middle", and "last".',
        );
      }

      PoseLandmarkType readSignalLandmark(String partKey) {
        final value = map[partKey];
        if (value is! String) {
          throw FormatException(
            'ExerciseConfig.rangeRepSignals.$signalName.$partKey must be a String.',
          );
        }

        try {
          return PoseLandmarkType.values.byName(value);
        } on ArgumentError {
          throw FormatException(
            'Unsupported PoseLandmarkType for '
            'ExerciseConfig.rangeRepSignals.$signalName.$partKey: $value',
          );
        }
      }

      return RangeRepSignalDefinition.angle(
        RangeRepAngleSignalConfig(
          first: readSignalLandmark('first'),
          middle: readSignalLandmark('middle'),
          last: readSignalLandmark('last'),
        ),
      );
    }

    RangeRepSignalExtractionConfig? readRangeRepSignalsOrNull() {
      final value = map['rangeRepSignals'];
      if (value == null) {
        return null;
      }
      if (value is! Map) {
        throw FormatException(
          'ExerciseConfig.rangeRepSignals must be an object.',
        );
      }

      final signalMap = Map<String, dynamic>.from(value);
      final allowedKeys = <String>{
        'postureAngle',
        'depthMetric',
        'alignmentMetric',
        'stabilityMetric',
        'endRangeMetric',
        'bottomControlMetric',
      };
      final unexpectedKeys = signalMap.keys
          .where((key) => !allowedKeys.contains(key))
          .toList(growable: false);
      if (unexpectedKeys.isNotEmpty) {
        throw FormatException(
          'Unsupported ExerciseConfig.rangeRepSignals key: '
          '${unexpectedKeys.first}',
        );
      }

      return RangeRepSignalExtractionConfig(
        postureAngle: readRangeRepSignalDefinition(
          'postureAngle',
          signalMap['postureAngle'],
        ),
        depthMetric: readRangeRepSignalDefinition(
          'depthMetric',
          signalMap['depthMetric'],
        ),
        alignmentMetric: readRangeRepSignalDefinition(
          'alignmentMetric',
          signalMap['alignmentMetric'],
        ),
        stabilityMetric: readRangeRepSignalDefinition(
          'stabilityMetric',
          signalMap['stabilityMetric'],
        ),
        endRangeMetric: readRangeRepSignalDefinition(
          'endRangeMetric',
          signalMap['endRangeMetric'],
        ),
        bottomControlMetric: readRangeRepSignalDefinition(
          'bottomControlMetric',
          signalMap['bottomControlMetric'],
        ),
      );
    }

    final name = map['name'];
    if (name is! String) {
      throw FormatException('ExerciseConfig.name must be a String.');
    }

    final holdPosture = readHoldPostureOrNull();
    final rangeRepScoreWeights = readRangeRepScoreWeightsOrNull();
    final rangeRepPhaseQuality = readRangeRepPhaseQualityOrNull();
    final rangeRepSignals = readRangeRepSignalsOrNull();

    return ExerciseConfig(
      name: name,
      primaryJoint: readLandmark('primaryJoint'),
      joint1: readLandmark('joint1'),
      joint2: readLandmark('joint2'),
      thresholdNeutral: readDouble(
        'thresholdNeutral',
        fallback: holdPosture?.activePostureAngle,
      ),
      thresholdActive: readDouble(
        'thresholdActive',
        fallback: holdPosture?.bodyLineEntryAngle,
      ),
      thresholdPeak: readDouble('thresholdPeak', fallback: 0.0),
      idealDescentSeconds: readDouble('idealDescentSeconds', fallback: 0.0),
      idealAscentSeconds: readDouble('idealAscentSeconds', fallback: 0.0),
      formThreshold: readDouble('formThreshold', fallback: 0.0),
      targetMinAngle: readDouble('targetMinAngle', fallback: 0.0),
      tempoPenaltyPerSecond: readDouble('tempoPenaltyPerSecond', fallback: 0.0),
      holdPosture: holdPosture,
      rangeRepScoreWeights: rangeRepScoreWeights,
      rangeRepPhaseQuality: rangeRepPhaseQuality,
      rangeRepSignals: rangeRepSignals,
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
        RangeRepAngleSignalConfig(
          first: PoseLandmarkType.leftShoulder,
          middle: PoseLandmarkType.leftHip,
          last: PoseLandmarkType.leftKnee,
        ),
      ),
      depthMetric: RangeRepSignalDefinition.source(
        RangeRepSignalSource.primaryMetric,
      ),
      alignmentMetric: RangeRepSignalDefinition.angle(
        RangeRepAngleSignalConfig(
          first: PoseLandmarkType.leftShoulder,
          middle: PoseLandmarkType.leftHip,
          last: PoseLandmarkType.leftAnkle,
        ),
      ),
      endRangeMetric: RangeRepSignalDefinition.angle(
        RangeRepAngleSignalConfig(
          first: PoseLandmarkType.leftHip,
          middle: PoseLandmarkType.leftKnee,
          last: PoseLandmarkType.leftAnkle,
        ),
      ),
    );
