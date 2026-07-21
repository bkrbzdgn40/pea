import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  turkish('tr'),
  english('en');

  const AppLanguage(this.languageCode);

  final String languageCode;
}

enum WorkoutCameraPreference { front, back }

enum WorkoutCameraQuality { low, medium, high }

class WorkoutSettings {
  const WorkoutSettings({
    this.language = AppLanguage.turkish,
    this.cameraPreference = WorkoutCameraPreference.front,
    this.cameraQuality = WorkoutCameraQuality.low,
  });

  final AppLanguage language;
  final WorkoutCameraPreference cameraPreference;
  final WorkoutCameraQuality cameraQuality;

  WorkoutSettings copyWith({
    AppLanguage? language,
    WorkoutCameraPreference? cameraPreference,
    WorkoutCameraQuality? cameraQuality,
  }) {
    return WorkoutSettings(
      language: language ?? this.language,
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
  static const _languageKey = 'settings.language';
  static const _cameraPreferenceKey = 'settings.cameraPreference';
  static const _cameraQualityKey = 'settings.cameraQuality';

  @override
  Future<WorkoutSettings> build() async {
    final preferences = await SharedPreferences.getInstance();

    return WorkoutSettings(
      language: _appLanguageFromName(preferences.getString(_languageKey)),
      cameraPreference: _cameraPreferenceFromName(
        preferences.getString(_cameraPreferenceKey),
      ),
      cameraQuality: _cameraQualityFromName(
        preferences.getString(_cameraQualityKey),
      ),
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    final updated = (state.valueOrNull ?? const WorkoutSettings()).copyWith(
      language: language,
    );

    state = AsyncData(updated);
    await _save(updated);
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

    await preferences.setString(_languageKey, settings.language.name);
    await preferences.setString(
      _cameraPreferenceKey,
      settings.cameraPreference.name,
    );
    await preferences.setString(_cameraQualityKey, settings.cameraQuality.name);
  }
}

AppLanguage _appLanguageFromName(String? name) {
  return AppLanguage.values.firstWhere(
    (language) => language.name == name,
    orElse: () => AppLanguage.turkish,
  );
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
