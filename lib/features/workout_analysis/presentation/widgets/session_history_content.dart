import 'package:flutter/material.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/workout_presentation_formatter.dart';

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
              mainAxisExtent: 260,
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
    final session = sessions[index];
    if (session.isHoldSession || session.averageScore <= 0) return null;

    for (
      var candidateIndex = index + 1;
      candidateIndex < sessions.length;
      candidateIndex++
    ) {
      final candidate = sessions[candidateIndex];
      if (candidate.exerciseType == session.exerciseType &&
          !candidate.isHoldSession &&
          candidate.averageScore > 0) {
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
          borderColor: AppColors.accent.withValues(alpha: 0.2),
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
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white38,
                    size: 16,
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
                          style: const TextStyle(
                            color: AppColors.accent,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreDeltaChip extends StatelessWidget {
  const _ScoreDeltaChip({required this.scoreDelta});

  final int scoreDelta;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final positive = scoreDelta > 0;
    final neutral = scoreDelta == 0;
    final accent = positive
        ? AppColors.accent
        : neutral
        ? Colors.white60
        : Colors.orangeAccent;

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
