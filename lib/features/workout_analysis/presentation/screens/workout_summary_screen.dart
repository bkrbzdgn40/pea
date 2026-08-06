import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_state_views.dart';
import '../../application/exercise_metric_registry.dart';
import '../../application/workout_live_metrics.dart';
import '../../domain/models/session_report.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/measurement_confidence_presentation_formatter.dart';
import '../formatters/session_measurement_evidence_presenter.dart';
import '../formatters/workout_presentation_formatter.dart';
import '../providers/completed_session_metrics_provider.dart';
import '../providers/completed_session_provider.dart';
import '../widgets/workout_summary_content.dart';
import 'home_screen.dart';
import 'session_detail_screen.dart';
import 'session_history_screen.dart';

class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  const WorkoutSummaryScreen({super.key});

  @override
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  void _retry() {
    Navigator.pop(context, true);
  }

  void _returnHistory() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const SessionHistoryScreen()),
      (route) => false,
    );
  }

  void _returnHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _openDetails(WorkoutSession session) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SessionDetailScreen(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final session = ref.watch(completedSessionProvider);
    final completedMetrics = ref.watch(completedSessionMetricsProvider);

    return AppScaffoldShell(
      title: localizations.workoutSummary,
      showDrawer: false,
      padding: EdgeInsets.zero,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppLayout.of(context, constraints: constraints);
          if (session == null) {
            return Padding(
              padding: layout.pagePadding,
              child: const _MissingSessionView(),
            );
          }

          final report = SessionReport.fromSession(
            session: session,
            reps: session.reps ?? const [],
          );
          final volumeValues = _volumeValues(localizations, session);
          final detailValues = _detailValues(
            localizations,
            session,
            completedMetrics,
          );

          return WorkoutSummaryContent(
            layout: layout,
            session: session,
            report: report,
            volumeValues: volumeValues,
            detailValues: detailValues,
            onRetry: _retry,
            onOpenDetails: () => _openDetails(session),
            onReturnHistory: _returnHistory,
            onReturnHome: _returnHome,
          );
        },
      ),
    );
  }
}

class _MissingSessionView extends StatelessWidget {
  const _MissingSessionView();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AppEmptyView(
      centered: true,
      icon: Icons.summarize_outlined,
      title: localizations.sessionDataMissing,
      message: localizations.sessionDataMissingDetail,
    );
  }
}

List<MapEntry<String, String>> _volumeValues(
  AppLocalizations localizations,
  WorkoutSession session,
) {
  if (session.isHoldSession) {
    return <MapEntry<String, String>>[
      MapEntry(
        localizations.workoutSummaryTotalHold,
        WorkoutPresentationFormatter.holdDuration(session.totalHoldSeconds),
      ),
      MapEntry(
        localizations.duration,
        WorkoutPresentationFormatter.duration(session.duration),
      ),
    ];
  }

  return <MapEntry<String, String>>[
    MapEntry(
      localizations.workoutSummaryTotalReps,
      session.totalReps.toString(),
    ),
    MapEntry(
      localizations.duration,
      WorkoutPresentationFormatter.duration(session.duration),
    ),
  ];
}

List<MapEntry<String, String>> _detailValues(
  AppLocalizations localizations,
  WorkoutSession session,
  WorkoutLiveMetricsSnapshot? liveMetrics,
) {
  final fallbackMetrics = const WorkoutSessionMetricSnapshotBuilder().build(
    session,
  );
  final values = <MapEntry<String, String>>[
    ..._measurementEvidenceValues(localizations, session),
  ];

  if (session.isHoldSession) {
    values.add(
      MapEntry(
        localizations.workoutSummaryFormBreaks,
        session.formBreakCount.toString(),
      ),
    );

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
    return values;
  }

  values.addAll(<MapEntry<String, String>>[
    MapEntry(
      localizations.workoutSummaryBestFormRangeScore,
      WorkoutPresentationFormatter.roundedScore(session.bestScore),
    ),
    MapEntry(localizations.formWarning, session.formWarningCount.toString()),
  ]);

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
        _formatRepDuration(localizations, averageTempo),
      ),
    );
    final fastestRepDuration = liveMetrics?.fastestRepDuration;
    if (fastestRepDuration != null) {
      values.add(
        MapEntry(
          localizations.fastestRep,
          _formatRepDuration(localizations, fastestRepDuration),
        ),
      );
    }
    final slowestRepDuration = liveMetrics?.slowestRepDuration;
    if (slowestRepDuration != null) {
      values.add(
        MapEntry(
          localizations.slowestRep,
          _formatRepDuration(localizations, slowestRepDuration),
        ),
      );
    }
    final tempoConsistencyScore = liveMetrics?.tempoConsistencyScore;
    if (tempoConsistencyScore != null) {
      values.add(
        MapEntry(
          localizations.tempoConsistency,
          tempoConsistencyScore.toStringAsFixed(0),
        ),
      );
    }
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

  return values;
}

List<MapEntry<String, String>> _measurementEvidenceValues(
  AppLocalizations localizations,
  WorkoutSession session,
) {
  final confidence =
      SessionMeasurementEvidencePresenter.confidenceLabel(
        session.averageMeasurementConfidence,
      ) ??
      MeasurementConfidencePresentationFormatter.percentage(
        localizations,
        MeasurementConfidencePresentationFormatter.averageKnown(
          session.reps ?? const [],
        ),
      );

  return <MapEntry<String, String>>[
    MapEntry(
      localizations.measurementQuality,
      SessionMeasurementEvidencePresenter.qualityLabel(
        localizations,
        session.measurementQuality,
      ),
    ),
    MapEntry(
      localizations.preparationCheck,
      SessionMeasurementEvidencePresenter.preparationLabel(
        localizations,
        session.preparationOutcome,
      ),
    ),
    MapEntry(localizations.averageMeasurementConfidence, confidence),
    if (session.measurementSampleCount > 0)
      MapEntry(
        localizations.measurementEvidence,
        localizations.measurementSampleCount(session.measurementSampleCount),
      ),
  ];
}

T? _resolvedMetricValue<T extends Object>(
  WorkoutLiveMetricsSnapshot? liveMetrics,
  ExerciseMetricSnapshot fallbackMetrics,
  ExerciseMetricDefinition<T> definition,
) {
  return liveMetrics?.sessionMetrics.valueFor(definition) ??
      fallbackMetrics.valueFor(definition);
}

String _formatRepDuration(AppLocalizations localizations, Duration duration) {
  final seconds = (duration.inMilliseconds / 1000).toStringAsFixed(1);
  return localizations.pick(tr: '$seconds sn', en: '$seconds s');
}
