import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../application/feedback_delivery_controller.dart';

enum AppLanguage {
  turkish('tr'),
  english('en');

  const AppLanguage(this.languageCode);

  final String languageCode;
}

final runtimeAppLanguageProvider = StateProvider<AppLanguage>(
  (ref) => AppLanguage.turkish,
);

final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final language = ref.watch(runtimeAppLanguageProvider);
  return AppLocalizations(Locale(language.languageCode));
});

enum WorkoutCameraPreference { front, back }

enum WorkoutCameraQuality { low, medium, high }

class WorkoutSettings {
  const WorkoutSettings({
    this.language = AppLanguage.turkish,
    this.cameraPreference = WorkoutCameraPreference.front,
    this.cameraQuality = WorkoutCameraQuality.low,
    this.voiceCoachEnabled = true,
    this.feedbackFrequency = FeedbackFrequency.normal,
  });

  final AppLanguage language;
  final WorkoutCameraPreference cameraPreference;
  final WorkoutCameraQuality cameraQuality;
  final bool voiceCoachEnabled;
  final FeedbackFrequency feedbackFrequency;

  WorkoutSettings copyWith({
    AppLanguage? language,
    WorkoutCameraPreference? cameraPreference,
    WorkoutCameraQuality? cameraQuality,
    bool? voiceCoachEnabled,
    FeedbackFrequency? feedbackFrequency,
  }) {
    return WorkoutSettings(
      language: language ?? this.language,
      cameraPreference: cameraPreference ?? this.cameraPreference,
      cameraQuality: cameraQuality ?? this.cameraQuality,
      voiceCoachEnabled: voiceCoachEnabled ?? this.voiceCoachEnabled,
      feedbackFrequency: feedbackFrequency ?? this.feedbackFrequency,
    );
  }
}

final runtimeWorkoutSettingsProvider = StateProvider<WorkoutSettings>(
  (ref) => const WorkoutSettings(),
);

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, WorkoutSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<WorkoutSettings> {
  static const _languageKey = 'settings.language';
  static const _cameraPreferenceKey = 'settings.cameraPreference';
  static const _cameraQualityKey = 'settings.cameraQuality';
  static const _voiceCoachEnabledKey = 'settings.voiceCoachEnabled';
  static const _feedbackFrequencyKey = 'settings.feedbackFrequency';

  @override
  Future<WorkoutSettings> build() async {
    final preferences = await SharedPreferences.getInstance();
    final settings = WorkoutSettings(
      language: _appLanguageFromName(preferences.getString(_languageKey)),
      cameraPreference: _cameraPreferenceFromName(
        preferences.getString(_cameraPreferenceKey),
      ),
      cameraQuality: _cameraQualityFromName(
        preferences.getString(_cameraQualityKey),
      ),
      voiceCoachEnabled: preferences.getBool(_voiceCoachEnabledKey) ?? true,
      feedbackFrequency: _feedbackFrequencyFromName(
        preferences.getString(_feedbackFrequencyKey),
      ),
    );
    _publishRuntimeSettings(settings);
    return settings;
  }

  Future<void> setLanguage(AppLanguage language) async {
    final updated = (state.valueOrNull ?? const WorkoutSettings()).copyWith(
      language: language,
    );

    state = AsyncData(updated);
    _publishRuntimeSettings(updated);
    await _save(updated);
  }

  Future<void> setCameraPreference(WorkoutCameraPreference preference) async {
    final updated = (state.valueOrNull ?? const WorkoutSettings()).copyWith(
      cameraPreference: preference,
    );

    state = AsyncData(updated);
    _publishRuntimeSettings(updated);
    await _save(updated);
  }

  Future<void> setCameraQuality(WorkoutCameraQuality quality) async {
    final updated = (state.valueOrNull ?? const WorkoutSettings()).copyWith(
      cameraQuality: quality,
    );

    state = AsyncData(updated);
    _publishRuntimeSettings(updated);
    await _save(updated);
  }

  Future<void> setVoiceCoachEnabled(bool enabled) async {
    final updated = (state.valueOrNull ?? const WorkoutSettings()).copyWith(
      voiceCoachEnabled: enabled,
    );

    state = AsyncData(updated);
    _publishRuntimeSettings(updated);
    await _save(updated);
  }

  Future<void> setFeedbackFrequency(FeedbackFrequency frequency) async {
    final updated = (state.valueOrNull ?? const WorkoutSettings()).copyWith(
      feedbackFrequency: frequency,
    );

    state = AsyncData(updated);
    _publishRuntimeSettings(updated);
    await _save(updated);
  }

  void _publishRuntimeSettings(WorkoutSettings settings) {
    ref.read(runtimeWorkoutSettingsProvider.notifier).state = settings;
    ref.read(runtimeAppLanguageProvider.notifier).state = settings.language;
  }

  Future<void> _save(WorkoutSettings settings) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_languageKey, settings.language.name);
    await preferences.setString(
      _cameraPreferenceKey,
      settings.cameraPreference.name,
    );
    await preferences.setString(_cameraQualityKey, settings.cameraQuality.name);
    await preferences.setBool(
      _voiceCoachEnabledKey,
      settings.voiceCoachEnabled,
    );
    await preferences.setString(
      _feedbackFrequencyKey,
      settings.feedbackFrequency.name,
    );
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

FeedbackFrequency _feedbackFrequencyFromName(String? name) {
  return FeedbackFrequency.values.firstWhere(
    (frequency) => frequency.name == name,
    orElse: () => FeedbackFrequency.normal,
  );
}
