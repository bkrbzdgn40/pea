import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../application/exercise_metric_registry.dart';
import '../../application/workout_live_metrics.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/workout_presentation_formatter.dart';
import '../providers/completed_session_metrics_provider.dart';
import '../providers/completed_session_provider.dart';
import 'home_screen.dart';

class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  const WorkoutSummaryScreen({super.key, this.onRetryRequested});

  final Future<bool> Function()? onRetryRequested;

  @override
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    if (_isRetrying) {
      return;
    }

    setState(() => _isRetrying = true);
    final onRetryRequested = widget.onRetryRequested;
    final canRetry = onRetryRequested == null ? true : await onRetryRequested();
    if (!mounted) {
      return;
    }

    if (canRetry) {
      Navigator.pop(context, true);
      return;
    }

    setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final session = ref.watch(completedSessionProvider);
    final completedMetrics = ref.watch(completedSessionMetricsProvider);
    final summaryValues = session == null
        ? const <MapEntry<String, String>>[]
        : _summaryValues(localizations, session, completedMetrics);

    return AppScaffoldShell(
      title: localizations.workoutSummary,
      showDrawer: false,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSurfaceCard(
            padding: const EdgeInsets.all(22),
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session == null
                      ? localizations.sessionDataMissing
                      : localizations.exerciseSummary(
                          localizations.exerciseTitle(session.exerciseType),
                        ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  session == null
                      ? localizations.summaryAppearsAfterAnalysis
                      : localizations.summaryUsesRecordedValues,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: session == null
                ? const _MissingSessionView()
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < summaryValues.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(height: 10),
                          _SummaryValueCard(
                            label: summaryValues[index].key,
                            value: summaryValues[index].value,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isRetrying ? null : _retry,
            icon: _isRetrying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.replay_rounded),
            label: Text(
              _isRetrying ? localizations.preparing : localizations.retry,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.home_outlined),
            label: Text(localizations.home),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingSessionView extends StatelessWidget {
  const _MissingSessionView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(context).sessionDataMissingDetail,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      radius: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

List<MapEntry<String, String>> _summaryValues(
  AppLocalizations localizations,
  WorkoutSession session,
  WorkoutLiveMetricsSnapshot? liveMetrics,
) {
  final fallbackMetrics = const WorkoutSessionMetricSnapshotBuilder().build(
    session,
  );

  if (session.isHoldSession) {
    final values = <MapEntry<String, String>>[
      MapEntry(
        localizations.exerciseType,
        localizations.exerciseTitle(session.exerciseType),
      ),
      MapEntry(
        localizations.workoutSummaryTotalHold,
        WorkoutPresentationFormatter.holdDuration(session.totalHoldSeconds),
      ),
      MapEntry(
        localizations.workoutSummaryBestHold,
        WorkoutPresentationFormatter.holdDuration(session.bestHoldSeconds),
      ),
      MapEntry(
        localizations.workoutSummaryFormBreaks,
        session.formBreakCount.toString(),
      ),
    ];

    final stability = _resolvedMetricValue(
      liveMetrics,
      fallbackMetrics,
      ExerciseMetricRegistry.stability,
    );
    if (stability != null) {
      values.add(
        MapEntry(localizations.stabilityScore, stability.toStringAsFixed(0)),
      );
    }

    values.add(
      MapEntry(
        localizations.duration,
        WorkoutPresentationFormatter.duration(session.duration),
      ),
    );
    return values;
  }

  final values = <MapEntry<String, String>>[
    MapEntry(
      localizations.exerciseType,
      localizations.exerciseTitle(session.exerciseType),
    ),
    MapEntry(
      localizations.workoutSummaryTotalReps,
      session.totalReps.toString(),
    ),
    MapEntry(
      localizations.workoutSummaryAverageScore,
      WorkoutPresentationFormatter.roundedScore(session.averageScore),
    ),
    MapEntry(
      localizations.workoutSummaryBestScore,
      WorkoutPresentationFormatter.roundedScore(session.bestScore),
    ),
    if (session.validReps > 0 || session.invalidReps > 0) ...[
      MapEntry(
        localizations.workoutSummaryValidReps,
        session.validReps.toString(),
      ),
      MapEntry(
        localizations.workoutSummaryInvalidReps,
        session.invalidReps.toString(),
      ),
    ],
    MapEntry(localizations.formWarning, session.formWarningCount.toString()),
  ];

  final averageRom = _resolvedMetricValue(
    liveMetrics,
    fallbackMetrics,
    ExerciseMetricRegistry.rangeOfMotion,
  );
  if (averageRom != null) {
    values.add(
      MapEntry(localizations.averageRom, '${averageRom.toStringAsFixed(1)}°'),
    );
  }

  final averageTempo = _resolvedMetricValue(
    liveMetrics,
    fallbackMetrics,
    ExerciseMetricRegistry.tempo,
  );
  if (averageTempo != null) {
    values.add(
      MapEntry(
        localizations.averageTempo,
        _formatDuration(localizations, averageTempo),
      ),
    );
  }

  final fastest = liveMetrics?.fastestRepDuration;
  final slowest = liveMetrics?.slowestRepDuration;
  if (fastest != null) {
    values.add(
      MapEntry(
        localizations.fastestRep,
        _formatDuration(localizations, fastest),
      ),
    );
  }
  if (slowest != null) {
    values.add(
      MapEntry(
        localizations.slowestRep,
        _formatDuration(localizations, slowest),
      ),
    );
  }

  final tempoConsistency = liveMetrics?.tempoConsistencyScore;
  if (tempoConsistency != null) {
    values.add(
      MapEntry(
        localizations.tempoConsistency,
        tempoConsistency.toStringAsFixed(0),
      ),
    );
  }

  if (liveMetrics?.hasBilateralRepCounts ?? false) {
    values
      ..add(
        MapEntry(localizations.leftReps, liveMetrics!.leftRepCount.toString()),
      )
      ..add(
        MapEntry(localizations.rightReps, liveMetrics.rightRepCount.toString()),
      );
  }

  final romDifference = _resolvedMetricValue(
    liveMetrics,
    fallbackMetrics,
    ExerciseMetricRegistry.symmetry,
  );
  if (romDifference != null) {
    values.add(
      MapEntry(
        localizations.averageRomDifference,
        '${romDifference.toStringAsFixed(1)}°',
      ),
    );
  }

  final asymmetry = _resolvedMetricValue(
    liveMetrics,
    fallbackMetrics,
    ExerciseMetricRegistry.asymmetryScore,
  );
  if (asymmetry != null) {
    values.add(
      MapEntry(localizations.asymmetryScore, asymmetry.toStringAsFixed(0)),
    );
  }

  values.add(
    MapEntry(
      localizations.duration,
      WorkoutPresentationFormatter.duration(session.duration),
    ),
  );
  return values;
}

T? _resolvedMetricValue<T extends Object>(
  WorkoutLiveMetricsSnapshot? liveMetrics,
  ExerciseMetricSnapshot fallbackMetrics,
  ExerciseMetricDefinition<T> definition,
) {
  return liveMetrics?.sessionMetrics.valueFor(definition) ??
      fallbackMetrics.valueFor(definition);
}

String _formatDuration(AppLocalizations localizations, Duration duration) {
  final milliseconds = duration.inMilliseconds;
  if (milliseconds < 1000) {
    return '$milliseconds ms';
  }
  return localizations.secondsValue(milliseconds / 1000);
}
