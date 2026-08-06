import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/localization/app_localizations.dart';
import '../../../application/engine_kind.dart';
import '../../formatters/measurement_confidence_presentation_formatter.dart';
import '../../providers/workout_controller.dart';
import '../../providers/workout_plan_session_provider.dart';
import 'live_analysis_theme.dart';

class LiveHudTechnicalDetails extends ConsumerWidget {
  const LiveHudTechnicalDetails({
    super.key,
    required this.compact,
    this.horizontal = false,
    this.includePrimaryMetrics = false,
    this.includePlanProgress = false,
  });

  final bool compact;
  final bool horizontal;
  final bool includePrimaryMetrics;
  final bool includePlanProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final state = ref.watch(
      workoutControllerProvider.select(
        (state) => (
          analysisKind: state.analysisKind,
          repCount: state.repCount,
          currentHoldSeconds: state.currentHoldSeconds,
          bestHoldSeconds: state.bestHoldSeconds,
          lastRepScore: state.lastRepScore,
          lastRepRom: state.lastRepROM,
          currentAngle: state.currentAngle,
          currentPhase: state.currentPhase,
          calibrationMetrics: state.calibrationMetrics,
        ),
      ),
    );
    final liveMetrics = ref.watch(workoutLiveMetricsProvider);
    final planSnapshot = includePlanProgress
        ? ref.watch(
            workoutPlanSessionProvider.select((state) => state.snapshot),
          )
        : null;

    final tempo =
        liveMetrics.tempo ??
        state
            .calibrationMetrics
            .lastRepTempoAssessment
            ?.measurement
            .measuredTempo
            ?.totalRepDuration;
    final rawRom =
        state.calibrationMetrics.lastRangeRepSummaryPrimaryRom ??
        (state.lastRepRom > 0 ? state.lastRepRom : null);
    final rawConfidence =
        state.calibrationMetrics.lastRangeRepSummaryConfidence;
    final confidence = rawConfidence != null && rawConfidence.isFinite
        ? rawConfidence
        : null;
    final angle =
        liveMetrics.angleDegrees ??
        _finiteRounded(state.currentAngle, positiveOnly: true);

