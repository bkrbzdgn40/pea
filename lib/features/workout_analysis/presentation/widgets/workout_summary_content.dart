import 'package:flutter/material.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../domain/models/session_report.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/workout_presentation_formatter.dart';
import '../mappers/session_report_ui_mapper.dart';

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

enum _SummaryTone { excellent, strong, steady, focus, completed }

class _SummaryOutcomeCard extends StatelessWidget {
  const _SummaryOutcomeCard({required this.session, required this.report});

  final WorkoutSession session;
  final SessionReport report;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final tone = _summaryTone(session);
    final accent = _summaryToneColor(tone);
    final primaryValue = session.isHoldSession
        ? WorkoutPresentationFormatter.holdDuration(session.totalHoldSeconds)
        : WorkoutPresentationFormatter.roundedScore(session.averageScore);

    return AppSurfaceCard(
      key: const ValueKey<String>('workout-summary-outcome-card'),
      padding: const EdgeInsets.all(20),
      radius: 20,
      color: const Color(0xFF111A17),
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
                child: Icon(_summaryToneIcon(tone), color: accent, size: 25),
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
                child: Text(
                  primaryValue,
                  key: const ValueKey<String>('workout-summary-primary-value'),
                  style: TextStyle(
                    color: accent,
                    fontSize: 44,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
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
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
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
        ElevatedButton.icon(
          key: const ValueKey<String>('workout-summary-retry-action'),
          onPressed: onRetry,
          icon: const Icon(Icons.replay_rounded),
          label: Text(localizations.repeatSameExercise),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        SizedBox(height: layout.sectionGap),
        OutlinedButton.icon(
          onPressed: onOpenDetails,
          icon: const Icon(Icons.insights_outlined),
          label: Text(localizations.viewDetails),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.42)),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: onReturnHome,
          icon: const Icon(Icons.home_outlined),
          label: Text(localizations.returnHome),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
            minimumSize: const Size.fromHeight(48),
          ),
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
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 12,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

_SummaryTone _summaryTone(WorkoutSession session) {
  if (session.isHoldSession) {
    if (session.totalHoldSeconds <= 0) return _SummaryTone.focus;
    if (session.formBreakCount == 0 && session.totalHoldSeconds >= 30) {
      return _SummaryTone.strong;
    }
    return _SummaryTone.completed;
  }

  if (session.averageScore <= 0) return _SummaryTone.completed;
  if (session.averageScore >= 90) return _SummaryTone.excellent;
  if (session.averageScore >= 80) return _SummaryTone.strong;
  if (session.averageScore >= 70) return _SummaryTone.steady;
  return _SummaryTone.focus;
}

Color _summaryToneColor(_SummaryTone tone) {
  return switch (tone) {
    _SummaryTone.excellent || _SummaryTone.strong => AppColors.accent,
    _SummaryTone.steady || _SummaryTone.completed => Colors.lightBlueAccent,
    _SummaryTone.focus => Colors.amberAccent,
  };
}

IconData _summaryToneIcon(_SummaryTone tone) {
  return switch (tone) {
    _SummaryTone.excellent => Icons.auto_awesome_rounded,
    _SummaryTone.strong => Icons.verified_rounded,
    _SummaryTone.steady => Icons.trending_up_rounded,
    _SummaryTone.focus => Icons.track_changes_rounded,
    _SummaryTone.completed => Icons.check_circle_outline_rounded,
  };
}

String _summaryToneLabel(AppLocalizations localizations, _SummaryTone tone) {
  return switch (tone) {
    _SummaryTone.excellent => localizations.summaryResultExcellent,
    _SummaryTone.strong => localizations.summaryResultStrong,
    _SummaryTone.steady => localizations.summaryResultSteady,
    _SummaryTone.focus => localizations.summaryResultNeedsFocus,
    _SummaryTone.completed => localizations.summaryResultCompleted,
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
