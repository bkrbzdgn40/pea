import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../auth/presentation/providers/auth_bootstrap_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../application/feedback_delivery_controller.dart';
import '../providers/settings_provider.dart';
import '../providers/user_data_management_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDeletingHistory = false;
  bool _isDeletingAccount = false;

  bool get _isDeletingData => _isDeletingHistory || _isDeletingAccount;

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 16),
              _SettingsSection(
                title: localizations.privacyAndData,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Text(
                      localizations.savedWorkoutDataExplanation,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  _DestructiveSettingsTile(
                    key: const ValueKey<String>('settings-delete-all-history'),
                    title: localizations.deleteAllHistory,
                    subtitle: localizations.deleteAllHistoryDescription,
                    isBusy: _isDeletingHistory,
                    onTap: _isDeletingData ? null : _deleteAllHistory,
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  _DestructiveSettingsTile(
                    key: const ValueKey<String>('settings-delete-account'),
                    title: localizations.deleteAccountAndData,
                    subtitle: localizations.deleteAccountAndDataDescription,
                    isBusy: _isDeletingAccount,
                    onTap: _isDeletingData ? null : _deleteAccountAndData,
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

  Future<void> _deleteAllHistory() async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await _confirmDestructiveAction(
      title: localizations.deleteAllHistoryTitle,
      message: localizations.deleteAllHistoryMessage,
      confirmKey: const ValueKey<String>('confirm-delete-all-history'),
    );
    if (!confirmed || !mounted) return;

    setState(() => _isDeletingHistory = true);
    try {
      await ref.read(userDataManagementControllerProvider).deleteAllHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizations.allHistoryDeleted)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.allHistoryDeleteFailed)),
      );
    } finally {
      if (mounted) setState(() => _isDeletingHistory = false);
    }
  }

  Future<void> _deleteAccountAndData() async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await _confirmDestructiveAction(
      title: localizations.deleteAccountTitle,
      message: localizations.deleteAccountMessage,
      confirmKey: const ValueKey<String>('confirm-delete-account'),
    );
    if (!confirmed || !mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      await ref
          .read(userDataManagementControllerProvider)
          .deleteAccountAndData();
      ref.invalidate(authStateChangesProvider);
      ref.invalidate(authBootstrapProvider);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.accountDeleteFailed)),
      );
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  Future<bool> _confirmDestructiveAction({
    required String title,
    required String message,
    required Key confirmKey,
  }) async {
    final localizations = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(localizations.cancel),
                ),
                TextButton(
                  key: confirmKey,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  child: Text(localizations.delete),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

class _DestructiveSettingsTile extends StatelessWidget {
  const _DestructiveSettingsTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isBusy,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.redAccent)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
      ),
      trailing: isBusy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.delete_outline, color: Colors.redAccent),
      enabled: onTap != null,
      onTap: onTap,
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
