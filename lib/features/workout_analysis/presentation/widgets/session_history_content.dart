import 'package:flutter/material.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_ui_primitives.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/workout_session.dart';
import '../../domain/session_evidence_eligibility_policy.dart';
import '../formatters/session_measurement_evidence_presenter.dart';
import '../formatters/workout_presentation_formatter.dart';
import 'session_result_visual.dart';

class SessionHistoryCollection extends StatelessWidget {
  const SessionHistoryCollection({
    super.key,
    required this.layout,
    required this.sessions,
    required this.onOpenSession,
  });

  final AppLayout layout;
  final List<WorkoutSession> sessions;
  final ValueChanged<WorkoutSession> onOpenSession;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= 760 && !layout.hasLargeText;
        if (useGrid) {
          return GridView.builder(
            key: const ValueKey<String>('session-history-grid'),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: layout.sectionGap,
              crossAxisSpacing: layout.sectionGap,
              mainAxisExtent: 294,
            ),
            itemCount: sessions.length,
            itemBuilder: (context, index) => _buildSessionCard(index),
          );
        }

        return ListView.separated(
          key: const ValueKey<String>('session-history-list'),
          itemCount: sessions.length,
          separatorBuilder: (_, _) => SizedBox(height: layout.sectionGap),
          itemBuilder: (context, index) => _buildSessionCard(index),
        );
      },
    );
  }

  Widget _buildSessionCard(int index) {
    final session = sessions[index];
    return _SessionCard(
      key: ValueKey<String>('session-history-card-${session.id}'),
      session: session,
      scoreDelta: _scoreDeltaFor(index),
      onTap: () => onOpenSession(session),
    );
  }

  int? _scoreDeltaFor(int index) {
    const evidencePolicy = SessionEvidenceEligibilityPolicy();
    final session = sessions[index];
    if (!evidencePolicy.contributesToScoreAggregates(session)) return null;

    for (
      var candidateIndex = index + 1;
      candidateIndex < sessions.length;
      candidateIndex++
    ) {
      final candidate = sessions[candidateIndex];
      if (candidate.exerciseType == session.exerciseType &&
          evidencePolicy.contributesToScoreAggregates(candidate)) {
        return session.averageScore.round() - candidate.averageScore.round();
      }
    }

    return null;
  }
}

class SessionHistoryToolbar extends StatelessWidget {
  const SessionHistoryToolbar({
    super.key,
    required this.layout,
    required this.sessionCount,
    required this.selectedExerciseFilter,
    required this.allExercisesFilter,
    required this.onExerciseSelected,
  });

