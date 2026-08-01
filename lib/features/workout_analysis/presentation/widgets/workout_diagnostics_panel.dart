import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/workout_diagnostics.dart';
import '../../domain/models/analysis_signal_role.dart';
import '../../domain/models/camera_view_contract.dart';
import '../../domain/models/hold_contract.dart';
import '../../domain/models/hold_feedback_code.dart';
import '../../domain/models/hold_phase.dart';
import '../../domain/models/range_rep_contract.dart';
import '../../infrastructure/services/diagnostics_json_file_exporter.dart';

typedef DiagnosticsJsonFileExporter =
    Future<void> Function({
      required String json,
      required String fileName,
      Rect? sharePositionOrigin,
    });

const String _missingDiagnosticsValue = '\u2014';

class WorkoutDiagnosticsPanel extends StatefulWidget {
  const WorkoutDiagnosticsPanel({
    required this.snapshotReader,
    required this.onReset,
    this.copyText,
    this.exportJsonFile,
    this.refreshInterval = const Duration(milliseconds: 500),
    super.key,
  });

  final WorkoutDiagnosticsSnapshot Function() snapshotReader;
  final VoidCallback onReset;
  final Future<void> Function(String text)? copyText;
  final DiagnosticsJsonFileExporter? exportJsonFile;
  final Duration refreshInterval;

  @override
  State<WorkoutDiagnosticsPanel> createState() =>
      _WorkoutDiagnosticsPanelState();
}

