import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_feedback_banner.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/presentation/widgets/app_status_tone.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../models/preparation_start_gate_state.dart';

class PreparationStartGateControls extends StatelessWidget {
  const PreparationStartGateControls({
    super.key,
    required this.phase,
    required this.countdownValue,
    required this.isConfigReady,
    required this.isCameraReady,
    required this.isPreparing,
    required this.onArm,
    required this.onCancel,
    required this.onOverride,
    this.compact = false,
  });

  final PreparationStartGatePhase? phase;
  final int? countdownValue;
  final bool isConfigReady;
  final bool isCameraReady;
  final bool isPreparing;
  final VoidCallback? onArm;
  final VoidCallback? onCancel;
  final VoidCallback? onOverride;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final currentPhase = phase ?? PreparationStartGatePhase.idle;

    if (currentPhase == PreparationStartGatePhase.monitoring ||
        currentPhase == PreparationStartGatePhase.overrideAvailable) {
      return AppSurfaceCard(
        key: const ValueKey<String>('preparation-start-gate-active'),
        padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
        color: colors.analysisAccent.withValues(alpha: 0.08),
        borderColor: colors.analysisAccent.withValues(alpha: 0.42),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final stackCancelAction =
                compact || constraints.maxWidth < 360 || textScale > 1.3;
            final monitoringSummary = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 38 : 42,
                  height: compact ? 38 : 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.analysisAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colors.analysisAccent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.preparationGateMonitoringTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.foreground,
                          fontWeight: AppFontWeights.heavy,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        localizations.preparationGateMonitoringMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.foregroundMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final cancelAction = compact
                ? IconButton(
                    key: const ValueKey<String>('preparation-cancel-gate'),
                    tooltip: localizations.preparationGateCancel,
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded),
                  )
                : TextButton(
                    key: const ValueKey<String>('preparation-cancel-gate'),
                    onPressed: onCancel,
                    child: Text(localizations.preparationGateCancel),
                  );

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stackCancelAction) ...[
                  monitoringSummary,
                  const SizedBox(height: AppSpacing.xxs),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: cancelAction,
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: monitoringSummary),
                      const SizedBox(width: AppSpacing.xs),
                      cancelAction,
                    ],
                  ),
                if (currentPhase ==
                    PreparationStartGatePhase.overrideAvailable) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppFeedbackBanner(
                    key: const ValueKey<String>('preparation-override-warning'),
                    title: localizations.preparationReadinessNeedsAdjustment,
                    message: localizations.preparationGateOverrideWarning,
                    tone: AppStatusTone.caution,
                    icon: Icons.warning_amber_rounded,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const ValueKey<String>(
                        'preparation-override-analysis',
                      ),
                      onPressed: onOverride,
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: Text(localizations.preparationGateOverrideAction),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );
    }

    if (currentPhase == PreparationStartGatePhase.countingDown) {
      return AppSurfaceCard(
        key: const ValueKey<String>('preparation-countdown-controls'),
        padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
        color: colors.success.withValues(alpha: 0.08),
        borderColor: colors.success.withValues(alpha: 0.48),
        child: Row(
          children: [
            Container(
              width: compact ? 40 : 46,
              height: compact ? 40 : 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.timer_outlined,
                color: colors.success,
                size: 23,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.preparationCountdownTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.foreground,
                      fontWeight: AppFontWeights.heavy,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    localizations.preparationCountdownMessage,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.foregroundMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (countdownValue != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                countdownValue!.toString(),
                key: const ValueKey<String>(
                  'preparation-countdown-control-value',
                ),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colors.success,
                  fontWeight: AppFontWeights.heavy,
                ),
              ),
            ],
            IconButton(
              key: const ValueKey<String>('preparation-cancel-countdown'),
              tooltip: localizations.preparationGateCancel,
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
    }

    if (currentPhase == PreparationStartGatePhase.approved ||
        currentPhase == PreparationStartGatePhase.launching) {
      return ElevatedButton.icon(
        key: const ValueKey<String>('preparation-launching-analysis'),
        onPressed: null,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(localizations.preparationGateLaunching),
        style: _startButtonStyle(compact: compact, colors: colors),
      );
    }

    return ElevatedButton.icon(
      key: const ValueKey<String>('preparation-start-gate'),
      onPressed: onArm,
      icon: isPreparing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.center_focus_strong_rounded),
      label: Text(
        !isConfigReady
            ? localizations.analysisConfigLoading
            : !isCameraReady
            ? localizations.preparationCameraUnavailable
            : localizations.startPreparationCheck,
      ),
      style: _startButtonStyle(compact: compact, colors: colors),
    );
  }

  ButtonStyle _startButtonStyle({
    required bool compact,
    required AppSemanticColors colors,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: colors.accent,
      foregroundColor: Colors.black,
      disabledBackgroundColor: colors.surfaceMuted,
      disabledForegroundColor: colors.foregroundSubtle,
      minimumSize: Size.fromHeight(compact ? 52 : 56),
      textStyle: const TextStyle(fontSize: 16, fontWeight: AppFontWeights.bold),
      elevation: AppElevation.flat,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.compact),
      ),
    );
  }
}
