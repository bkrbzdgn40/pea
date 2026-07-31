import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../application/exercise_metric_registry.dart';
import '../../application/workout_live_metrics.dart';
import '../../domain/models/session_report.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/workout_presentation_formatter.dart';
import '../providers/completed_session_metrics_provider.dart';
import '../providers/completed_session_provider.dart';
import '../widgets/workout_summary_content.dart';
import 'home_screen.dart';
import 'session_detail_screen.dart';

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
          final summaryValues = _summaryValues(
            localizations,
            session,
            completedMetrics,
          );

          return WorkoutSummaryContent(
            layout: layout,
            session: session,
            report: report,
            summaryValues: summaryValues,
            onRetry: _retry,
            onOpenDetails: () => _openDetails(session),
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

  final hasValidationBreakdown =
      session.validReps > 0 || session.invalidReps > 0;
  final persistedLowConfidenceReps = session.reps
      ?.where(
        (rep) =>
            rep.validationStatus == 'lowConfidence' ||
            rep.validationStatus == 'low confidence',
      )
      .length;
  final lowConfidenceReps =
      persistedLowConfidenceReps ?? session.lowConfidenceReps;

  final values = <MapEntry<String, String>>[
    MapEntry(
      localizations.workoutSummaryTotalReps,
      session.totalReps.toString(),
    ),
    MapEntry(
      localizations.workoutSummaryBestFormRangeScore,
      WorkoutPresentationFormatter.roundedScore(session.bestScore),
    ),
    if (hasValidationBreakdown || lowConfidenceReps > 0) ...[
      MapEntry(
        localizations.workoutSummaryValidReps,
        session.validReps.toString(),
      ),
      if (lowConfidenceReps > 0)
        MapEntry(localizations.lowConfidence, lowConfidenceReps.toString()),
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