class _WorkoutDiagnosticsPanelState extends State<WorkoutDiagnosticsPanel> {
  Timer? _pollingTimer;
  WorkoutDiagnosticsSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = _tryReadSnapshot();
    _pollingTimer = Timer.periodic(widget.refreshInterval, (_) {
      _refreshSnapshot();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final hasHoldTypedState =
        snapshot?.presentedHoldFeedbackCode != null ||
        snapshot?.engineHoldFeedbackCode != null ||
        snapshot?.holdEnginePhase != null ||
        snapshot?.currentHoldSide != null ||
        snapshot?.lastVisibleHoldPosture != null ||
        snapshot?.holdSignals.isNotEmpty == true ||
        snapshot?.isHoldFormBreakGraceActive != null ||
        snapshot?.isHoldVisibilitySuspended != null;
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Beta Diagnostics',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: snapshot == null
                    ? const Center(
                        child: Text('Diagnostics snapshot okunamad\u0131.'),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          _DiagnosticsSection(
                            title: 'Kimlik',
                            children: [
                              _DiagnosticsRow(
                                label: 'Build mode',
                                value: snapshot.buildMode,
                              ),
                              _DiagnosticsRow(
                                label: 'Commit SHA',
                                value: snapshot.appCommitSha,
                              ),
                              _DiagnosticsRow(
                                label: 'Analysis kind',
                                value: snapshot.analysisKind,
                              ),
                              _DiagnosticsRow(
                                label: 'Exercise',
                                value: snapshot.exerciseType,
                              ),
                              _DiagnosticsRow(
                                label: 'Contract profile',
                                value: snapshot.contractProfile,
                              ),
                              _DiagnosticsRow(
                                label: 'Config',
                                value: snapshot.configAssetPath,
                              ),
                              _DiagnosticsRow(
                                label: 'Schema version',
                                value: snapshot.schemaVersion.toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Elapsed time',
                                value: _formatElapsed(snapshot.elapsedMs),
                              ),
                            ],
                          ),
                          if (snapshot.rangeRepSignalRoles.isNotEmpty ||
                              snapshot.holdSignalRoles.isNotEmpty)
                            _DiagnosticsSection(
                              title: 'Signal roles',
                              children: [
                                ..._buildRangeRepSignalRoleRows(snapshot),
                                ..._buildHoldSignalRoleRows(snapshot),
                              ],
                            ),
                          _DiagnosticsSection(
                            title: 'Frame ak\u0131\u015f\u0131',
                            children: [
                              _DiagnosticsRow(
                                label: 'Camera frames',
                                value: snapshot.cameraFrameCount.toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Analysis attempts',
                                value: snapshot.analysisAttemptCount.toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Analysis completed',
                                value: snapshot.analysisCompletedCount
                                    .toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Throttled frames',
                                value: snapshot.throttledFrameCount.toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Reentrant drops',
                                value: snapshot.reentrantDropCount.toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Converter drops',
                                value: snapshot.converterDropCount.toString(),
                              ),
                            ],
                          ),
                          _DiagnosticsSection(
                            title: 'Pose ve g\u00fcvenilirlik',
                            children: [
                              _DiagnosticsRow(
                                label: 'No-pose frames',
                                value: snapshot.noPoseFrameCount.toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Detected pose frames',
                                value: snapshot.detectedPoseFrameCount
                                    .toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Accepted pose frames',
                                value: snapshot.acceptedPoseFrameCount
                                    .toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Rejected pose frames',
                                value: snapshot.rejectedPoseFrameCount
                                    .toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Low-confidence rejects',
                                value: snapshot.lowConfidencePoseFrameCount
                                    .toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Invalid-geometry rejects',
                                value: snapshot.invalidPoseGeometryFrameCount
                                    .toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Multi-pose frames',
                                value: snapshot.multiPoseFrameCount.toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Max pose count',
                                value: snapshot.maxPoseCount.toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Analysis exceptions',
                                value: snapshot.analysisExceptionCount
                                    .toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Resync count',
                                value: snapshot.resyncCount.toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Pose reacquisition count',
                                value: snapshot.poseReacquisitionCount
                                    .toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Brief occlusion count',
                                value: snapshot.briefOcclusionCount.toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Brief occlusion recovery count',
                                value: snapshot.briefOcclusionRecoveryCount
                                    .toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Brief occlusion abort count',
                                value: snapshot.briefOcclusionAbortCount
                                    .toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Last pose rejection',
                                value: _formatOptionalText(
                                  snapshot.lastPoseRejectionReason,
                                ),
                              ),
                              _DiagnosticsRow(
                                label: 'Pose quality samples',
                                value: snapshot.poseQualitySampleCount
                                    .toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Required likelihood p05',
                                value: _formatDouble(
                                  snapshot.minimumRequiredLikelihoodP05,
                                  suffix: '',
                                ),
                              ),
                              _DiagnosticsRow(
                                label: 'Required likelihood p50',
                                value: _formatDouble(
                                  snapshot.minimumRequiredLikelihoodP50,
                                  suffix: '',
                                ),
                              ),
                              _DiagnosticsRow(
                                label: 'Pose quality status',
                                value: snapshot.currentPoseQualityStatus,
                              ),
                              _DiagnosticsRow(
                                label: 'Visibility status',
                                value: snapshot.currentVisibilityStatus,
                              ),
                              _DiagnosticsRow(
                                label: 'Side switch count',
                                value: snapshot.sideSwitchCount.toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Active-rep side switch count',
                                value: snapshot.activeRepSideSwitchCount
                                    .toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Active-rep resync count',
                                value: snapshot.activeRepResyncCount.toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Range-rep abort count',
                                value: snapshot.rangeRepAbortCount.toString(),
                              ),
                              _DiagnosticsRow(
                                label: 'Current selected side',
                                value: _formatOptionalText(
                                  snapshot.currentSelectedSide,
                                ),
                              ),
                            ],
                          ),
                          _DiagnosticsSection(
                            title: 'Performans',
                            children: [
                              _DiagnosticsRow(
                                label: 'Camera FPS',
                                value: _formatDouble(
                                  snapshot.currentCameraFps,
                                  suffix: ' fps',
                                ),
                              ),
                              _DiagnosticsRow(
                                label: 'Camera lens',
                                value: _formatOptionalText(
                                  snapshot.cameraLensDirection,
                                ),
                              ),
                              _DiagnosticsRow(
                                label: 'Sensor orientation',
                                value: snapshot.sensorOrientationDegrees == null
                                    ? _missingDiagnosticsValue
                                    : '${snapshot.sensorOrientationDegrees}\u00b0',
                              ),
                              _DiagnosticsRow(
                                label: 'Device orientation',
                                value: _formatOptionalText(
                                  snapshot.deviceOrientation,
                                ),
                              ),
                              _DiagnosticsRow(
                                label: 'Analysis FPS',
                                value: _formatDouble(
                                  snapshot.currentAnalysisFps,
                                  suffix: ' fps',
                                ),
                              ),
                              _DiagnosticsRow(
                                label: 'Processing p50',
                                value: _formatMilliseconds(
                                  snapshot.frameProcessingMsP50,
                                ),
                              ),
                              _DiagnosticsRow(
                                label: 'Processing p95',
                                value: _formatMilliseconds(
                                  snapshot.frameProcessingMsP95,
                                ),
                              ),
                              _DiagnosticsRow(
                                label: 'Processing max',
                                value: _formatMilliseconds(
                                  snapshot.frameProcessingMsMax,
                                ),
                              ),
                            ],
                          ),
                          if (snapshot.analysisKind == 'rangeRep')
                            _DiagnosticsSection(
                              title: 'Range-rep timing trace',
                              children: _buildRangeRepTimingTraceRows(snapshot),
                            ),
                          _DiagnosticsSection(
                            title: 'G\u00fcncel egzersiz sonucu',
                            children: [
                              _DiagnosticsRow(
                                label: 'Rep count',
                                value: _formatInt(snapshot.repCount),
                              ),
                              _DiagnosticsRow(
                                label: 'Current hold',
                                value: _formatHoldDuration(
                                  snapshot.currentHoldSeconds,
                                ),
                              ),
                              _DiagnosticsRow(
                                label: 'Best hold',
                                value: _formatHoldDuration(
                                  snapshot.bestHoldSeconds,
                                ),
                              ),
                              _DiagnosticsRow(
                                label: 'Current phase',
                                value: _formatOptionalText(
                                  snapshot.currentPhase,
                                ),
                              ),
                              _DiagnosticsRow(
                                label: 'Is holding',
                                value: _formatBool(snapshot.isHolding),
                              ),
                              _DiagnosticsRow(
                                label: 'Calibration offset',
                                value: _formatDouble(
                                  snapshot.lastCalibrationOffsetDegrees,
                                  suffix: '\u00b0',
                                ),
                              ),
                              if (snapshot.analysisKind == 'rangeRep') ...[
                                _DiagnosticsRow(
                                  label: 'Last validation status',
                                  value: _formatOptionalText(
                                    snapshot.lastRangeRepValidationStatus,
                                  ),
                                ),
                                _DiagnosticsRow(
                                  label: 'Last validation reasons',
                                  value: _formatStringList(
                                    snapshot.lastRangeRepValidationReasons,
                                  ),
                                ),
                                _DiagnosticsRow(
                                  label: 'Tempo diagnostic findings',
                                  value: _formatStringList(
                                    snapshot.lastRangeRepTempoDiagnosticReasons,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (hasHoldTypedState)
                            _DiagnosticsSection(
                              title: 'Hold typed state',
                              children: [
                                _DiagnosticsRow(
                                  label: 'Presented feedback code',
                                  value: _formatHoldFeedbackCode(
                                    snapshot.presentedHoldFeedbackCode,
                                  ),
                                ),
                                _DiagnosticsRow(
                                  label: 'Engine feedback code',
                                  value: _formatHoldFeedbackCode(
                                    snapshot.engineHoldFeedbackCode,
                                  ),
                                ),
                                _DiagnosticsRow(
                                  label: 'Feedback family',
                                  value: _formatHoldFeedbackFamily(
                                    snapshot.presentedHoldFeedbackCode,
                                  ),
                                ),
                                _DiagnosticsRow(
                                  label: 'Engine phase',
                                  value: _formatHoldPhase(
                                    snapshot.holdEnginePhase,
                                  ),
                                ),
                                _DiagnosticsRow(
                                  label: 'Selected hold side',
                                  value: _formatOptionalText(
                                    snapshot.currentHoldSide?.name,
                                  ),
                                ),
                                _DiagnosticsRow(
                                  label: 'Metrics complete',
                                  value: _formatBool(
                                    snapshot
                                        .lastVisibleHoldPosture
                                        ?.hasCompleteMetrics,
                                  ),
                                ),
                                _DiagnosticsRow(
                                  label: 'Active posture',
                                  value: _formatBool(
                                    snapshot
                                        .lastVisibleHoldPosture
                                        ?.hasActivePosture,
                                  ),
                                ),
                                ..._buildHoldSignalRows(snapshot),
                                if (snapshot.hasHoldSignal(
                                  HoldSignal.alignment,
                                ))
                                  _DiagnosticsRow(
                                    label: 'Body aligned',
                                    value: _formatBool(
                                      snapshot.holdSignalValidityFor(
                                        HoldSignal.alignment,
                                      ),
                                    ),
                                  ),
                                if (snapshot.hasHoldSignal(HoldSignal.support))
                                  _DiagnosticsRow(
                                    label: 'Arm supported',
                                    value: _formatBool(
                                      snapshot.holdSignalValidityFor(
                                        HoldSignal.support,
                                      ),
                                    ),
                                  ),
                                if (snapshot.hasHoldSignal(
                                  HoldSignal.extension,
                                ))
                                  _DiagnosticsRow(
                                    label: 'Legs extended',
                                    value: _formatBool(
                                      snapshot.holdSignalValidityFor(
                                        HoldSignal.extension,
                                      ),
                                    ),
                                  ),
                                _DiagnosticsRow(
                                  label: 'Form-break grace active',
                                  value: _formatBool(
                                    snapshot.isHoldFormBreakGraceActive,
                                  ),
                                ),
                                _DiagnosticsRow(
                                  label: 'Visibility suspended',
                                  value: _formatBool(
                                    snapshot.isHoldVisibilitySuspended,
                                  ),
                                ),
                                _DiagnosticsRow(
                                  label: 'Visibility suspend count',
                                  value: snapshot.holdVisibilitySuspendCount
                                      .toString(),
                                ),
                                _DiagnosticsRow(
                                  label: 'Visibility recovery count',
                                  value: snapshot.holdVisibilityRecoveryCount
                                      .toString(),
                                ),
                                _DiagnosticsRow(
                                  label: 'Visibility abort count',
                                  value: snapshot.holdVisibilityAbortCount
                                      .toString(),
                                ),
                                _DiagnosticsRow(
                                  label: 'Visibility suspended total',
                                  value: _formatMilliseconds(
                                    snapshot.holdVisibilitySuspendedMsTotal,
                                  ),
                                ),
                                _DiagnosticsRow(
                                  label: 'Last visibility gap',
                                  value: _formatMilliseconds(
                                    snapshot.lastHoldVisibilityGapMs,
                                  ),
                                ),
                              ],
                            ),
                          if (snapshot.cameraViewContract != null)
                            _DiagnosticsSection(
                              title: 'Camera view',
                              children: _buildCameraViewRows(
                                snapshot.cameraViewContract!,
                              ),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 12,
                  overflowSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _handleCopyJson,
                      child: const Text("JSON'u Kopyala"),
                    ),
                    OutlinedButton(
                      onPressed: _handleExportJsonFile,
                      child: const Text('JSON Dosyasını Paylaş'),
                    ),
                    OutlinedButton(
                      onPressed: _handleReset,
                      child: const Text(
                        'Saya\u00e7lar\u0131 S\u0131f\u0131rla',
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Kapat'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  WorkoutDiagnosticsSnapshot? _tryReadSnapshot() {
    try {
      return widget.snapshotReader();
    } catch (_) {
      return null;
    }
  }

  void _refreshSnapshot() {
    final nextSnapshot = _tryReadSnapshot();
    if (!mounted || nextSnapshot == null) {
      return;
    }
    setState(() => _snapshot = nextSnapshot);
  }

  Future<void> _handleCopyJson() async {
    final snapshot = _tryReadSnapshot();
    if (snapshot == null) {
      return;
    }
    final text = const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
    final copy = widget.copyText ?? _copyWithClipboard;
    try {
      await copy(text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnostics JSON panoya kopyaland\u0131.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diagnostics JSON kopyalanamad\u0131.')),
      );
    }
  }

  Future<void> _copyWithClipboard(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _handleExportJsonFile() async {
    final snapshot = _tryReadSnapshot();
    if (snapshot == null) {
      return;
    }
    final json = const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
    final exporter = widget.exportJsonFile ?? shareDiagnosticsJsonFile;
    final renderBox = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;
    try {
      await exporter(
        json: json,
        fileName: _buildDiagnosticsFileName(snapshot),
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnostics JSON dosyası paylaşılamadı.'),
        ),
      );
    }
  }

  void _handleReset() {
    widget.onReset();
    _refreshSnapshot();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Diagnostics saya\u00e7lar\u0131 s\u0131f\u0131rland\u0131.',
        ),
      ),
    );
  }
}

class _DiagnosticsSection extends StatelessWidget {
  const _DiagnosticsSection({required this.title, required this.children});

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

class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow({required this.label, required this.value});

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

List<Widget> _buildHoldSignalRows(WorkoutDiagnosticsSnapshot snapshot) {
  return <Widget>[
    for (final signal in snapshot.holdSignals)
      _DiagnosticsRow(
        label: signal.name,
        value: _formatHoldSignalDiagnostic(snapshot, signal),
      ),
  ];
}

List<Widget> _buildCameraViewRows(CameraViewContract contract) {
  return <Widget>[
    for (final view in CameraView.values)
      _DiagnosticsRow(
        label: 'Camera ${view.name}',
        value: contract.supportFor(view).name,
      ),
  ];
}

List<Widget> _buildRangeRepTimingTraceRows(
  WorkoutDiagnosticsSnapshot snapshot,
) {
  final trace =
      snapshot.activeRangeRepTimingTrace ??
      snapshot.lastEndedRangeRepTimingTrace;
  if (trace == null) {
    return <Widget>[
      _DiagnosticsRow(label: 'Trace', value: _missingDiagnosticsValue),
      _DiagnosticsRow(
        label: 'Non-monotonic observations',
        value: snapshot.nonMonotonicRangeRepObservationCount.toString(),
      ),
    ];
  }

  final transitionSummary = trace.transitions.isEmpty
      ? _missingDiagnosticsValue
      : trace.transitions
            .map(
              (transition) =>
                  '${transition.type} (+${transition.confirmationLagMs}ms)',
            )
            .join(' > ');

  return <Widget>[
    _DiagnosticsRow(label: 'Outcome', value: trace.outcome.name),
    _DiagnosticsRow(label: 'Samples', value: trace.sampleCount.toString()),
    _DiagnosticsRow(
      label: 'Phase samples',
      value:
          '${trace.towardPeakSampleCount} / '
          '${trace.peakSampleCount} / ${trace.returnSampleCount}',
    ),
    _DiagnosticsRow(
      label: 'Observation interval avg',
      value: _formatDouble(trace.averageObservationIntervalMs, suffix: ' ms'),
    ),
    _DiagnosticsRow(
      label: 'Observation interval max',
      value: _formatMilliseconds(trace.maxObservationIntervalMs),
    ),
    _DiagnosticsRow(
      label: 'Processing lag last',
      value: _formatMilliseconds(trace.lastProcessingLagMs),
    ),
    _DiagnosticsRow(
      label: 'Processing lag max',
      value: _formatMilliseconds(trace.maxProcessingLagMs),
    ),
    _DiagnosticsRow(
      label: 'Direction changes',
      value: trace.directionChangeCount.toString(),
    ),
    _DiagnosticsRow(
      label: 'Visibility gap',
      value: trace.hadVisibilityGap ? 'yes' : 'no',
    ),
    _DiagnosticsRow(
      label: 'Non-monotonic observations',
      value: snapshot.nonMonotonicRangeRepObservationCount.toString(),
    ),
    _DiagnosticsRow(
      label: 'Invalid processing lags',
      value: trace.invalidProcessingLagCount.toString(),
    ),
    _DiagnosticsRow(label: 'Transitions', value: transitionSummary),
  ];
}

List<Widget> _buildRangeRepSignalRoleRows(WorkoutDiagnosticsSnapshot snapshot) {
  return <Widget>[
    for (final signal in RangeRepSignal.values)
      if (snapshot.rangeRepSignalRoles.containsKey(signal))
        _DiagnosticsRow(
          label: '${signal.name} roles',
          value: _formatAnalysisSignalRoles(
            snapshot.rangeRepSignalRoles[signal]!,
          ),
        ),
  ];
}

List<Widget> _buildHoldSignalRoleRows(WorkoutDiagnosticsSnapshot snapshot) {
  return <Widget>[
    for (final signal in HoldSignal.values)
      if (snapshot.holdSignalRoles.containsKey(signal))
        _DiagnosticsRow(
          label: '${signal.name} roles',
          value: _formatAnalysisSignalRoles(snapshot.holdSignalRoles[signal]!),
        ),
  ];
}

String _formatAnalysisSignalRoles(Set<AnalysisSignalRole> roles) {
  return AnalysisSignalRole.values
      .where(roles.contains)
      .map((role) => role.name)
      .join(', ');
}

String _formatHoldSignalDiagnostic(
  WorkoutDiagnosticsSnapshot snapshot,
  HoldSignal signal,
) {
  final currentValue = snapshot.currentHoldSignalValue(signal);
  final targetValue = snapshot.targetHoldSignalValue(signal);
  final validity = snapshot.holdSignalValidityFor(signal);
  final currentLabel = currentValue == null
      ? _missingDiagnosticsValue
      : _formatSignalValue(currentValue);
  final targetLabel = targetValue == null
      ? _missingDiagnosticsValue
      : _formatHoldSignalTarget(signal, targetValue);
  final validityLabel = validity == null
      ? _missingDiagnosticsValue
      : (validity ? 'valid' : 'invalid');

  return '$currentLabel / target $targetLabel / $validityLabel';
}

String _formatSignalValue(double value) => value.toStringAsFixed(1);

String _formatHoldSignalTarget(HoldSignal signal, double value) {
  final formattedValue = _formatSignalValue(value);
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

String _buildDiagnosticsFileName(WorkoutDiagnosticsSnapshot snapshot) {
  final exercise = _sanitizeFileNamePart(snapshot.exerciseType);
  final timestamp = _formatFileTimestamp(snapshot.snapshotCreatedAt);
  return 'diagnostics_v${snapshot.schemaVersion}_${exercise}_$timestamp.json';
}

String _sanitizeFileNamePart(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  );
  final sanitized = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
  return sanitized.isEmpty ? 'unknown_exercise' : sanitized;
}

String _formatFileTimestamp(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}_'
      '${twoDigits(value.hour)}${twoDigits(value.minute)}${twoDigits(value.second)}';
}

String _formatOptionalText(String? value) =>
    value == null || value.isEmpty ? _missingDiagnosticsValue : value;

String _formatStringList(List<String> values) =>
    values.isEmpty ? _missingDiagnosticsValue : values.join(', ');

String _formatHoldFeedbackCode(HoldFeedbackCode? code) =>
    code == null ? _missingDiagnosticsValue : code.code;

String _formatHoldFeedbackFamily(HoldFeedbackCode? code) =>
    code == null ? _missingDiagnosticsValue : code.family.name;

String _formatHoldPhase(HoldPhase? phase) =>
    phase == null ? _missingDiagnosticsValue : phase.code;

String _formatInt(int? value) => value?.toString() ?? _missingDiagnosticsValue;

String _formatMilliseconds(int? value) =>
    value == null ? _missingDiagnosticsValue : '$value ms';

String _formatBool(bool? value) {
  if (value == null) {
    return _missingDiagnosticsValue;
  }
  return value ? 'Evet' : 'Hay\u0131r';
}

String _formatDouble(double? value, {required String suffix}) {
  if (value == null) {
    return _missingDiagnosticsValue;
  }
  return '${value.toStringAsFixed(1)}$suffix';
}

String _formatHoldDuration(int? seconds) {
  if (seconds == null) {
    return _missingDiagnosticsValue;
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

String _formatElapsed(int milliseconds) {
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
