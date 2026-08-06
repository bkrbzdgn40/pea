import 'package:flutter/material.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_ui_primitives.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_motion.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/session_report.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/session_measurement_evidence_presenter.dart';
import '../formatters/workout_presentation_formatter.dart';
import '../mappers/session_report_ui_mapper.dart';
import 'session_measurement_evidence_notice.dart';
import 'session_result_visual.dart';

class WorkoutSummaryContent extends StatelessWidget {
  const WorkoutSummaryContent({
    super.key,
    required this.layout,
    required this.session,
    required this.report,
    required this.volumeValues,
    required this.detailValues,
    required this.onRetry,
    required this.onOpenDetails,
    required this.onReturnHistory,
    required this.onReturnHome,
  });

  final AppLayout layout;
  final WorkoutSession session;
  final SessionReport report;
  final List<MapEntry<String, String>> volumeValues;
  final List<MapEntry<String, String>> detailValues;
  final VoidCallback onRetry;
  final VoidCallback onOpenDetails;
  final VoidCallback onReturnHistory;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final useWideLayout =
        layout.viewportSize.width >= 700 &&
        (layout.isLandscape || layout.isExpanded);
    final showEvidenceWarning =
        SessionMeasurementEvidencePresenter.shouldShowWarning(session);

    final decisionContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryVolumeCard(values: volumeValues),
        if (showEvidenceWarning) ...[
          SizedBox(height: layout.sectionGap),
          SessionMeasurementEvidenceNotice(
            key: const ValueKey<String>('workout-summary-measurement-warning'),
            session: session,
          ),
        ],
        SizedBox(height: layout.sectionGap),
        _SummaryDecisionCard(session: session, report: report),
      ],
    );

    return SingleChildScrollView(
      key: ValueKey<String>(
        useWideLayout
            ? 'workout-summary-wide-layout'
            : 'workout-summary-portrait-layout',
      ),
      padding: layout.pagePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (useWideLayout)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _SummaryOutcomeCard(
                        session: session,
                        report: report,
                      ),
                    ),
                    SizedBox(width: layout.panelGap),
                    Expanded(flex: 5, child: decisionContent),
                  ],
                )
              else ...[
                _SummaryOutcomeCard(session: session, report: report),
                SizedBox(height: layout.sectionGap),
                decisionContent,
              ],
              SizedBox(height: layout.panelGap),
              _SummaryPrimaryActions(
                layout: layout,
                onOpenDetails: onOpenDetails,
                onReturnHistory: onReturnHistory,
              ),
              SizedBox(height: layout.sectionGap),
              _SummarySecondaryDetails(
                layout: layout,
                session: session,
                report: report,
                values: detailValues,
                onRetry: onRetry,
                onReturnHome: onReturnHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryOutcomeCard extends StatelessWidget {
  const _SummaryOutcomeCard({required this.session, required this.report});

  final WorkoutSession session;
  final SessionReport report;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final tone = sessionResultTone(session);
    final accent = tone.resolveColor(colors);
    final hasBestHold = session.bestHoldSeconds > 0;
    final holdValue = hasBestHold
        ? session.bestHoldSeconds
        : session.totalHoldSeconds;
    final primaryValue = session.isHoldSession
        ? WorkoutPresentationFormatter.holdDuration(holdValue)
        : report.hasScoreData
        ? WorkoutPresentationFormatter.roundedScore(session.averageScore)
        : '—';
    final primaryLabel = session.isHoldSession
        ? hasBestHold
              ? localizations.workoutSummaryBestHold
              : localizations.workoutSummaryTotalHold
        : localizations.workoutSummaryAverageFormRangeScore;

    return AppSurfaceCard(
      key: const ValueKey<String>('workout-summary-outcome-card'),
      padding: const EdgeInsets.all(20),
      radius: 20,
      variant: AppSurfaceVariant.strong,
      color: Color.alphaBlend(
        accent.withValues(alpha: 0.055),
        colors.surfaceStrong,
      ),
      borderColor: accent.withValues(alpha: 0.48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.36)),
                ),
                child: Icon(tone.icon, color: accent, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.exerciseSummary(
                        localizations.exerciseTitle(session.exerciseType),
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _summaryToneLabel(localizations, tone),
                      key: const ValueKey<String>('workout-summary-tone'),
                      style: TextStyle(
                        color: accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            primaryLabel,
            key: const ValueKey<String>('workout-summary-primary-label'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.foregroundMuted,
              fontWeight: AppFontWeights.semibold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: AnimatedSwitcher(
                  duration: AppMotion.resolveDuration(
                    context,
                    AppMotionDurations.emphasized,
                  ),
                  switchInCurve: AppMotionCurves.standard,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.96,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<String>(primaryValue),
                    child: Text(
                      primaryValue,
                      key: const ValueKey<String>(
                        'workout-summary-primary-value',
                      ),
                      style: TextStyle(
                        color: accent,
                        fontSize: 44,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                      ),
                    ),
                  ),
                ),
              ),
              if (!session.isHoldSession && report.hasScoreData) ...[
                const SizedBox(width: 5),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    '/100',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryVolumeCard extends StatelessWidget {
  const _SummaryVolumeCard({required this.values});

  final List<MapEntry<String, String>> values;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: const ValueKey<String>('workout-summary-volume'),
      variant: AppSurfaceVariant.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.summarySessionVolume,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = _layoutWidthRequiresStack(
                context,
                constraints.maxWidth,
              );
              final items = values
                  .map(
                    (entry) => _SummaryVolumeValue(
                      label: entry.key,
                      value: entry.value,
                    ),
                  )
                  .toList(growable: false);

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      if (index > 0) const SizedBox(height: AppSpacing.sm),
                      items[index],
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    if (index > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(child: items[index]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

bool _layoutWidthRequiresStack(BuildContext context, double width) {
  return MediaQuery.textScalerOf(context).scale(1) >= 1.6 || width < 320;
}

class _SummaryVolumeValue extends StatelessWidget {
  const _SummaryVolumeValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Semantics(
      container: true,
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.foregroundMuted,
              fontWeight: AppFontWeights.semibold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDecisionCard extends StatelessWidget {
  const _SummaryDecisionCard({required this.session, required this.report});

  final WorkoutSession session;
  final SessionReport report;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final focus = _summaryNextFocus(localizations, session, report);

    return AppSurfaceCard(
      key: const ValueKey<String>('workout-summary-focus'),
      padding: const EdgeInsets.all(16),
      borderColor: colors.caution.withValues(alpha: 0.32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.caution.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Icon(
              Icons.track_changes_rounded,
              color: colors.caution,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.summaryNextFocus,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.caution,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  focus,
                  key: const ValueKey<String>('workout-summary-focus-message'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foreground,
                    height: 1.4,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPrimaryActions extends StatelessWidget {
  const _SummaryPrimaryActions({
    required this.layout,
    required this.onOpenDetails,
    required this.onReturnHistory,
  });

  final AppLayout layout;
  final VoidCallback onOpenDetails;
  final VoidCallback onReturnHistory;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final stack = layout.hasLargeText || layout.viewportSize.width < 520;
    final historyButton = AppButton(
      key: const ValueKey<String>('workout-summary-history-action'),
      label: localizations.returnToHistory,
      onPressed: onReturnHistory,
      icon: Icons.history_rounded,
      expand: true,
    );
    final detailsButton = AppButton(
      key: const ValueKey<String>('workout-summary-details-action'),
      label: localizations.viewDetails,
      onPressed: onOpenDetails,
      icon: Icons.insights_outlined,
      variant: AppButtonVariant.outline,
      expand: true,
    );

    if (stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          historyButton,
          SizedBox(height: layout.sectionGap),
          detailsButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: historyButton),
        SizedBox(width: layout.sectionGap),
        Expanded(child: detailsButton),
      ],
    );
  }
}

class _SummarySecondaryDetails extends StatelessWidget {
  const _SummarySecondaryDetails({
    required this.layout,
    required this.session,
    required this.report,
    required this.values,
    required this.onRetry,
    required this.onReturnHome,
  });

  final AppLayout layout;
  final WorkoutSession session;
  final SessionReport report;
  final List<MapEntry<String, String>> values;
  final VoidCallback onRetry;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final validation = _summaryValidationCounts(session);
    final issues = localizedSessionReportIssues(localizations, report);

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const ValueKey<String>('workout-summary-secondary-details'),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          iconColor: colors.analysisAccent,
          collapsedIconColor: colors.foregroundMuted,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.analysisAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Icon(
              Icons.tune_rounded,
              color: colors.analysisAccent,
              size: 21,
            ),
          ),
          title: Text(
            localizations.summaryTechnicalDetails,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              localizations.summaryTechnicalDetailsHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.foregroundMuted,
                height: 1.35,
              ),
            ),
          ),
          children: [
            if (validation != null) ...[
              _SummaryDetailHeading(title: localizations.summaryRepBreakdown),
              _SummaryValidationOverview(counts: validation),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (issues.isNotEmpty) ...[
              _SummaryDetailHeading(title: localizations.summaryDetailedIssues),
              _SummaryIssueList(issues: issues),
              const SizedBox(height: AppSpacing.lg),
            ],
            _SummaryMetricsGrid(layout: layout, values: values),
            const SizedBox(height: AppSpacing.lg),
            _SummarySecondaryActions(
              layout: layout,
              onRetry: onRetry,
              onReturnHome: onReturnHome,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryDetailHeading extends StatelessWidget {
  const _SummaryDetailHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: colors.foreground,
          fontWeight: AppFontWeights.heavy,
        ),
      ),
    );
  }
}

class _SummaryIssueList extends StatelessWidget {
  const _SummaryIssueList({required this.issues});

  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Column(
      key: const ValueKey<String>('workout-summary-detailed-issues'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < issues.length; index++) ...[
          if (index > 0) const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.caution,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  issues[index],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SummaryValidationOverview extends StatelessWidget {
  const _SummaryValidationOverview({required this.counts});

  final _SummaryValidationCounts counts;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Semantics(
      container: true,
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          if (counts.valid > 0)
            AppStatusChip(
              label: '${localizations.valid}: ${counts.valid}',
              tone: AppStatusTone.success,
              icon: Icons.check_circle_rounded,
            ),
          if (counts.lowConfidence > 0)
            AppStatusChip(
              label: '${localizations.lowConfidence}: ${counts.lowConfidence}',
              tone: AppStatusTone.caution,
              icon: Icons.visibility_outlined,
            ),
          if (counts.invalid > 0)
            AppStatusChip(
              label: '${localizations.invalid}: ${counts.invalid}',
              tone: AppStatusTone.invalid,
              icon: Icons.close_rounded,
            ),
          if (counts.unknown > 0)
            AppStatusChip(
              label: '${localizations.uncertain}: ${counts.unknown}',
              tone: AppStatusTone.neutral,
              icon: Icons.help_outline_rounded,
            ),
        ],
      ),
    );
  }
}

class _SummaryValidationCounts {
  const _SummaryValidationCounts({
    required this.valid,
    required this.lowConfidence,
    required this.invalid,
    required this.unknown,
  });

  final int valid;
  final int lowConfidence;
  final int invalid;
  final int unknown;
}

_SummaryValidationCounts? _summaryValidationCounts(WorkoutSession session) {
  if (session.isHoldSession) return null;

  final reps = session.reps;
  if (reps != null && reps.isNotEmpty) {
    final valid = reps.where((rep) => rep.isValidatedAsValid).length;
    final lowConfidence = reps
        .where((rep) => rep.isValidatedAsLowConfidence)
        .length;
    final invalid = reps.where((rep) => rep.isValidatedAsInvalid).length;
    final unknown = reps.where((rep) => rep.isValidationUnknown).length;
    if (valid + lowConfidence + invalid + unknown > 0) {
      return _SummaryValidationCounts(
        valid: valid,
        lowConfidence: lowConfidence,
        invalid: invalid,
        unknown: unknown,
      );
    }
  }

  if (session.validReps <= 0 &&
      session.lowConfidenceReps <= 0 &&
      session.invalidReps <= 0) {
    return null;
  }

  return _SummaryValidationCounts(
    valid: session.validReps,
    lowConfidence: session.lowConfidenceReps,
    invalid: session.invalidReps,
    unknown: 0,
  );
}

class _SummaryMetricsGrid extends StatelessWidget {
  const _SummaryMetricsGrid({required this.layout, required this.values});

  final AppLayout layout;
  final List<MapEntry<String, String>> values;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Column(
      key: const ValueKey<String>('workout-summary-metrics'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryDetailHeading(title: localizations.reportSummary),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = layout.hasLargeText || constraints.maxWidth < 360
                ? 1
                : 2;
            final gap = layout.sectionGap;
            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - gap) / 2;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final entry in values)
                  SizedBox(
                    width: width,
                    child: AppMetricTile(
                      label: entry.key,
                      value: entry.value,
                      tone: AppStatusTone.accent,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SummarySecondaryActions extends StatelessWidget {
  const _SummarySecondaryActions({
    required this.layout,
    required this.onRetry,
    required this.onReturnHome,
  });

  final AppLayout layout;
  final VoidCallback onRetry;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final stack = layout.hasLargeText || layout.viewportSize.width < 520;
    final retryButton = AppButton(
      key: const ValueKey<String>('workout-summary-retry-action'),
      label: localizations.repeatSameExercise,
      onPressed: onRetry,
      icon: Icons.replay_rounded,
      variant: AppButtonVariant.ghost,
      expand: true,
    );
    final homeButton = AppButton(
      key: const ValueKey<String>('workout-summary-home-action'),
      label: localizations.returnHome,
      onPressed: onReturnHome,
      icon: Icons.home_outlined,
      variant: AppButtonVariant.ghost,
      expand: true,
    );

    if (stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          retryButton,
          const SizedBox(height: AppSpacing.xxs),
          homeButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: retryButton),
        SizedBox(width: layout.sectionGap),
        Expanded(child: homeButton),
      ],
    );
  }
}

String _summaryToneLabel(
  AppLocalizations localizations,
  SessionResultTone tone,
) {
  return switch (tone) {
    SessionResultTone.excellent => localizations.summaryResultExcellent,
    SessionResultTone.strong => localizations.summaryResultStrong,
    SessionResultTone.steady => localizations.summaryResultSteady,
    SessionResultTone.focus => localizations.summaryResultNeedsFocus,
    SessionResultTone.completed => localizations.summaryResultCompleted,
  };
}

String _summaryNextFocus(
  AppLocalizations localizations,
  WorkoutSession session,
  SessionReport report,
) {
  final recommendations = localizedSessionReportRecommendations(
    localizations,
    report,
  );
  final useStableFallback =
      !report.hasRepDetails &&
      !session.isHoldSession &&
      session.formWarningCount == 0 &&
      session.averageScore >= 75;

  if (recommendations.isEmpty || useStableFallback) {
    return localizations.summaryMaintainControl;
  }

  return recommendations.first;
}
