import 'package:flutter/material.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_ui_primitives.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_motion.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/session_report.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/workout_presentation_formatter.dart';
import '../mappers/session_report_ui_mapper.dart';
import 'session_result_visual.dart';

class WorkoutSummaryContent extends StatelessWidget {
  const WorkoutSummaryContent({
    super.key,
    required this.layout,
    required this.session,
    required this.report,
    required this.summaryValues,
    required this.onRetry,
    required this.onOpenDetails,
    required this.onReturnHome,
  });

  final AppLayout layout;
  final WorkoutSession session;
  final SessionReport report;
  final List<MapEntry<String, String>> summaryValues;
  final VoidCallback onRetry;
  final VoidCallback onOpenDetails;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final useWideLayout =
        layout.viewportSize.width >= 700 &&
        (layout.isLandscape || layout.isExpanded);

    if (!useWideLayout) {
      return SingleChildScrollView(
        key: const ValueKey<String>('workout-summary-portrait-layout'),
        padding: layout.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryOutcomeCard(session: session, report: report),
            SizedBox(height: layout.sectionGap),
            _SummaryInsights(session: session, report: report),
            SizedBox(height: layout.panelGap),
            _SummaryMetricsGrid(layout: layout, values: summaryValues),
            SizedBox(height: layout.panelGap),
            _SummaryActions(
              layout: layout,
              onRetry: onRetry,
              onOpenDetails: onOpenDetails,
              onReturnHome: onReturnHome,
            ),
          ],
        ),
      );
    }

    return Padding(
      key: const ValueKey<String>('workout-summary-wide-layout'),
      padding: layout.pagePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryOutcomeCard(session: session, report: report),
                  SizedBox(height: layout.sectionGap),
                  _SummaryInsights(session: session, report: report),
                  SizedBox(height: layout.panelGap),
                  _SummaryActions(
                    layout: layout,
                    onRetry: onRetry,
                    onOpenDetails: onOpenDetails,
                    onReturnHome: onReturnHome,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: layout.panelGap),
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              child: _SummaryMetricsGrid(layout: layout, values: summaryValues),
            ),
          ),
        ],
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
    final primaryValue = session.isHoldSession
        ? WorkoutPresentationFormatter.holdDuration(session.totalHoldSeconds)
        : WorkoutPresentationFormatter.roundedScore(session.averageScore);
    final validation = _summaryValidationCounts(session);

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
          const SizedBox(height: 20),
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
              if (!session.isHoldSession) ...[
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
          const SizedBox(height: 14),
          Text(
            _summaryNarrative(localizations, report),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.foregroundMuted,
              height: 1.45,
            ),
          ),
          if (validation != null) ...[
            const SizedBox(height: AppSpacing.md),
            _SummaryValidationOverview(counts: validation),
          ],
        ],
      ),
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

class _SummaryInsights extends StatelessWidget {
  const _SummaryInsights({required this.session, required this.report});

  final WorkoutSession session;
  final SessionReport report;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final recommendations = localizedSessionReportRecommendations(
      localizations,
      report,
    );
    final useStableFallback =
        !report.hasRepDetails &&
        !session.isHoldSession &&
        session.formWarningCount == 0 &&
        session.averageScore >= 75;
    final focus = recommendations.isEmpty || useStableFallback
        ? localizations.summaryMaintainControl
        : recommendations.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 520;
        final cards = <Widget>[
          _SummaryInsightCard(
            key: const ValueKey<String>('workout-summary-strength'),
            icon: Icons.workspace_premium_outlined,
            title: localizations.summaryHighlight,
            message: _summaryHighlight(localizations, session),
            accent: AppColors.accent,
          ),
          _SummaryInsightCard(
            key: const ValueKey<String>('workout-summary-focus'),
            icon: Icons.track_changes_rounded,
            title: localizations.summaryNextFocus,
            message: focus,
            accent: Colors.amberAccent,
          ),
        ];

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [cards.first, const SizedBox(height: 10), cards.last],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards.first),
            const SizedBox(width: 10),
            Expanded(child: cards.last),
          ],
        );
      },
    );
  }
}

class _SummaryInsightCard extends StatelessWidget {
  const _SummaryInsightCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(15),
      radius: 15,
      borderColor: accent.withValues(alpha: 0.28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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
        Text(
          localizations.reportSummary,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
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
                    child: _SummaryValueCard(
                      label: entry.key,
                      value: entry.value,
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

class _SummaryActions extends StatelessWidget {
  const _SummaryActions({
    required this.layout,
    required this.onRetry,
    required this.onOpenDetails,
    required this.onReturnHome,
  });

  final AppLayout layout;
  final VoidCallback onRetry;
  final VoidCallback onOpenDetails;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Column(
      key: const ValueKey<String>('workout-summary-actions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          key: const ValueKey<String>('workout-summary-retry-action'),
          label: localizations.repeatSameExercise,
          onPressed: onRetry,
          icon: Icons.replay_rounded,
          expand: true,
        ),
        SizedBox(height: layout.sectionGap),
        AppButton(
          label: localizations.viewDetails,
          onPressed: onOpenDetails,
          icon: Icons.insights_outlined,
          variant: AppButtonVariant.outline,
          expand: true,
        ),
        const SizedBox(height: AppSpacing.xxs),
        AppButton(
          label: localizations.returnHome,
          onPressed: onReturnHome,
          icon: Icons.home_outlined,
          variant: AppButtonVariant.ghost,
          expand: true,
        ),
      ],
    );
  }
}

class _SummaryValueCard extends StatelessWidget {
  const _SummaryValueCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppMetricTile(
      label: label,
      value: value,
      tone: AppStatusTone.accent,
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

String _summaryHighlight(
  AppLocalizations localizations,
  WorkoutSession session,
) {
  if (session.isHoldSession) {
    return localizations.summaryBestHoldHighlight(
      WorkoutPresentationFormatter.holdDuration(session.bestHoldSeconds),
    );
  }

  if (session.bestScore > 0) {
    return localizations.summaryBestScoreHighlight(
      WorkoutPresentationFormatter.roundedScore(session.bestScore),
    );
  }

  return localizations.summaryRepHighlight(session.totalReps);
}

String _summaryNarrative(AppLocalizations localizations, SessionReport report) {
  if (report.isHoldSession || report.hasRepDetails || report.totalReps <= 0) {
    return localizedSessionReportSummary(localizations, report);
  }

  return localizations.sessionReportRangeSummary(
    totalReps: report.totalReps,
    validReps: report.validReps,
    lowConfidenceReps: report.lowConfidenceReps,
    invalidReps: report.invalidReps,
    unknownReps: report.unknownReps,
    averageScore: report.averageScore,
  );
}
