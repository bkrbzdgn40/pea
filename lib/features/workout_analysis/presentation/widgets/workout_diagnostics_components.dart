import 'package:flutter/material.dart';

import '../../application/workout_diagnostics.dart';
import '../../domain/models/analysis_signal_role.dart';
import '../../domain/models/camera_view_contract.dart';
import '../../domain/models/hold_contract.dart';
import '../../domain/models/hold_feedback_code.dart';
import '../../domain/models/hold_phase.dart';
import '../../domain/models/measurement_confidence_breakdown.dart';
import '../../domain/models/range_rep_contract.dart';

const String missingDiagnosticsValue = '\u2014';

class DiagnosticsSection extends StatelessWidget {
  const DiagnosticsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class DiagnosticsRow extends StatelessWidget {
  const DiagnosticsRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> buildHoldSignalRows(WorkoutDiagnosticsSnapshot snapshot) {
  return <Widget>[
    for (final signal in snapshot.holdSignals)
      DiagnosticsRow(
        label: signal.name,
        value: formatHoldSignalDiagnostic(snapshot, signal),
      ),
  ];
}

List<Widget> buildCameraViewRows(CameraViewContract contract) {
  return <Widget>[
    for (final view in CameraView.values)
      DiagnosticsRow(
        label: 'Camera ${view.name}',
        value: contract.supportFor(view).name,
      ),
  ];
}

List<Widget> buildRangeRepTimingTraceRows(WorkoutDiagnosticsSnapshot snapshot) {
  final trace =
      snapshot.activeRangeRepTimingTrace ??
      snapshot.lastEndedRangeRepTimingTrace;
  if (trace == null) {
    return <Widget>[
      DiagnosticsRow(label: 'Trace', value: missingDiagnosticsValue),
      DiagnosticsRow(
        label: 'Non-monotonic observations',
        value: snapshot.nonMonotonicRangeRepObservationCount.toString(),
      ),
    ];
  }

  final transitionSummary = trace.transitions.isEmpty
      ? missingDiagnosticsValue
      : trace.transitions
            .map(
              (transition) =>
                  '${transition.type} (+${transition.confirmationLagMs}ms)',
            )
            .join(' > ');

  return <Widget>[
    DiagnosticsRow(label: 'Outcome', value: trace.outcome.name),
    DiagnosticsRow(label: 'Samples', value: trace.sampleCount.toString()),
    DiagnosticsRow(
      label: 'Phase samples',
      value:
          '${trace.towardPeakSampleCount} / '
          '${trace.peakSampleCount} / ${trace.returnSampleCount}',
    ),
    DiagnosticsRow(
      label: 'Observation interval avg',
      value: formatDouble(trace.averageObservationIntervalMs, suffix: ' ms'),
    ),
    DiagnosticsRow(
      label: 'Observation interval max',
      value: formatMilliseconds(trace.maxObservationIntervalMs),
    ),
    DiagnosticsRow(
      label: 'Processing lag last',
      value: formatMilliseconds(trace.lastProcessingLagMs),
    ),
    DiagnosticsRow(
      label: 'Processing lag max',
      value: formatMilliseconds(trace.maxProcessingLagMs),
    ),
    DiagnosticsRow(
      label: 'Direction changes',
      value: trace.directionChangeCount.toString(),
    ),
    DiagnosticsRow(
      label: 'Visibility gap',
      value: trace.hadVisibilityGap ? 'yes' : 'no',
    ),
    DiagnosticsRow(
      label: 'Sparse recovery',
      value: trace.usedSparseCycleRecovery ? 'yes' : 'no',
    ),
    DiagnosticsRow(
      label: 'Non-monotonic observations',
      value: snapshot.nonMonotonicRangeRepObservationCount.toString(),
    ),
    DiagnosticsRow(
      label: 'Invalid processing lags',
      value: trace.invalidProcessingLagCount.toString(),
    ),
    DiagnosticsRow(
      label: 'Tempo measurement status',
      value: formatOptionalText(
        snapshot.lastTempoMeasurementAssessment?.status.name,
      ),
    ),
    DiagnosticsRow(
      label: 'Tempo measurement issues',
      value: formatStringList(
        snapshot.lastTempoMeasurementAssessment?.issues
                .map((issue) => issue.name)
                .toList(growable: false) ??
            const <String>[],
      ),
    ),
    DiagnosticsRow(label: 'Transitions', value: transitionSummary),
  ];
}

List<Widget> buildRangeRepSignalRoleRows(WorkoutDiagnosticsSnapshot snapshot) {
  return <Widget>[
    for (final signal in RangeRepSignal.values)
      if (snapshot.rangeRepSignalRoles.containsKey(signal))
        DiagnosticsRow(
          label: '${signal.name} roles',
          value: formatAnalysisSignalRoles(
            snapshot.rangeRepSignalRoles[signal]!,
          ),
        ),
  ];
}

List<Widget> buildHoldSignalRoleRows(WorkoutDiagnosticsSnapshot snapshot) {
  return <Widget>[
    for (final signal in HoldSignal.values)
      if (snapshot.holdSignalRoles.containsKey(signal))
        DiagnosticsRow(
          label: '${signal.name} roles',
          value: formatAnalysisSignalRoles(snapshot.holdSignalRoles[signal]!),
        ),
  ];
}

String formatAnalysisSignalRoles(Set<AnalysisSignalRole> roles) {
  return AnalysisSignalRole.values
      .where(roles.contains)
      .map((role) => role.name)
      .join(', ');
}

String formatHoldSignalDiagnostic(
  WorkoutDiagnosticsSnapshot snapshot,
  HoldSignal signal,
) {
  final currentValue = snapshot.currentHoldSignalValue(signal);
  final targetValue = snapshot.targetHoldSignalValue(signal);
  final validity = snapshot.holdSignalValidityFor(signal);
  final currentLabel = currentValue == null
      ? missingDiagnosticsValue
      : formatSignalValue(currentValue);
  final targetLabel = targetValue == null
      ? missingDiagnosticsValue
      : formatHoldSignalTarget(signal, targetValue);
  final validityLabel = validity == null
      ? missingDiagnosticsValue
      : (validity ? 'valid' : 'invalid');

  return '$currentLabel / target $targetLabel / $validityLabel';
}

String formatSignalValue(double value) => value.toStringAsFixed(1);

String formatHoldSignalTarget(HoldSignal signal, double value) {
  final formattedValue = formatSignalValue(value);
  switch (signal) {
    case HoldSignal.alignment:
    case HoldSignal.extension:
    case HoldSignal.armExtension:
    case HoldSignal.kneeExtension:
    case HoldSignal.torsoAlignment:
      return '>= $formattedValue';
    case HoldSignal.compression:
      return '<= $formattedValue';
    case HoldSignal.supportStacking:
    case HoldSignal.hipClearance:
      return '>= $formattedValue';
    case HoldSignal.kneeFlexion:
    case HoldSignal.hipFlexion:
      return '~ $formattedValue';
    case HoldSignal.support:
      return formattedValue;
  }
}

String buildDiagnosticsFileName(WorkoutDiagnosticsSnapshot snapshot) {
  final exercise = sanitizeFileNamePart(snapshot.exerciseType);
  final timestamp = formatFileTimestamp(snapshot.snapshotCreatedAt);
  return 'diagnostics_v${snapshot.schemaVersion}_${exercise}_$timestamp.json';
}

String sanitizeFileNamePart(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  );
  final sanitized = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
  return sanitized.isEmpty ? 'unknown_exercise' : sanitized;
}

String formatFileTimestamp(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}_'
      '${twoDigits(value.hour)}${twoDigits(value.minute)}${twoDigits(value.second)}';
}