  final AppLayout layout;
  final int sessionCount;
  final String selectedExerciseFilter;
  final String allExercisesFilter;
  final ValueChanged<String> onExerciseSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return AppSurfaceCard(
      key: const ValueKey<String>('session-history-toolbar'),
      padding: const EdgeInsets.all(14),
      variant: AppSurfaceVariant.strong,
      borderColor: context.semanticColors.analysisAccent.withValues(
        alpha: AppOpacity.border,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = layout.hasLargeText || constraints.maxWidth < 520;
          final count = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insights_rounded,
                color: AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  localizations.sessionsShown(sessionCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
          final filter = _HistoryExerciseFilter(
            selectedValue: selectedExerciseFilter,
            allExercisesFilter: allExercisesFilter,
            onChanged: onExerciseSelected,
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [count, const SizedBox(height: 12), filter],
            );
          }

          return Row(
            children: [
              Expanded(child: count),
              const SizedBox(width: 16),
              SizedBox(width: 250, child: filter),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryExerciseFilter extends StatelessWidget {
  const _HistoryExerciseFilter({
    required this.selectedValue,
    required this.allExercisesFilter,
    required this.onChanged,
  });

  final String selectedValue;
  final String allExercisesFilter;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const ValueKey<String>('session-history-exercise-filter'),
          value: selectedValue,
          isExpanded: true,
          dropdownColor: AppColors.primarySurface,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: [
            DropdownMenuItem<String>(
              value: allExercisesFilter,
              child: Text(localizations.allExercises),
            ),
            for (final exercise in ExerciseType.values)
              DropdownMenuItem<String>(
                value: exercise.id,
                child: Text(
                  localizations.exerciseTitle(exercise.id),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    super.key,
    required this.session,
    required this.scoreDelta,
    required this.onTap,
  });

  final WorkoutSession session;
  final int? scoreDelta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final tone = sessionResultTone(session);
    final accent = tone.resolveColor(colors);
    final isHold = session.isHoldSession;
    final primaryLabel = isHold
        ? localizations.totalHold
        : localizations.averageFormRangeScoreShort;
    final primaryValue = isHold
        ? WorkoutPresentationFormatter.holdDuration(session.totalHoldSeconds)
        : WorkoutPresentationFormatter.roundedScore(session.averageScore);
    final metrics = isHold
        ? <MapEntry<String, String>>[
            MapEntry(
              localizations.duration,
              WorkoutPresentationFormatter.duration(session.duration),
            ),
            MapEntry(
              localizations.bestHold,
              WorkoutPresentationFormatter.holdDuration(
                session.bestHoldSeconds,
              ),
            ),
            MapEntry(
              localizations.interruptions,
              session.formBreakCount.toString(),
            ),
          ]
        : <MapEntry<String, String>>[
            MapEntry(
              localizations.duration,
              WorkoutPresentationFormatter.duration(session.duration),
            ),
            MapEntry(localizations.reps, session.totalReps.toString()),
            MapEntry(
              localizations.bestShort,
              WorkoutPresentationFormatter.roundedScore(session.bestScore),
            ),
            MapEntry(
              localizations.warnings,
              session.formWarningCount.toString(),
            ),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          radius: 18,
          variant: AppSurfaceVariant.strong,
          color: Color.alphaBlend(
            accent.withValues(alpha: 0.045),
            colors.surfaceStrong,
          ),
          borderColor: accent.withValues(alpha: AppOpacity.border),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.exerciseTitle(session.exerciseType),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          WorkoutPresentationFormatter.dateTime(
                            session.startedAt,
                          ),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tone.icon, color: accent, size: 21),
                          if (SessionMeasurementEvidencePresenter.shouldShowWarning(
                            session,
                          )) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Tooltip(
                              message:
                                  SessionMeasurementEvidencePresenter.warningTitle(
                                    localizations,
                                    session,
                                  ),
                              excludeFromSemantics: true,
                              child: Semantics(
                                container: true,
                                excludeSemantics: true,
                                label:
                                    SessionMeasurementEvidencePresenter.warningTitle(
                                      localizations,
                                      session,
                                    ),
                                child: Icon(
                                  SessionMeasurementEvidencePresenter.warningIcon(
                                    session,
                                  ),
                                  key: const ValueKey<String>(
                                    'session-history-measurement-warning',
                                  ),
                                  color:
                                      SessionMeasurementEvidencePresenter.warningTone(
                                        session,
                                      ).resolveColor(colors),
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: colors.foregroundSubtle,
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primaryLabel,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          primaryValue,
                          style: TextStyle(
                            color: accent,
                            fontSize: 31,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (scoreDelta != null)
                    _ScoreDeltaChip(scoreDelta: scoreDelta!),
                ],
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in metrics)
                    _SessionMetric(label: entry.key, value: entry.value),
                ],
              ),
              if (!isHold && _hasValidationBreakdown(session)) ...[
                const SizedBox(height: AppSpacing.sm),
                _SessionValidationStrip(session: session),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionValidationStrip extends StatelessWidget {
  const _SessionValidationStrip({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final lowConfidence = session.lowConfidenceReps;

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        if (session.validReps > 0)
          AppStatusChip(
            label: '${localizations.valid}: ${session.validReps}',
            tone: AppStatusTone.success,
            showIcon: false,
          ),
        if (lowConfidence > 0)
          AppStatusChip(
            label: '${localizations.lowConfidence}: $lowConfidence',
            tone: AppStatusTone.caution,
            showIcon: false,
          ),
        if (session.invalidReps > 0)
          AppStatusChip(
            label: '${localizations.invalid}: ${session.invalidReps}',
            tone: AppStatusTone.invalid,
            showIcon: false,
          ),
      ],
    );
  }
}

bool _hasValidationBreakdown(WorkoutSession session) {
  return session.validReps > 0 ||
      session.lowConfidenceReps > 0 ||
      session.invalidReps > 0;
}

class _ScoreDeltaChip extends StatelessWidget {
  const _ScoreDeltaChip({required this.scoreDelta});

  final int scoreDelta;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final positive = scoreDelta > 0;
    final neutral = scoreDelta == 0;
    final accent = positive
        ? colors.success
        : neutral
        ? colors.foregroundMuted
        : colors.invalid;

    return Container(
      key: const ValueKey<String>('session-history-score-delta'),
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive
                ? Icons.trending_up_rounded
                : neutral
                ? Icons.trending_flat_rounded
                : Icons.trending_down_rounded,
            color: accent,
            size: 17,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              localizations.scoreComparedToPrevious(scoreDelta),
              style: TextStyle(
                color: accent,
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionMetric extends StatelessWidget {
  const _SessionMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.outlineSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.foregroundSubtle,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
