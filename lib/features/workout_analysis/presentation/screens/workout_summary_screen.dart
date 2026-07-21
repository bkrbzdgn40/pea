import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final session = ref.watch(completedSessionProvider);
    final completedMetrics = ref.watch(completedSessionMetricsProvider);
    final summaryValues = session == null
        ? const <MapEntry<String, String>>[]
        : _summaryValues(session, completedMetrics);

    return AppScaffoldShell(
      title: 'Antrenman Özeti',
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
                      ? 'Oturum verisi bulunamadı'
                      : '${WorkoutPresentationFormatter.exerciseTitle(session.exerciseType)} özeti',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  session == null
                      ? 'Canlı analiz tamamlandığında oturum özeti burada görünür.'
                      : 'Canlı analizden oluşturulan gerçek oturum değerleri.',
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
            label: Text(_isRetrying ? 'Hazırlanıyor...' : 'Tekrar Dene'),
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
            label: const Text('Ana Sayfa'),
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
        'Oturum verisi bulunamadı.',
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
  WorkoutSession session,
  WorkoutLiveMetricsSnapshot? liveMetrics,
) {
  final fallbackMetrics = const WorkoutSessionMetricSnapshotBuilder().build(
    session,
  );

  if (session.isHoldSession) {
    final values = <MapEntry<String, String>>[
      MapEntry(
        'Egzersiz tipi',
        WorkoutPresentationFormatter.exerciseTitle(session.exerciseType),
      ),
      MapEntry(
        'Toplam hold',
        WorkoutPresentationFormatter.holdDuration(session.totalHoldSeconds),
      ),
      MapEntry(
        'En iyi hold',
        WorkoutPresentationFormatter.holdDuration(session.bestHoldSeconds),
      ),
      MapEntry('Form kesintisi', session.formBreakCount.toString()),
    ];

    final stability = _resolvedMetricValue(
      liveMetrics,
      fallbackMetrics,
      ExerciseMetricRegistry.stability,
    );
    if (stability != null) {
      values.add(MapEntry('Stabilite skoru', stability.toStringAsFixed(0)));
    }

    values.add(
      MapEntry('Süre', WorkoutPresentationFormatter.duration(session.duration)),
    );
    return values;
  }

  final values = <MapEntry<String, String>>[
    MapEntry(
      'Egzersiz tipi',
      WorkoutPresentationFormatter.exerciseTitle(session.exerciseType),
    ),
    MapEntry('Toplam tekrar', session.totalReps.toString()),
    MapEntry(
      'Ortalama skor',
      WorkoutPresentationFormatter.roundedScore(session.averageScore),
    ),
    MapEntry(
      'En iyi skor',
      WorkoutPresentationFormatter.roundedScore(session.bestScore),
    ),
    if (session.validReps > 0 || session.invalidReps > 0) ...[
      MapEntry('Geçerli tekrar', session.validReps.toString()),
      MapEntry('Geçersiz tekrar', session.invalidReps.toString()),
    ],
    MapEntry('Form uyarısı', session.formWarningCount.toString()),
  ];

  final averageRom = _resolvedMetricValue(
    liveMetrics,
    fallbackMetrics,
    ExerciseMetricRegistry.rangeOfMotion,
  );
  if (averageRom != null) {
    values.add(MapEntry('Ortalama ROM', '${averageRom.toStringAsFixed(1)}°'));
  }

  final averageTempo = _resolvedMetricValue(
    liveMetrics,
    fallbackMetrics,
    ExerciseMetricRegistry.tempo,
  );
  if (averageTempo != null) {
    values.add(MapEntry('Ortalama tempo', _formatDuration(averageTempo)));
  }

  final fastest = liveMetrics?.fastestRepDuration;
  final slowest = liveMetrics?.slowestRepDuration;
  if (fastest != null) {
    values.add(MapEntry('En hızlı tekrar', _formatDuration(fastest)));
  }
  if (slowest != null) {
    values.add(MapEntry('En yavaş tekrar', _formatDuration(slowest)));
  }

  final tempoConsistency = liveMetrics?.tempoConsistencyScore;
  if (tempoConsistency != null) {
    values.add(
      MapEntry('Tempo tutarlılığı', tempoConsistency.toStringAsFixed(0)),
    );
  }

  if (liveMetrics?.hasBilateralRepCounts ?? false) {
    values
      ..add(MapEntry('Sol tekrar', liveMetrics!.leftRepCount.toString()))
      ..add(MapEntry('Sağ tekrar', liveMetrics.rightRepCount.toString()));
  }

  final romDifference = _resolvedMetricValue(
    liveMetrics,
    fallbackMetrics,
    ExerciseMetricRegistry.symmetry,
  );
  if (romDifference != null) {
    values.add(
      MapEntry('Ortalama ROM farkı', '${romDifference.toStringAsFixed(1)}°'),
    );
  }

  final asymmetry = _resolvedMetricValue(
    liveMetrics,
    fallbackMetrics,
    ExerciseMetricRegistry.asymmetryScore,
  );
  if (asymmetry != null) {
    values.add(MapEntry('Asimetri skoru', asymmetry.toStringAsFixed(0)));
  }

  values.add(
    MapEntry('Süre', WorkoutPresentationFormatter.duration(session.duration)),
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

String _formatDuration(Duration duration) {
  final milliseconds = duration.inMilliseconds;
  if (milliseconds < 1000) {
    return '$milliseconds ms';
  }
  return '${(milliseconds / 1000).toStringAsFixed(1)} sn';
}
