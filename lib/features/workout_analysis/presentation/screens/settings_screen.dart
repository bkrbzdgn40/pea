import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_button.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_section.dart';
import '../../../../app/presentation/widgets/app_state_views.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
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
      maxContentWidth: 760,
      body: settingsState.when(
        data: (settings) {
          final controller = ref.read(settingsControllerProvider.notifier);
          return ListView(
            key: const PageStorageKey<String>('settings-content'),
            padding: AppSpacing.pagePadding,
            children: [
              AppSection(
                title: localizations.settingsAnalysisExperience,
                description:
                    localizations.settingsAnalysisExperienceDescription,
                child: _SettingsGroupCard(
                  children: [
                    _SettingsSwitchRow(
                      key: const ValueKey<String>(
                        'settings-voice-coach-switch',
                      ),
                      title: localizations.voiceCoach,
                      description: localizations.voiceCoachDescription,
                      value: settings.voiceCoachEnabled,
                      onChanged: (enabled) {
                        unawaited(controller.setVoiceCoachEnabled(enabled));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                title: localizations.settingsFeedback,
                description: localizations.settingsFeedbackDescription,
                child: _SettingsGroupCard(
                  children: [
                    _SettingsDropdownRow<FeedbackFrequency>(
                      key: const ValueKey<String>(
                        'settings-feedback-frequency-dropdown',
                      ),
                      title: localizations.feedbackFrequency,
                      description: localizations.feedbackFrequencyDescription,
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
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                title: localizations.camera,
                description: localizations.settingsCameraDescription,
                child: _SettingsGroupCard(
                  children: [
                    _SettingsDropdownRow<WorkoutCameraPreference>(
                      key: const ValueKey<String>(
                        'settings-camera-preference-dropdown',
                      ),
                      title: localizations.cameraPreference,
                      description: localizations.cameraPreferenceDescription,
                      value: settings.cameraPreference,
                      values: WorkoutCameraPreference.values,
                      labelFor: (preference) => switch (preference) {
                        WorkoutCameraPreference.front =>
                          localizations.frontCamera,
                        WorkoutCameraPreference.back =>
                          localizations.backCamera,
                      },
                      onChanged: (preference) {
                        if (preference == null) return;
                        unawaited(controller.setCameraPreference(preference));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                title: localizations.settingsLanguageAndAppearance,
                description:
                    localizations.settingsLanguageAndAppearanceDescription,
                child: _SettingsGroupCard(
                  children: [
                    _SettingsDropdownRow<AppLanguage>(
                      key: const ValueKey<String>('settings-language-dropdown'),
                      title: localizations.appLanguage,
                      description: localizations.appLanguageDescription,
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
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                title: localizations.settingsAdvancedAnalysis,
                description: localizations.settingsAdvancedAnalysisDescription,
                child: _SettingsGroupCard(
                  children: [
                    _SettingsDropdownRow<WorkoutCameraQuality>(
                      key: const ValueKey<String>(
                        'settings-camera-quality-dropdown',
                      ),
                      title: localizations.imageQuality,
                      description: localizations.imageQualityDescription,
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
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                title: localizations.settingsDataAndAccount,
                description: localizations.settingsDataAndAccountDescription,
                child: const _StoredDataCard(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                title: localizations.settingsDangerousActions,
                description: localizations.settingsDangerousActionsDescription,
                child: _DangerousActionsCard(
                  isDeletingHistory: _isDeletingHistory,
                  isDeletingAccount: _isDeletingAccount,
                  onDeleteHistory: _isDeletingData ? null : _deleteAllHistory,
                  onDeleteAccount: _isDeletingData
                      ? null
                      : _deleteAccountAndData,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
        loading: () => AppLoadingView(message: localizations.loading),
        error: (error, _) => AppErrorView(
          title: localizations.settingsLoadFailed,
          message: localizations.settingsLoadFailedDescription,
          icon: Icons.settings_outlined,
          actionLabel: localizations.retry,
          onAction: () => ref.invalidate(settingsControllerProvider),
        ),
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
    final colors = context.semanticColors;
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
                  style: TextButton.styleFrom(foregroundColor: colors.danger),
                  child: Text(localizations.delete),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      variant: AppSurfaceVariant.muted,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(height: 1, color: colors.outlineSubtle),
          ],
        ],
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return _SettingsRow(
      title: title,
      description: description,
      control: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: colors.analysisAccent.withValues(alpha: 0.48),
        activeThumbColor: colors.analysisAccent,
      ),
    );
  }
}

class _SettingsDropdownRow<T> extends StatelessWidget {
  const _SettingsDropdownRow({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String title;
  final String description;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return _SettingsRow(
      title: title,
      description: description,
      control: SizedBox(
        width: 208,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            isDense: true,
            borderRadius: BorderRadius.circular(AppRadii.small),
            dropdownColor: colors.surfaceStrong,
            iconEnabledColor: colors.analysisAccent,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.semibold,
            ),
            items: values
                .map(
                  (item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      labelFor(item),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.description,
    required this.control,
  });

  final String title;
  final String description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackControl = constraints.maxWidth < 520 || textScale >= 1.45;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.foreground,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.foregroundMuted,
                height: 1.35,
              ),
            ),
          ],
        );

        if (stackControl) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerRight, child: control),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: text),
              const SizedBox(width: AppSpacing.lg),
              control,
            ],
          ),
        );
      },
    );
  }
}

class _StoredDataCard extends StatelessWidget {
  const _StoredDataCard();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      variant: AppSurfaceVariant.accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_done_outlined, color: colors.analysisAccent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              localizations.savedWorkoutDataExplanation,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.foregroundMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerousActionsCard extends StatelessWidget {
  const _DangerousActionsCard({
    required this.isDeletingHistory,
    required this.isDeletingAccount,
    required this.onDeleteHistory,
    required this.onDeleteAccount,
  });

  final bool isDeletingHistory;
  final bool isDeletingAccount;
  final VoidCallback? onDeleteHistory;
  final VoidCallback? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      color: colors.danger.withValues(alpha: AppOpacity.subtle),
      borderColor: colors.danger.withValues(alpha: AppOpacity.border),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _DestructiveSettingsRow(
            key: const ValueKey<String>('settings-delete-all-history'),
            title: localizations.deleteAllHistory,
            description: localizations.deleteAllHistoryDescription,
            isBusy: isDeletingHistory,
            onPressed: onDeleteHistory,
          ),
          Divider(
            height: 1,
            color: colors.danger.withValues(alpha: AppOpacity.border),
          ),
          _DestructiveSettingsRow(
            key: const ValueKey<String>('settings-delete-account'),
            title: localizations.deleteAccountAndData,
            description: localizations.deleteAccountAndDataDescription,
            isBusy: isDeletingAccount,
            onPressed: onDeleteAccount,
          ),
        ],
      ),
    );
  }
}

class _DestructiveSettingsRow extends StatelessWidget {
  const _DestructiveSettingsRow({
    super.key,
    required this.title,
    required this.description,
    required this.isBusy,
    required this.onPressed,
  });

  final String title;
  final String description;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackControl = constraints.maxWidth < 520 || textScale >= 1.45;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.danger,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.foregroundMuted,
                height: 1.35,
              ),
            ),
          ],
        );
        final action = AppButton(
          label: AppLocalizations.of(context).delete,
          icon: Icons.delete_outline_rounded,
          variant: AppButtonVariant.danger,
          isLoading: isBusy,
          onPressed: onPressed,
        );

        if (stackControl) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: text),
              const SizedBox(width: AppSpacing.lg),
              action,
            ],
          ),
        );
      },
    );
  }
}
