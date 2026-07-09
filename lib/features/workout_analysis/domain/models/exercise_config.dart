import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

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
  });

  HoldPostureConfig get resolvedHoldPosture {
    return holdPosture ?? HoldPostureConfig.legacy(this);
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

    final name = map['name'];
    if (name is! String) {
      throw FormatException('ExerciseConfig.name must be a String.');
    }

    final holdPosture = readHoldPostureOrNull();
    final rangeRepScoreWeights = readRangeRepScoreWeightsOrNull();
    final rangeRepPhaseQuality = readRangeRepPhaseQualityOrNull();

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
    );
  }
}
