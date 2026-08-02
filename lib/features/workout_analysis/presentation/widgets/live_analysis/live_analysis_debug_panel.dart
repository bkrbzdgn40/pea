import 'package:flutter/material.dart';

import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/workout_live_metric_display_state.dart';

class LiveCanonicalMetricsBar extends StatelessWidget {
  const LiveCanonicalMetricsBar({
    super.key,
    required this.metrics,
    this.compact = false,
  });

  final WorkoutLiveMetricDisplayState metrics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final items = <MapEntry<String, String>>[];

    final angleDegrees = metrics.angleDegrees;
    if (angleDegrees != null) {
      items.add(
        MapEntry<String, String>(localizations.angleMetric, '$angleDegrees°'),
      );
    }

    final tempo = metrics.tempo;
    if (tempo != null) {
      items.add(
        MapEntry<String, String>(
          localizations.tempoMetric,
          _formatMetricDuration(localizations, tempo),
        ),
      );
    }

    final stabilityScore = metrics.stabilityScore;
    if (stabilityScore != null) {
      items.add(
        MapEntry<String, String>(
          localizations.stabilityMetric,
          stabilityScore.toString(),
        ),
      );
    }

    final asymmetryScore = metrics.asymmetryScore;
    if (asymmetryScore != null) {
      items.add(
        MapEntry<String, String>(
          localizations.asymmetryMetric,
          asymmetryScore.toString(),
        ),
      );
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      key: const ValueKey<String>('live-canonical-metrics-bar'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(compact ? 18 : 14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          for (var index = 0; index < items.take(3).length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    items[index].key,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: compact ? 8 : 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[index].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatMetricDuration(
  AppLocalizations localizations,
  Duration duration,
) {
  if (duration.inMilliseconds < 1000) {
    return '${duration.inMilliseconds} ms';
  }
  return localizations.secondsValue(duration.inMilliseconds / 1000);
}

class CalibrationDebugPanel extends StatelessWidget {
  const CalibrationDebugPanel({
    super.key,
    required this.workoutState,
    required this.onClose,
  });

  final WorkoutState workoutState;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final metrics = workoutState.calibrationMetrics;
    final isHoldAnalysis = workoutState.analysisKind == EngineKind.hold;
    final scrollMaxHeight = MediaQuery.of(context).size.height * 0.42;

    final holdRows = <Widget>[
      _DebugMetricRow(
        label: 'body line',
        value: _formatOptionalAngle(
          metrics.currentBodyLineAngle,
          isAvailable: metrics.hasBodyLineAngle,
        ),
      ),
      _DebugMetricRow(
        label: 'arm support',
        value: _formatOptionalAngle(
          metrics.currentArmSupportAngle,
          isAvailable: metrics.hasArmSupportAngle,
        ),
      ),
      _DebugMetricRow(
        label: 'leg extension',
        value: _formatOptionalAngle(
          metrics.currentLegExtensionAngle,
          isAvailable: metrics.hasLegExtensionAngle,
        ),
      ),
      _DebugMetricRow(label: 'coverage', value: _formatHoldCoverage(metrics)),
      _DebugMetricRow(
        label: 'body target',
        value: _formatAngle(metrics.formThreshold),
      ),
      _DebugMetricRow(
        label: 'isFormBad',
        value: workoutState.isFormBad ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'isHolding',
        value: workoutState.isHolding ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'hold break',
        value: workoutState.hadHoldFormBreak ? 'true' : 'false',
      ),
    ];

    final rangeRepCoreRows = <Widget>[
      _DebugMetricRow(
        label: 'primary/current',
        value: _formatAngle(workoutState.currentAngle),
      ),
      _DebugMetricRow(
        label: 'form/current',
        value: _formatAngle(metrics.currentBackAngle),
      ),
      _DebugMetricRow(
        label: 'threshold',
        value: _formatAngle(metrics.formThreshold),
      ),
      _DebugMetricRow(
        label: 'isFormBad',
        value: workoutState.isFormBad ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'frame valid',
        value: metrics.isRangeRepFrameValid ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'selected side',
        value: metrics.selectedRangeRepSide ?? '--',
      ),
      _DebugMetricRow(
        label: 'side reason',
        value: metrics.rangeRepSideSelectionReason ?? '--',
      ),
      if (metrics.rangeRepSideHysteresisStatus != null)
        _DebugMetricRow(
          label: 'SideHys',
          value: metrics.rangeRepSideHysteresisStatus!,
        ),
      if (metrics.rangeRepSideConsistencyStatus != null)
        _DebugMetricRow(
          label: 'SideRep',
          value: metrics.rangeRepSideConsistencyStatus!,
        ),
      _DebugMetricRow(
        label: 'invalid reason',
        value: metrics.rangeRepInvalidReason ?? '--',
      ),
      _DebugMetricRow(
        label: 'visibility',
        value: metrics.rangeRepVisibilityStatus,
      ),
      _DebugMetricRow(
        label: 'invalid streak',
        value: metrics.rangeRepInvalidFrameStreak.toString(),
      ),
      _DebugMetricRow(
        label: 'invalid duration',
        value: _formatMilliseconds(metrics.rangeRepInvalidDurationMs),
      ),
      _DebugMetricRow(
        label: 'resync triggered',
        value: metrics.rangeRepResyncTriggered ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'resync reason',
        value: metrics.rangeRepResyncReason ?? '--',
      ),
      _DebugMetricRow(
        label: 'phase gate',
        value: metrics.rangeRepPhaseGateStatus,
      ),
      _DebugMetricRow(
        label: 'pending transition',
        value: metrics.rangeRepPendingTransition ?? '--',
      ),
      _DebugMetricRow(
        label: 'last transition',
        value: metrics.rangeRepLastConfirmedTransition ?? '--',
      ),
      _DebugMetricRow(
        label: 'coverage',
        value: _formatRangeRepCoverage(metrics),
      ),
      _DebugMetricRow(
        label: 'side coverage',
        value: _formatRangeRepSideCoverage(metrics),
      ),
      if (metrics.leftRangeRepSideConfidence != null)
        _DebugMetricRow(
          label: 'L Conf',
          value: _formatTelemetryValue(metrics.leftRangeRepSideConfidence!),
        ),
      if (metrics.rightRangeRepSideConfidence != null)
        _DebugMetricRow(
          label: 'R Conf',
          value: _formatTelemetryValue(metrics.rightRangeRepSideConfidence!),
        ),
    ];

    final signalRows = <Widget>[
      if (metrics.currentTorsoAngle != null)
        _DebugMetricRow(
          label: 'Torso',
          value: _formatTelemetryValue(metrics.currentTorsoAngle!),
        ),
      if (metrics.currentDepthMetric != null)
        _DebugMetricRow(
          label: 'Depth',
          value: _formatTelemetryValue(metrics.currentDepthMetric!),
        ),
      if (metrics.currentAlignmentMetric != null)
        _DebugMetricRow(
          label: 'Align',
          value: _formatTelemetryValue(metrics.currentAlignmentMetric!),
        ),
      if (metrics.currentStabilityMetric != null)
        _DebugMetricRow(
          label: 'Stability',
          value: _formatTelemetryValue(metrics.currentStabilityMetric!),
        ),
      if (metrics.currentLockoutMetric != null)
        _DebugMetricRow(
          label: 'Lockout',
          value: _formatTelemetryValue(metrics.currentLockoutMetric!),
        ),
      if (metrics.currentBottomControlMetric != null)
        _DebugMetricRow(
          label: 'BottomCtrl',
          value: _formatTelemetryValue(metrics.currentBottomControlMetric!),
        ),
    ];

    final thresholdRows = <Widget>[
      _DebugMetricRow(
        label: 'Current',
        value: _formatThresholdCurrent(metrics),
      ),
      _DebugMetricRow(
        label: 'Decision',
        value: _formatThresholdDecisionMeta(metrics),
      ),
      _DebugMetricRow(
        label: 'Session',
        value: _formatThresholdDecisionSummary(metrics),
      ),
    ];

    final validationRows = <Widget>[
      _DebugMetricRow(
        label: 'ValidCount',
        value: metrics.rangeRepValidatedCount.toString(),
      ),
      _DebugMetricRow(
        label: 'LowConfCount',
        value: metrics.rangeRepLowConfidenceCount.toString(),
      ),
      _DebugMetricRow(
        label: 'InvalidCount',
        value: metrics.rangeRepInvalidCount.toString(),
      ),
      if (metrics.hasLastRangeRepValidation) ...[
        _DebugMetricRow(
          label: 'Validation',
          value: metrics.lastRangeRepValidationStatus ?? '--',
        ),
        if (metrics.lastRangeRepValidatedRepIndex != null)
          _DebugMetricRow(
            label: 'Rep',
            value: metrics.lastRangeRepValidatedRepIndex.toString(),
          ),
        if (metrics.lastRangeRepValidationReasons.isNotEmpty)
          _DebugMetricRow(
            label: 'Reasons',
            value: metrics.lastRangeRepValidationReasons.join(', '),
          ),
      ],
    ];

    final phaseRows = <Widget>[
      if (metrics.descendingPhaseDurationMs != null)
        _DebugMetricRow(
          label: 'DescMs',
          value: metrics.descendingPhaseDurationMs.toString(),
        ),
      if (metrics.peakPhaseDurationMs != null)
        _DebugMetricRow(
          label: 'PeakMs',
          value: metrics.peakPhaseDurationMs.toString(),
        ),
      if (metrics.ascendingPhaseDurationMs != null)
        _DebugMetricRow(
          label: 'AscMs',
          value: metrics.ascendingPhaseDurationMs.toString(),
        ),
      if (metrics.descendingPhaseWorstFormMetric != null)
        _DebugMetricRow(
          label: 'DescForm',
          value: _formatPhaseFormTelemetry(
            metrics.descendingPhaseWorstFormMetric,
            metrics.descendingPhaseHadFormViolation,
          ),
        ),
      if (metrics.peakPhaseWorstFormMetric != null)
        _DebugMetricRow(
          label: 'PeakForm',
          value: _formatPhaseFormTelemetry(
            metrics.peakPhaseWorstFormMetric,
            metrics.peakPhaseHadFormViolation,
          ),
        ),
      if (metrics.ascendingPhaseWorstFormMetric != null)
        _DebugMetricRow(
          label: 'AscForm',
          value: _formatPhaseFormTelemetry(
            metrics.ascendingPhaseWorstFormMetric,
            metrics.ascendingPhaseHadFormViolation,
          ),
        ),
      _DebugMetricRow(label: 'DescQ', value: metrics.descendingPhaseStatus),
      if (metrics.descendingPhaseIssues.isNotEmpty)
        _DebugMetricRow(
          label: 'DescIssues',
          value: metrics.descendingPhaseIssues.join(', '),
        ),
      _DebugMetricRow(label: 'PeakQ', value: metrics.peakPhaseStatus),
      if (metrics.peakPhaseIssues.isNotEmpty)
        _DebugMetricRow(
          label: 'PeakIssues',
          value: metrics.peakPhaseIssues.join(', '),
        ),
      _DebugMetricRow(label: 'AscQ', value: metrics.ascendingPhaseStatus),
      if (metrics.ascendingPhaseIssues.isNotEmpty)
        _DebugMetricRow(
          label: 'AscIssues',
          value: metrics.ascendingPhaseIssues.join(', '),
        ),
      if (metrics.phaseQualityPenalty != null)
        _DebugMetricRow(
          label: 'PhasePenalty',
          value: _formatTelemetryValue(metrics.phaseQualityPenalty!),
        ),
      if (metrics.phaseAdjustedScore != null)
        _DebugMetricRow(
          label: 'PhaseScore',
          value: _formatTelemetryValue(metrics.phaseAdjustedScore!),
        ),
      if (metrics.phaseFeedbackCandidate != null)
        _DebugMetricRow(
          label: 'PhaseCue',
          value: metrics.phaseFeedbackCandidate!,
        ),
    ];

    final lastRepRows = <Widget>[
      if (metrics.hasLastRangeRepSummary) ...[
        if (metrics.lastRangeRepSummaryMinAngle != null)
          _DebugMetricRow(
            label: 'MinAngle',
            value: _formatTelemetryValue(metrics.lastRangeRepSummaryMinAngle!),
          ),
        if (metrics.lastRangeRepSummaryWorstFormMetric != null)
          _DebugMetricRow(
            label: 'WorstForm',
            value: _formatTelemetryValue(
              metrics.lastRangeRepSummaryWorstFormMetric!,
            ),
          ),
        if (metrics.lastRangeRepSummaryDescentMillis != null)
          _DebugMetricRow(
            label: 'DescentMs',
            value: metrics.lastRangeRepSummaryDescentMillis.toString(),
          ),
        if (metrics.lastRangeRepSummaryAscentMillis != null)
          _DebugMetricRow(
            label: 'AscentMs',
            value: metrics.lastRangeRepSummaryAscentMillis.toString(),
          ),
        _DebugMetricRow(
          label: 'FormBreak',
          value: metrics.lastRangeRepSummaryHadFormViolation ? 'true' : 'false',
        ),
        _DebugMetricRow(
          label: 'CoverageDrop',
          value: metrics.lastRangeRepSummaryHadCoverageDrop ? 'true' : 'false',
        ),
        _DebugMetricRow(
          label: 'SideSwitch',
          value: metrics.lastRangeRepSummarySwitchedSideDuringRep
              ? 'true'
              : 'false',
        ),
        _DebugMetricRow(
          label: 'FullPhase',
          value: metrics.lastRangeRepSummaryCompletedPhaseSequence
              ? 'true'
              : 'false',
        ),
        _DebugMetricRow(
          label: 'Side',
          value: metrics.lastRangeRepSummarySelectedSideLabel ?? '--',
        ),
      ],
      _DebugMetricRow(
        label: 'rep worst back',
        value: _formatAngle(metrics.currentRepWorstBackAngle),
      ),
      _DebugMetricRow(
        label: 'rep violation',
        value: metrics.currentRepHadFormViolation ? 'true' : 'false',
      ),
      if (metrics.hasLastRepBreakdown) ...[
        const Divider(color: Colors.white24, height: 14),
        Text(
          'last rep: score ${workoutState.lastRepScore.toStringAsFixed(1)} | '
          'rom ${metrics.lastRepRomScore.toStringAsFixed(1)} | '
          'desc ${metrics.lastRepDescentScore.toStringAsFixed(1)} | '
          'asc ${metrics.lastRepAscentScore.toStringAsFixed(1)}',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          'last form: worst ${_formatAngle(metrics.lastRepWorstBackAngle)} | '
          'violation ${metrics.lastRepHadFormViolation ? 'true' : 'false'}',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.45)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white70, fontSize: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Calibration',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: scrollMaxHeight),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isHoldAnalysis)
                        _DebugSection(title: 'Hold', children: holdRows)
                      else ...[
                        _DebugSection(
                          title: 'Core',
                          children: rangeRepCoreRows,
                        ),
                        if (signalRows.isNotEmpty)
                          _DebugSection(title: 'Signals', children: signalRows),
                        _DebugSection(
                          title: 'Validation',
                          children: validationRows,
                        ),
                        _DebugSection(
                          title: 'Threshold',
                          children: thresholdRows,
                        ),
                        _DebugSection(title: 'Phase', children: phaseRows),
                        _DebugSection(title: 'Last Rep', children: lastRepRows),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatOptionalAngle(double? value, {required bool isAvailable}) {
  if (!isAvailable || value == null) {
    return '--';
  }

  return _formatAngle(value);
}

String _formatTelemetryValue(double value) {
  return value.toStringAsFixed(1);
}

String _formatHoldCoverage(WorkoutCalibrationMetrics metrics) {
  final bodyCoverage = metrics.hasBodyLineAngle ? 'body ok' : 'body missing';
  final armCoverage = metrics.hasArmSupportAngle ? 'arm ok' : 'arm missing';
  final legCoverage = metrics.hasLegExtensionAngle ? 'leg ok' : 'leg missing';

  return '$bodyCoverage / $armCoverage / $legCoverage';
}

String _formatRangeRepCoverage(WorkoutCalibrationMetrics metrics) {
  final primaryCoverage = metrics.hasPrimaryAngle
      ? 'primary ok'
      : 'primary missing';
  final formCoverage = metrics.hasFormMetric ? 'form ok' : 'form missing';

  return '$primaryCoverage / $formCoverage';
}

String _formatRangeRepSideCoverage(WorkoutCalibrationMetrics metrics) {
  return 'L ${metrics.leftRangeRepCoverage}/2 / '
      'R ${metrics.rightRangeRepCoverage}/2';
}

String _formatThresholdCurrent(WorkoutCalibrationMetrics metrics) {
  final baseThreshold = metrics.baseFormThreshold ?? metrics.formThreshold;
  final effectiveThreshold =
      metrics.effectiveFormThreshold ?? metrics.formThreshold;
  final parts = <String>[
    'base ${_formatAngle(baseThreshold)}',
    'eff ${_formatAngle(effectiveThreshold)}',
  ];

  if (metrics.calibrationThresholdOffsetCandidate != null) {
    final offset = metrics.calibrationThresholdOffsetCandidate!;
    final sign = offset >= 0 ? '+' : '';
    parts.add('off $sign${_formatTelemetryValue(offset)}');
  }

  return parts.join(' | ');
}

String _formatThresholdDecisionMeta(WorkoutCalibrationMetrics metrics) {
  final parts = <String>[
    metrics.calibrationThresholdOffsetFallbackReason ?? '--',
  ];

  if (metrics.calibrationThresholdOffsetSampleCount != null) {
    parts.add('n ${metrics.calibrationThresholdOffsetSampleCount}');
  }
  if (metrics.calibrationThresholdOffsetBaselineSideLabel != null) {
    parts.add('side ${metrics.calibrationThresholdOffsetBaselineSideLabel}');
  }

  return parts.join(' | ');
}

String _formatThresholdDecisionSummary(WorkoutCalibrationMetrics metrics) {
  return 'all ${metrics.calibrationThresholdDecisionCount} | '
      'ap ${metrics.calibrationThresholdAppliedCount} | '
      'nb ${metrics.calibrationThresholdNoBaselineCount} | '
      'ins ${metrics.calibrationThresholdInsufficientSamplesCount} | '
      'miss ${metrics.calibrationThresholdMissingFormBaselineCount} | '
      'side ${metrics.calibrationThresholdSideMismatchCount} | '
      'small ${metrics.calibrationThresholdOffsetTooSmallCount}';
}

String _formatMilliseconds(int milliseconds) {
  return '${milliseconds}ms';
}

String _formatPhaseFormTelemetry(
  double? worstFormMetric,
  bool hadFormViolation,
) {
  final worstValue = worstFormMetric == null
      ? '--'
      : _formatTelemetryValue(worstFormMetric);

  return '$worstValue / ${hadFormViolation ? 'true' : 'false'}';
}

class _DebugSection extends StatelessWidget {
  const _DebugSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _DebugMetricRow extends StatelessWidget {
  const _DebugMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAngle(double value) {
  return '${value.toStringAsFixed(1)}°';
}
