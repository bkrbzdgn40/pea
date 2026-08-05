import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_status_chip.dart';
import '../../../../app/presentation/widgets/app_status_tone.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/session_measurement_evidence_presenter.dart';
import '../formatters/workout_presentation_formatter.dart';

class HomeRecentSessionCard extends StatelessWidget {
  const HomeRecentSessionCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  final WorkoutSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final exerciseTitle = localizations.exerciseTitle(session.exerciseType);
    final warningTitle =
        SessionMeasurementEvidencePresenter.shouldShowWarning(session)
        ? SessionMeasurementEvidencePresenter.warningTitle(
            localizations,
            session,
          )
        : null;
    final metrics = _buildMetrics(localizations);

    return Semantics(
      button: true,
      label: [
        '${localizations.recentSession}: $exerciseTitle',
        ?warningTitle,
      ].join(', '),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('home-recent-session'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.surface),
          child: Ink(
            padding: AppSpacing.surfacePadding,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadii.surface),
              border: Border.all(color: colors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RecentSessionHeader(
                  title: localizations.recentSession,
                  subtitle: localizations.recentSessionSubtitle,
                  exerciseTitle: exerciseTitle,
                  warningTitle: warningTitle,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  WorkoutPresentationFormatter.dateTime(session.startedAt),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.foregroundSubtle,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackMetrics =
                        MediaQuery.textScalerOf(context).scale(1) >= 1.6 ||
                        constraints.maxWidth < 280;

                    if (stackMetrics) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (
                            var index = 0;
                            index < metrics.length;
                            index++
                          ) ...[
                            _RecentSessionMetric(metric: metrics[index]),
                            if (index != metrics.length - 1)
                              const SizedBox(height: AppSpacing.xs),
                          ],
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var index = 0;
                          index < metrics.length;
                          index++
                        ) ...[
                          Expanded(
                            child: _RecentSessionMetric(metric: metrics[index]),
                          ),
                          if (index != metrics.length - 1)
                            const SizedBox(width: AppSpacing.xs),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        localizations.openSession,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.analysisAccent,
                          fontWeight: AppFontWeights.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: colors.analysisAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_RecentMetricData> _buildMetrics(AppLocalizations localizations) {
    if (session.isHoldSession) {
      final metrics = <_RecentMetricData>[
        _RecentMetricData(
          label: localizations.duration,
          value: WorkoutPresentationFormatter.duration(session.duration),
        ),
      ];
      if (session.formBreakCount > 0) {
        metrics.add(
          _RecentMetricData(
            label: localizations.formBreaks,
            value: session.formBreakCount.toString(),
          ),
        );
      }
      return metrics;
    }

    final metrics = <_RecentMetricData>[
      _RecentMetricData(
        label: localizations.totalReps,
        value: session.totalReps.toString(),
      ),
    ];
    final hasValidationBreakdown =
        session.validReps + session.lowConfidenceReps + session.invalidReps > 0;

    if (hasValidationBreakdown) {
      metrics.add(
        _RecentMetricData(
          label: localizations.validReps,
          value: session.validReps.toString(),
        ),
      );
    } else {
      metrics.add(
        _RecentMetricData(
          label: localizations.duration,
          value: WorkoutPresentationFormatter.duration(session.duration),
        ),
      );
    }

    if (session.averageScore > 0) {
      metrics.add(
        _RecentMetricData(
          label: localizations.averageScoreShort,
          value: WorkoutPresentationFormatter.roundedScore(
            session.averageScore,
          ),
        ),
      );
    }

    return metrics.take(3).toList(growable: false);
  }
}

class _RecentSessionHeader extends StatelessWidget {
  const _RecentSessionHeader({
    required this.title,
    required this.subtitle,
    required this.exerciseTitle,
    this.warningTitle,
  });

  final String title;
  final String subtitle;
  final String exerciseTitle;
  final String? warningTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors.foreground,
            fontWeight: AppFontWeights.heavy,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.foregroundMuted),
        ),
      ],
    );
    final exerciseChip = AppStatusChip(
      label: exerciseTitle,
      tone: AppStatusTone.accent,
      icon: Icons.fitness_center_rounded,
    );
    final warningIndicator = warningTitle == null
        ? null
        : Tooltip(
            message: warningTitle!,
            excludeFromSemantics: true,
            child: Container(
              key: const ValueKey<String>(
                'home-recent-session-evidence-warning',
              ),
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.caution.withValues(alpha: AppOpacity.subtle),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: colors.caution.withValues(
                    alpha: AppOpacity.strongBorder,
                  ),
                ),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: colors.caution,
              ),
            ),
          );
    final statusItems = <Widget>[exerciseChip, ?warningIndicator];

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackHeader =
            MediaQuery.textScalerOf(context).scale(1) >= 1.6 ||
            constraints.maxWidth < 300;
        if (stackHeader) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: statusItems,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: statusItems,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentSessionMetric extends StatelessWidget {
  const _RecentSessionMetric({required this.metric});

  final _RecentMetricData metric;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: colors.outlineSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.foregroundMuted,
              fontWeight: AppFontWeights.semibold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentMetricData {
  const _RecentMetricData({required this.label, required this.value});

  final String label;
  final String value;
}
