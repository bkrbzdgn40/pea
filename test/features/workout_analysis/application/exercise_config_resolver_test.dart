import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_config_resolver.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  group('ExerciseConfigResolver', () {
    test('loads the unchanged squat config asset path', () async {
      final source = _FakeExerciseConfigSource(_sampleConfig());
      final resolver = ExerciseConfigResolver(source: source);

      final config = await resolver.resolve(ExerciseType.squat);

      expect(config.name, 'Sample');
      expect(source.loadedAssetPaths, <String>[
        'assets/config/exercises/squat.json',
      ]);
    });

    test('loads the unchanged plank config asset path', () async {
      final source = _FakeExerciseConfigSource(_sampleConfig());
      final resolver = ExerciseConfigResolver(source: source);

      await resolver.resolve(ExerciseType.plank);

      expect(source.loadedAssetPaths, <String>[
        'assets/config/exercises/plank.json',
      ]);
    });

    test('loads the sit-up config asset path', () async {
      final source = _FakeExerciseConfigSource(_sampleConfig());
      final resolver = ExerciseConfigResolver(source: source);

      await resolver.resolve(ExerciseType.sitUp);

      expect(source.loadedAssetPaths, <String>[
        'assets/config/exercises/sit_up.json',
      ]);
    });

    test('rejects unsupported exercises before loading a config', () async {
      final source = _FakeExerciseConfigSource(_sampleConfig());
      final resolver = ExerciseConfigResolver(source: source);

      expect(
        () => resolver.resolve(ExerciseType.lunge),
        throwsA(isA<StateError>()),
      );
      expect(source.loadedAssetPaths, isEmpty);
    });
  });
}

class _FakeExerciseConfigSource implements ExerciseConfigSource {
  _FakeExerciseConfigSource(this._config);

  final ExerciseConfig _config;
  final List<String> loadedAssetPaths = <String>[];

  @override
  Future<ExerciseConfig> loadConfig(String assetPath) async {
    loadedAssetPaths.add(assetPath);
    return _config;
  }
}

ExerciseConfig _sampleConfig() {
  return ExerciseConfig(
    name: 'Sample',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160.0,
    thresholdActive: 150.0,
    thresholdPeak: 95.0,
  );
}
