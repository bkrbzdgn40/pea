import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../domain/models/exercise_type.dart';
import '../providers/exercise_score_trend_provider.dart';
import '../providers/user_sessions_snapshot_provider.dart';
import '../widgets/score_trend_card.dart';

class ScoreTrendDetailScreen extends ConsumerWidget {
  const ScoreTrendDetailScreen({super.key, required this.exercise});

  final ExerciseType exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final exerciseTitle = localizations.exerciseTitle(exercise.id);
    final trendState = ref.watch(exerciseScoreTrendProvider(exercise));

    return AppScaffoldShell(
      title: localizations.formScoreTrend(exerciseTitle),
      currentPage: null,
      body: trendState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
        error: (_, _) => _ScoreTrendEmptyState(
          message: localizations.formScoreDataUnavailable,
          detail: localizations.tryAgainLater,
        ),
        data: (trendData) {
          if (!trendData.hasRealData) {
            final didFail =
                trendData.source == UserSessionsSnapshotSource.error;

            return _ScoreTrendEmptyState(
              message: didFail
                  ? localizations.formScoreTrendUnavailable(exerciseTitle)
                  : localizations.formScoreTrendEmpty(exerciseTitle),
              detail: didFail
                  ? localizations.tryAgainLater
                  : localizations.formScoreTrendEmptyDetail,
            );
          }

          final lastScore = trendData.samples.last.score;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScoreTrendCard(
                  exerciseTitle: exerciseTitle,
                  points: trendData.detailPoints(),
                  chartHeight: 300,
                  subtitle: localizations.formScoreTrendChronological(
                    exerciseTitle,
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 10.0;
                    final columnCount = constraints.maxWidth < 340
                        ? 1
                        : constraints.maxWidth < 560
                        ? 2
                        : 3;
                    final tileWidth =
                        (constraints.maxWidth - spacing * (columnCount - 1)) /
                        columnCount;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children:
                          [
                                _TrendSummaryTile(
                                  label: localizations.session,
                                  value: trendData.samples.length.toString(),
                                ),
                                _TrendSummaryTile(
                                  label: localizations.latestFormScore,
                                  value: lastScore.round().toString(),
                                ),
                                _TrendSummaryTile(
                                  label: localizations.bestFormScore,
                                  value: trendData.bestAverageScore
                                      .round()
                                      .toString(),
                                ),
                              ]
                              .map(
                                (tile) =>
                                    SizedBox(width: tileWidth, child: tile),
                              )
                              .toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrendSummaryTile extends StatelessWidget {
  const _TrendSummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreTrendEmptyState extends StatelessWidget {
  const _ScoreTrendEmptyState({required this.message, this.detail});

  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.show_chart_rounded,
              color: Colors.greenAccent,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
