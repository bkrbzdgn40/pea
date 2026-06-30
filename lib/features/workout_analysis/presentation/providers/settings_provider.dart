import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WorkoutCameraPreference { front, back }

extension WorkoutCameraPreferenceLabel on WorkoutCameraPreference {
  String get label {
    return switch (this) {
      WorkoutCameraPreference.front => 'Ön kamera',
      WorkoutCameraPreference.back => 'Arka kamera',
    };
  }
}

enum WorkoutCameraQuality { low, medium, high }

extension WorkoutCameraQualityLabel on WorkoutCameraQuality {
  String get label {
    return switch (this) {
      WorkoutCameraQuality.low => 'Düşük',
      WorkoutCameraQuality.medium => 'Orta',
      WorkoutCameraQuality.high => 'Yüksek',
    };
  }
}

class WorkoutSettings {
  const WorkoutSettings({
    this.cameraPreference = WorkoutCameraPreference.front,
    this.cameraQuality = WorkoutCameraQuality.low,
  });

  final WorkoutCameraPreference cameraPreference;
  final WorkoutCameraQuality cameraQuality;

  WorkoutSettings copyWith({
    WorkoutCameraPreference? cameraPreference,
    WorkoutCameraQuality? cameraQuality,
  }) {
    return WorkoutSettings(
      cameraPreference: cameraPreference ?? this.cameraPreference,
      cameraQuality: cameraQuality ?? this.cameraQuality,
    );
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, WorkoutSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<WorkoutSettings> {
  static const _cameraPreferenceKey = 'settings.cameraPreference';
  static const _cameraQualityKey = 'settings.cameraQuality';

  @override
  Future<WorkoutSettings> build() async {
    final preferences = await SharedPreferences.getInstance();

    return WorkoutSettings(
      cameraPreference: _cameraPreferenceFromName(
        preferences.getString(_cameraPreferenceKey),
      ),
      cameraQuality: _cameraQualityFromName(
        preferences.getString(_cameraQualityKey),
      ),
    );
  }

  Future<void> setCameraPreference(WorkoutCameraPreference preference) async {
    final updated = (state.valueOrNull ?? const WorkoutSettings()).copyWith(
      cameraPreference: preference,
    );

    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> setCameraQuality(WorkoutCameraQuality quality) async {
    final updated = (state.valueOrNull ?? const WorkoutSettings()).copyWith(
      cameraQuality: quality,
    );

    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> _save(WorkoutSettings settings) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _cameraPreferenceKey,
      settings.cameraPreference.name,
    );
    await preferences.setString(_cameraQualityKey, settings.cameraQuality.name);
  }
}

WorkoutCameraPreference _cameraPreferenceFromName(String? name) {
  return WorkoutCameraPreference.values.firstWhere(
    (preference) => preference.name == name,
    orElse: () => WorkoutCameraPreference.front,
  );
}

WorkoutCameraQuality _cameraQualityFromName(String? name) {
  return WorkoutCameraQuality.values.firstWhere(
    (quality) => quality.name == name,
    orElse: () => WorkoutCameraQuality.low,
  );
}
