import 'package:flutter/material.dart';

import '../../application/workout_diagnostics.dart';
import '../../domain/models/hold_contract.dart';
import 'workout_diagnostics_components.dart';

class WorkoutDiagnosticsSnapshotView extends StatelessWidget {
  const WorkoutDiagnosticsSnapshotView({super.key, required this.snapshot});

  final WorkoutDiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final hasHoldTypedState =
        snapshot.presentedHoldFeedbackCode != null ||
        snapshot.engineHoldFeedbackCode != null ||
        snapshot.holdEnginePhase != null ||
        snapshot.currentHoldSide != null ||
        snapshot.lastVisibleHoldPosture != null ||
        snapshot.holdSignals.isNotEmpty ||
        snapshot.isHoldFormBreakGraceActive != null ||
        snapshot.isHoldVisibilitySuspended != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        DiagnosticsSection(
          title: 'Kimlik',
          children: [
            DiagnosticsRow(label: 'Build mode', value: snapshot.buildMode),
            DiagnosticsRow(label: 'Commit SHA', value: snapshot.appCommitSha),
            DiagnosticsRow(
              label: 'Analysis kind',
              value: snapshot.analysisKind,
            ),
            DiagnosticsRow(label: 'Exercise', value: snapshot.exerciseType),
            DiagnosticsRow(
              label: 'Contract profile',
              value: snapshot.contractProfile,
            ),
            DiagnosticsRow(label: 'Config', value: snapshot.configAssetPath),
            DiagnosticsRow(
              label: 'Schema version',
              value: snapshot.schemaVersion.toString(),
            ),
            DiagnosticsRow(
              label: 'Elapsed time',
              value: formatElapsed(snapshot.elapsedMs),
            ),
          ],
        ),
        if (snapshot.rangeRepSignalRoles.isNotEmpty ||
            snapshot.holdSignalRoles.isNotEmpty)
          DiagnosticsSection(
            title: 'Signal roles',
            children: [
              ...buildRangeRepSignalRoleRows(snapshot),
              ...buildHoldSignalRoleRows(snapshot),
            ],
          ),
        DiagnosticsSection(
          title: 'Frame ak\u0131\u015f\u0131',
          children: [
            DiagnosticsRow(
              label: 'Camera frames',
              value: snapshot.cameraFrameCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Analysis attempts',
              value: snapshot.analysisAttemptCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Analysis completed',
              value: snapshot.analysisCompletedCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Throttled frames',
              value: snapshot.throttledFrameCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Reentrant drops',
              value: snapshot.reentrantDropCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Converter drops',
              value: snapshot.converterDropCount.toString(),
            ),
          ],
        ),
        DiagnosticsSection(
          title: 'Pose ve g\u00fcvenilirlik',
          children: [
            DiagnosticsRow(
              label: 'No-pose frames',
              value: snapshot.noPoseFrameCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Detected pose frames',
              value: snapshot.detectedPoseFrameCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Accepted pose frames',
              value: snapshot.acceptedPoseFrameCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Rejected pose frames',
              value: snapshot.rejectedPoseFrameCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Low-confidence rejects',
              value: snapshot.lowConfidencePoseFrameCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Invalid-geometry rejects',
              value: snapshot.invalidPoseGeometryFrameCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Multi-pose frames',
              value: snapshot.multiPoseFrameCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Max pose count',
              value: snapshot.maxPoseCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Analysis exceptions',
              value: snapshot.analysisExceptionCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Pose detection timeouts',
              value: snapshot.analysisTimeoutCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Resync count',
              value: snapshot.resyncCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Pose reacquisition count',
              value: snapshot.poseReacquisitionCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Brief occlusion count',
              value: snapshot.briefOcclusionCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Brief occlusion recovery count',
              value: snapshot.briefOcclusionRecoveryCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Brief occlusion abort count',
              value: snapshot.briefOcclusionAbortCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Last pose rejection',
              value: formatOptionalText(snapshot.lastPoseRejectionReason),
            ),
            DiagnosticsRow(
              label: 'Pose quality samples',
              value: snapshot.poseQualitySampleCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Required likelihood p05',
              value: formatDouble(
                snapshot.minimumRequiredLikelihoodP05,
                suffix: '',
              ),
            ),
            DiagnosticsRow(
              label: 'Required likelihood p50',
              value: formatDouble(
                snapshot.minimumRequiredLikelihoodP50,
                suffix: '',
              ),
            ),
            DiagnosticsRow(
              label: 'Pose quality status',
              value: snapshot.currentPoseQualityStatus,
            ),
            DiagnosticsRow(
              label: 'Visibility status',
              value: snapshot.currentVisibilityStatus,
            ),
            DiagnosticsRow(
              label: 'Side switch count',
              value: snapshot.sideSwitchCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Active-rep side switch count',
              value: snapshot.activeRepSideSwitchCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Active-rep resync count',
              value: snapshot.activeRepResyncCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Range-rep abort count',
              value: snapshot.rangeRepAbortCount.toString(),
            ),
            DiagnosticsRow(
              label: 'Current selected side',
              value: formatOptionalText(snapshot.currentSelectedSide),
            ),
            if (snapshot.analysisKind == 'rangeRep') ...[
              DiagnosticsRow(
                label: 'Current left confidence',
                value: formatMeasurementConfidence(
                  snapshot.currentLeftMeasurementConfidence,
                ),
              ),
              DiagnosticsRow(
                label: 'Current right confidence',
                value: formatMeasurementConfidence(
                  snapshot.currentRightMeasurementConfidence,
                ),
              ),
              DiagnosticsRow(
                label: 'Last rep confidence',
                value: formatMeasurementConfidence(
                  snapshot.lastRepMeasurementConfidence,
                ),
              ),
              DiagnosticsRow(
                label: 'Known confidence reps',
                value: snapshot.measurementConfidenceKnownRepCount.toString(),
              ),
              DiagnosticsRow(
                label: 'Unknown confidence reps',
                value: snapshot.measurementConfidenceUnknownRepCount.toString(),
              ),
              DiagnosticsRow(
                label: 'Confidence issues',
                value: formatCountMap(
                  snapshot.measurementConfidenceIssueCounts,
                ),
              ),
            ],
          ],
        ),
        DiagnosticsSection(
          title: 'Performans',
          children: [
            DiagnosticsRow(
              label: 'Camera FPS',
              value: formatDouble(snapshot.currentCameraFps, suffix: ' fps'),
            ),
            DiagnosticsRow(
              label: 'Camera lens',
              value: formatOptionalText(snapshot.cameraLensDirection),
            ),
            DiagnosticsRow(
              label: 'Sensor orientation',
              value: snapshot.sensorOrientationDegrees == null
                  ? missingDiagnosticsValue
                  : '${snapshot.sensorOrientationDegrees}\u00b0',
            ),
            DiagnosticsRow(
              label: 'Device orientation',
              value: formatOptionalText(snapshot.deviceOrientation),
            ),
            DiagnosticsRow(
              label: 'Analysis FPS',
              value: formatDouble(snapshot.currentAnalysisFps, suffix: ' fps'),
            ),
            DiagnosticsRow(
              label: 'Processing p50',
              value: formatMilliseconds(snapshot.frameProcessingMsP50),
            ),
            DiagnosticsRow(
              label: 'Processing p95',
              value: formatMilliseconds(snapshot.frameProcessingMsP95),
            ),
            DiagnosticsRow(
              label: 'Processing max',
              value: formatMilliseconds(snapshot.frameProcessingMsMax),
            ),
          ],
        ),
        if (snapshot.analysisKind == 'rangeRep')
          DiagnosticsSection(
            title: 'Range-rep timing trace',
            children: buildRangeRepTimingTraceRows(snapshot),
          ),
        DiagnosticsSection(
          title: 'G\u00fcncel egzersiz sonucu',
          children: [
            DiagnosticsRow(
              label: 'Rep count',
              value: formatInt(snapshot.repCount),
            ),
            DiagnosticsRow(
              label: 'Current hold',
              value: formatHoldDuration(snapshot.currentHoldSeconds),
            ),
            DiagnosticsRow(
              label: 'Best hold',
              value: formatHoldDuration(snapshot.bestHoldSeconds),
            ),
            DiagnosticsRow(
              label: 'Current phase',
              value: formatOptionalText(snapshot.currentPhase),
            ),
            DiagnosticsRow(
              label: 'Is holding',
              value: formatBool(snapshot.isHolding),
            ),
            DiagnosticsRow(
              label: 'Calibration offset',
              value: formatDouble(
                snapshot.lastCalibrationOffsetDegrees,
                suffix: '\u00b0',
              ),
            ),
            if (snapshot.analysisKind == 'rangeRep') ...[
              DiagnosticsRow(
                label: 'Last validation status',
                value: formatOptionalText(
                  snapshot.lastRangeRepValidationStatus,
                ),
              ),
              DiagnosticsRow(
                label: 'Last validation reasons',
                value: formatStringList(snapshot.lastRangeRepValidationReasons),
              ),
              DiagnosticsRow(
                label: 'Tempo diagnostic findings',
                value: formatStringList(
                  snapshot.lastRangeRepTempoDiagnosticReasons,
                ),
              ),
            ],
          ],
        ),
        if (hasHoldTypedState)
          DiagnosticsSection(
            title: 'Hold typed state',
            children: [
              DiagnosticsRow(
                label: 'Presented feedback code',
                value: formatHoldFeedbackCode(
                  snapshot.presentedHoldFeedbackCode,
                ),
              ),
              DiagnosticsRow(
                label: 'Engine feedback code',
                value: formatHoldFeedbackCode(snapshot.engineHoldFeedbackCode),
              ),
              DiagnosticsRow(
                label: 'Feedback family',
                value: formatHoldFeedbackFamily(
                  snapshot.presentedHoldFeedbackCode,
                ),
              ),
              DiagnosticsRow(
                label: 'Engine phase',
                value: formatHoldPhase(snapshot.holdEnginePhase),
              ),
              DiagnosticsRow(
                label: 'Selected hold side',
                value: formatOptionalText(snapshot.currentHoldSide?.name),
              ),
              DiagnosticsRow(
                label: 'Metrics complete',
                value: formatBool(
                  snapshot.lastVisibleHoldPosture?.hasCompleteMetrics,
                ),
              ),
              DiagnosticsRow(
                label: 'Active posture',
                value: formatBool(
                  snapshot.lastVisibleHoldPosture?.hasActivePosture,
                ),
              ),
              ...buildHoldSignalRows(snapshot),
              if (snapshot.hasHoldSignal(HoldSignal.alignment))
                DiagnosticsRow(
                  label: 'Body aligned',
                  value: formatBool(
                    snapshot.holdSignalValidityFor(HoldSignal.alignment),
                  ),
                ),
              if (snapshot.hasHoldSignal(HoldSignal.support))
                DiagnosticsRow(
                  label: 'Arm supported',
                  value: formatBool(
                    snapshot.holdSignalValidityFor(HoldSignal.support),
                  ),
                ),
              if (snapshot.hasHoldSignal(HoldSignal.extension))
                DiagnosticsRow(
                  label: 'Legs extended',
                  value: formatBool(
                    snapshot.holdSignalValidityFor(HoldSignal.extension),
                  ),
                ),
              DiagnosticsRow(
                label: 'Form-break grace active',
                value: formatBool(snapshot.isHoldFormBreakGraceActive),
              ),
              DiagnosticsRow(
                label: 'Visibility suspended',
                value: formatBool(snapshot.isHoldVisibilitySuspended),
              ),
              DiagnosticsRow(
                label: 'Visibility suspend count',
                value: snapshot.holdVisibilitySuspendCount.toString(),
              ),
              DiagnosticsRow(
                label: 'Visibility recovery count',
                value: snapshot.holdVisibilityRecoveryCount.toString(),
              ),
              DiagnosticsRow(
                label: 'Visibility abort count',
                value: snapshot.holdVisibilityAbortCount.toString(),
              ),
              DiagnosticsRow(
                label: 'Visibility suspended total',
                value: formatMilliseconds(
                  snapshot.holdVisibilitySuspendedMsTotal,
                ),
              ),
              DiagnosticsRow(
                label: 'Last visibility gap',
                value: formatMilliseconds(snapshot.lastHoldVisibilityGapMs),
              ),
            ],
          ),
        if (snapshot.cameraViewContract != null)
          DiagnosticsSection(
            title: 'Camera view',
            children: buildCameraViewRows(snapshot.cameraViewContract!),
          ),
      ],
    );
  }
}