    final items = <_LiveHudDetailItem>[
      if (includePrimaryMetrics) ...<_LiveHudDetailItem>[
        _LiveHudDetailItem(
          label: state.analysisKind == EngineKind.hold
              ? localizations.holdMetric
              : localizations.repMetric,
          value: state.analysisKind == EngineKind.hold
              ? _formatSeconds(localizations, state.currentHoldSeconds)
              : state.repCount.toString(),
        ),
        _LiveHudDetailItem(
          label: state.analysisKind == EngineKind.hold
              ? localizations.bestMetric
              : localizations.formRangeScoreMetric,
          value: state.analysisKind == EngineKind.hold
              ? _formatSeconds(localizations, state.bestHoldSeconds)
              : _scoreValue(state.lastRepScore),
        ),
      ],
      _LiveHudDetailItem(
        label: localizations.phaseMetric,
        value: state.currentPhase.trim().isEmpty
            ? '—'
            : localizations.workoutPhaseLabel(state.currentPhase),
      ),
      _LiveHudDetailItem(
        label: localizations.rangeOfMotionMetric,
        value: _degreeValue(rawRom),
      ),
      _LiveHudDetailItem(
        label: localizations.tempoMetric,
        value: tempo == null ? '—' : _formatDuration(localizations, tempo),
      ),
      _LiveHudDetailItem(
        label: localizations.measurementConfidence,
        value: confidence == null
            ? '—'
            : MeasurementConfidencePresentationFormatter.percentage(
                localizations,
                confidence,
              ),
      ),
      if (angle != null)
        _LiveHudDetailItem(label: localizations.angleMetric, value: '$angle°'),
      if (liveMetrics.stabilityScore != null)
        _LiveHudDetailItem(
          label: localizations.stabilityMetric,
          value: liveMetrics.stabilityScore.toString(),
        ),
      if (liveMetrics.asymmetryScore != null)
        _LiveHudDetailItem(
          label: localizations.asymmetryMetric,
          value: liveMetrics.asymmetryScore.toString(),
        ),
      if (includePlanProgress && planSnapshot != null)
        _LiveHudDetailItem(
          label: localizations.liveHudPlanProgress,
          value: localizations.plannedWorkoutProgress(
            round: planSnapshot.roundNumber,
            totalRounds: planSnapshot.totalRounds,
            set: planSnapshot.setNumber,
            totalSets: planSnapshot.setsInCurrentExercise,
          ),
        ),
    ];

    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 2.0).toDouble();
    final horizontalHeight = (compact ? 72.0 : 82.0) * textScale;
    final horizontalTileWidth =
        (compact ? 106.0 : 128.0) * (1 + ((textScale - 1) * 0.5));
    final content = horizontal
        ? SizedBox(
            height: horizontalHeight,
            child: ListView.separated(
              key: const ValueKey<String>('live-hud-technical-details-scroll'),
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
              itemCount: items.length,
              separatorBuilder: (_, _) => SizedBox(width: compact ? 7 : 9),
              itemBuilder: (context, index) => SizedBox(
                width: horizontalTileWidth,
                child: _LiveHudDetailTile(item: items[index], compact: compact),
              ),
            ),
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = constraints.maxWidth < 300
                  ? constraints.maxWidth
                  : (constraints.maxWidth - (compact ? 8 : 10)) / 2;
              return Wrap(
                spacing: compact ? 8 : 10,
                runSpacing: compact ? 8 : 10,
                children: <Widget>[
                  for (final item in items)
                    SizedBox(
                      width: tileWidth,
                      child: _LiveHudDetailTile(item: item, compact: compact),
                    ),
                ],
              );
            },
          );

    return Semantics(
      container: true,
      label: localizations.liveHudTechnicalDetails,
      child: Container(
        key: const ValueKey<String>('live-hud-technical-details'),
        padding: horizontal
            ? EdgeInsets.symmetric(vertical: compact ? 7 : 9)
            : EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(compact ? 18 : 22),
          border: Border.all(color: liveHudAccent.withValues(alpha: 0.36)),
        ),
        child: content,
      ),
    );
  }
}

class _LiveHudDetailItem {
  const _LiveHudDetailItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _LiveHudDetailTile extends StatelessWidget {
  const _LiveHudDetailTile({required this.item, required this.compact});

  final _LiveHudDetailItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 11,
          vertical: compact ? 7 : 9,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              item.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white60,
                fontSize: compact ? 9 : 10,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 13 : 15,
                height: 1.12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int? _finiteRounded(double? value, {bool positiveOnly = false}) {
  if (value == null || !value.isFinite || (positiveOnly && value <= 0)) {
    return null;
  }
  return value.round();
}

String _scoreValue(double value) {
  final rounded = _finiteRounded(value, positiveOnly: true);
  return rounded?.toString() ?? '—';
}

String _degreeValue(double? value) {
  final rounded = _finiteRounded(value, positiveOnly: true);
  return rounded == null ? '—' : '$rounded°';
}

String _formatSeconds(AppLocalizations localizations, double seconds) {
  if (!seconds.isFinite || seconds <= 0) {
    return '—';
  }
  return _formatDuration(
    localizations,
    Duration(milliseconds: (seconds * 1000).round()),
  );
}

String _formatDuration(AppLocalizations localizations, Duration duration) {
  if (duration.inMilliseconds <= 0) {
    return '—';
  }
  if (duration.inMinutes > 0) {
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration.inMinutes}:$seconds';
  }
  final seconds = duration.inMilliseconds / 1000;
  final precision = seconds >= 10 ? 0 : 1;
  return '${seconds.toStringAsFixed(precision)} ${localizations.secondsShort}';
}