String formatMeasurementConfidence(MeasurementConfidenceBreakdown? breakdown) {
  if (breakdown == null) {
    return missingDiagnosticsValue;
  }

  String component(double? value) =>
      value == null ? missingDiagnosticsValue : value.toStringAsFixed(3);
  final issues = breakdown.issues.isEmpty
      ? 'none'
      : breakdown.issues.map((issue) => issue.code).join(',');
  return 'combined=${component(breakdown.combined)} '
      'landmark=${component(breakdown.landmarkLikelihood)} '
      'signal=${component(breakdown.signalAvailability)} '
      'geometry=${component(breakdown.geometryPlausibility)} '
      'temporal=${component(breakdown.temporalContinuity)} '
      'issues=$issues';
}

String formatCountMap(Map<String, int> counts) {
  if (counts.isEmpty) {
    return missingDiagnosticsValue;
  }
  final keys = counts.keys.toList()..sort();
  return keys.map((key) => '$key=${counts[key]}').join(', ');
}

String formatOptionalText(String? value) =>
    value == null || value.isEmpty ? missingDiagnosticsValue : value;

String formatStringList(List<String> values) =>
    values.isEmpty ? missingDiagnosticsValue : values.join(', ');

String formatHoldFeedbackCode(HoldFeedbackCode? code) =>
    code == null ? missingDiagnosticsValue : code.code;

String formatHoldFeedbackFamily(HoldFeedbackCode? code) =>
    code == null ? missingDiagnosticsValue : code.family.name;

String formatHoldPhase(HoldPhase? phase) =>
    phase == null ? missingDiagnosticsValue : phase.code;

String formatInt(int? value) => value?.toString() ?? missingDiagnosticsValue;

String formatMilliseconds(int? value) =>
    value == null ? missingDiagnosticsValue : '$value ms';

String formatBool(bool? value) {
  if (value == null) {
    return missingDiagnosticsValue;
  }
  return value ? 'Evet' : 'Hay\u0131r';
}

String formatDouble(double? value, {required String suffix}) {
  if (value == null) {
    return missingDiagnosticsValue;
  }
  return '${value.toStringAsFixed(1)}$suffix';
}

String formatHoldDuration(int? seconds) {
  if (seconds == null) {
    return missingDiagnosticsValue;
  }
  if (seconds < 60) {
    return '$seconds sn';
  }
  final duration = Duration(seconds: seconds);
  final minutes = duration.inMinutes;
  final remainingSeconds = duration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  return '$minutes:$remainingSeconds';
}

String formatElapsed(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}:$seconds';
  }
  return '${duration.inSeconds} sn';
}
