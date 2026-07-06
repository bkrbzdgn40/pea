import 'dart:convert';

import 'package:flutter/services.dart';

import '../../application/exercise_config_resolver.dart';
import '../../domain/models/exercise_config.dart';

/// Loads exercise config assets from the bundled app assets.
class AssetExerciseConfigSource implements ExerciseConfigSource {
  const AssetExerciseConfigSource();

  @override
  Future<ExerciseConfig> loadConfig(String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map) {
      throw FormatException(
        'Exercise config asset must decode to a JSON object.',
      );
    }

    return ExerciseConfig.fromMap(Map<String, dynamic>.from(decoded));
  }
}
