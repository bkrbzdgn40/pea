import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../application/feedback_delivery_controller.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);
    final localizations = AppLocalizations.of(context);

    return AppScaffoldShell(
      title: localizations.settings,
      currentPage: AppDestination.settings,
      padding: EdgeInsets.zero,
      body: settingsState.when(
        data: (settings) {
          final controller = ref.read(settingsControllerProvider.notifier);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _SettingsSection(
                title: localizations.language,
                children: [
                  _SettingsDropdownTile<AppLanguage>(
                    title: localizations.appLanguage,
                    value: settings.language,
                    values: AppLanguage.values,
                    labelFor: (language) => switch (language) {
                      AppLanguage.turkish => localizations.turkish,
                      AppLanguage.english => localizations.english,
                    },
                    onChanged: (language) {
                      if (language == null) return;

                      unawaited(controller.setLanguage(language));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: localizations.liveFeedback,
                children: [
                  _SettingsSwitchTile(
                    key: const ValueKey<String>('settings-voice-coach-switch'),
                    title: localizations.voiceCoach,
                    subtitle: localizations.voiceCoachDescription,
                    value: settings.voiceCoachEnabled,
                    onChanged: (enabled) {
                      unawaited(controller.setVoiceCoachEnabled(enabled));
                    },
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  _SettingsDropdownTile<FeedbackFrequency>(
                    key: const ValueKey<String>(
                      'settings-feedback-frequency-dropdown',
                    ),
                    title: localizations.feedbackFrequency,
                    subtitle: localizations.feedbackFrequencyDescription,
                    value: settings.feedbackFrequency,
                    values: FeedbackFrequency.values,
                    labelFor: (frequency) => switch (frequency) {
                      FeedbackFrequency.reduced =>
                        localizations.feedbackFrequencyReduced,
                      FeedbackFrequency.normal =>
                        localizations.feedbackFrequencyNormal,
                      FeedbackFrequency.frequent =>
                        localizations.feedbackFrequencyFrequent,
                    },
                    onChanged: (frequency) {
                      if (frequency == null) return;

                      unawaited(controller.setFeedbackFrequency(frequency));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: localizations.camera,
                children: [
                  _SettingsDropdownTile<WorkoutCameraPreference>(
                    title: localizations.cameraPreference,
                    value: settings.cameraPreference,
                    values: WorkoutCameraPreference.values,
                    labelFor: (preference) => switch (preference) {
                      WorkoutCameraPreference.front =>
                        localizations.frontCamera,
                      WorkoutCameraPreference.back => localizations.backCamera,
                    },
                    onChanged: (preference) {
                      if (preference == null) return;

                      unawaited(controller.setCameraPreference(preference));
                    },
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  _SettingsDropdownTile<WorkoutCameraQuality>(
                    title: localizations.imageQuality,
                    value: settings.cameraQuality,
                    values: WorkoutCameraQuality.values,
                    labelFor: (quality) => switch (quality) {
                      WorkoutCameraQuality.low => localizations.low,
                      WorkoutCameraQuality.medium => localizations.medium,
                      WorkoutCameraQuality.high => localizations.high,
                    },
                    onChanged: (quality) {
                      if (quality == null) return;

                      unawaited(controller.setCameraQuality(quality));
                    },
                  ),
                ],
              ),
            ],
          );
        },
        loading: () {
          return const Center(
            child: CircularProgressIndicator(color: Colors.greenAccent),
          );
        },
        error: (error, _) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.settings_outlined,
                    color: Colors.greenAccent,
                    size: 40,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    localizations.settingsLoadFailed,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => ref.invalidate(settingsControllerProvider),
                    child: Text(localizations.retry),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsDropdownTile<T> extends StatelessWidget {
  const _SettingsDropdownTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        subtitle ?? labelFor(value),
        style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
      ),
      trailing: DropdownButton<T>(
        value: value,
        dropdownColor: const Color(0xFF202020),
        underline: const SizedBox.shrink(),
        iconEnabledColor: Colors.greenAccent,
        style: const TextStyle(color: Colors.white),
        items: values
            .map(
              (item) =>
                  DropdownMenuItem<T>(value: item, child: Text(labelFor(item))),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.greenAccent,
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
