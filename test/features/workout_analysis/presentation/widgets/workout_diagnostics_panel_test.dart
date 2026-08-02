import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_signal_role.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/camera_view_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_validity.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/measurement_confidence_breakdown.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/tempo_measurement_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_timing_trace.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/tempo_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/workout_diagnostics_panel.dart';

const String _missingValue = '\u2014';
const String _resetButtonText = 'Saya\u00e7lar\u0131 S\u0131f\u0131rla';
const String _copySuccessText = 'Diagnostics JSON panoya kopyaland\u0131.';
const String _exportButtonText = 'JSON Dosyasını Paylaş';
const String _exportFailureText = 'Diagnostics JSON dosyası paylaşılamadı.';
const String _resetSuccessText =
    'Diagnostics saya\u00e7lar\u0131 s\u0131f\u0131rland\u0131.';

final CameraViewContract _sideViewContract = CameraViewContract(
  views: const <CameraView, CameraViewSupport>{
    CameraView.side: CameraViewSupport.preferred,
    CameraView.front: CameraViewSupport.unsupported,
  },
);

final CameraViewContract _frontViewContract = CameraViewContract(
  views: const <CameraView, CameraViewSupport>{
    CameraView.side: CameraViewSupport.unsupported,
    CameraView.front: CameraViewSupport.preferred,
  },
);

void main() {
  testWidgets('temel snapshot alanlarini gosterir', (tester) async {
    await _pumpPanel(
      tester,
      snapshotReader: () => _snapshot(elapsedMs: 5000, appCommitSha: 'abc123'),
      onReset: () {},
    );

    expect(find.text('Build mode'), findsOneWidget);
    expect(find.text('debug'), findsOneWidget);
    expect(find.text('Commit SHA'), findsOneWidget);
    expect(find.text('abc123'), findsOneWidget);
    expect(find.text('Analysis kind'), findsOneWidget);
    expect(find.text('rangeRep'), findsOneWidget);
    expect(find.text('Exercise'), findsOneWidget);
    expect(find.text('squat'), findsOneWidget);
    expect(find.text('Contract profile'), findsOneWidget);
    expect(find.text('rangeRep:squat'), findsOneWidget);
    expect(find.text('Schema version'), findsOneWidget);
    expect(find.text('Elapsed time'), findsOneWidget);
    expect(find.text('5 sn'), findsOneWidget);
  });

  testWidgets('active range-rep signal roles render in canonical order', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      snapshotReader: () =>
          _snapshot(rangeRepSignalRoles: RangeRepContracts.sitUp.signalRoles),
      onReset: () {},
    );

    await tester.scrollUntilVisible(
      find.text('Signal roles'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Signal roles'), findsOneWidget);
    expect(find.text('primaryMetric roles'), findsOneWidget);
    expect(find.text('detection, validation, scoring'), findsOneWidget);
    expect(find.text('formMetric roles'), findsOneWidget);
    expect(find.text('postureAngle roles'), findsOneWidget);
    expect(find.text('setup'), findsNWidgets(2));
    expect(find.text('validation, technique, scoring'), findsNothing);
    expect(find.text('alignment roles'), findsNothing);
  });

  testWidgets('range-rep timing trace renders observation diagnostics', (
    tester,
  ) async {
    final base = DateTime.utc(2030, 1, 1, 0, 0, 0);
    final trace = RangeRepTimingTraceSnapshot(
      outcome: RangeRepTimingTraceOutcome.completed,
      sampleCount: 7,
      towardPeakSampleCount: 3,
      peakSampleCount: 1,
      returnSampleCount: 3,
      directionChangeCount: 2,
      averageObservationIntervalMs: 103.3,
      maxObservationIntervalMs: 120,
      lastProcessingLagMs: 340,
      maxProcessingLagMs: 680,
      hadVisibilityGap: true,
      transitions: <RangeRepTimingTransitionTrace>[
        RangeRepTimingTransitionTrace(
          type: 'startTowardPeak',
          effectiveAt: base,
          confirmedAt: base.add(const Duration(milliseconds: 100)),
        ),
      ],
    );
    await _pumpPanel(
      tester,
      snapshotReader: () => _snapshot(
        lastEndedTimingTrace: trace,
        lastTempoMeasurementAssessment: TempoMeasurementAssessment(
          status: TempoMeasurementStatus.unavailable,
          issues: const <TempoMeasurementIssue>[
            TempoMeasurementIssue.visibilityInterrupted,
          ],
          measuredTempo: const TempoRepResult(
            repIndex: 1,
            eccentricDuration: Duration(milliseconds: 300),
            bottomPauseDuration: Duration(milliseconds: 100),
            concentricDuration: Duration(milliseconds: 400),
            topPauseDuration: Duration.zero,
            totalRepDuration: Duration(milliseconds: 800),
            towardPeakDuration: Duration(milliseconds: 300),
            returnDuration: Duration(milliseconds: 400),
          ),
          trace: trace,
        ),
        nonMonotonicObservationCount: 2,
      ),
      onReset: () {},
    );

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Range-rep timing trace'),
      300,
      scrollable: scrollable,
    );

    expect(find.text('Range-rep timing trace'), findsOneWidget);
    expect(find.text('completed'), findsOneWidget);
    expect(find.text('3 / 1 / 3'), findsOneWidget);
    expect(find.text('103.3 ms'), findsOneWidget);
    expect(find.text('680 ms'), findsOneWidget);
    expect(find.text('Sparse recovery'), findsOneWidget);
    expect(find.text('Tempo measurement status'), findsOneWidget);
    expect(find.text('unavailable'), findsOneWidget);
    expect(find.text('visibilityInterrupted'), findsOneWidget);
    expect(find.text('startTowardPeak (+100ms)'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('tempo quarantine findings render separately from validation', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      snapshotReader: () => _snapshot(
        lastRangeRepValidationStatus: 'valid',
        lastRangeRepValidationReasons: const <String>[],
        lastRangeRepTempoDiagnosticReasons: const <String>[
          'excessiveAscentSpeed',
        ],
      ),
      onReset: () {},
    );

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Tempo diagnostic findings'),
      300,
      scrollable: scrollable,
    );

    expect(find.text('Last validation status'), findsOneWidget);
    expect(find.text('Last validation reasons'), findsOneWidget);
    expect(find.text('Tempo diagnostic findings'), findsOneWidget);
    expect(find.text('excessiveAscentSpeed'), findsOneWidget);
  });

  testWidgets('active camera-view contract renders in canonical order', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      snapshotReader: () => _snapshot(cameraViewContract: _frontViewContract),
      onReset: () {},
    );
    await tester.scrollUntilVisible(
      find.text('Camera view'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Camera view'), findsOneWidget);
    expect(find.text('Camera side'), findsOneWidget);
    expect(find.text('unsupported'), findsOneWidget);
    expect(find.text('Camera front'), findsOneWidget);
    expect(find.text('preferred'), findsOneWidget);
  });

  testWidgets('active hold roles render without range-rep leakage', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      snapshotReader: () => _snapshot(
        analysisKind: 'hold',
        holdSignalRoles: HoldContracts.plankFamily.signalRoles,
      ),
      onReset: () {},
    );

    await tester.scrollUntilVisible(
      find.text('Signal roles'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('alignment roles'), findsOneWidget);
    expect(find.text('support roles'), findsOneWidget);
    expect(find.text('extension roles'), findsOneWidget);
    expect(find.text('detection, validation'), findsNWidgets(3));
    expect(find.text('primaryMetric roles'), findsNothing);
  });

  testWidgets('hold typed state alanlarini gosterir', (tester) async {
    await _pumpPanel(
      tester,
      snapshotReader: () => _snapshot(
        analysisKind: 'hold',
        presentedHoldFeedbackCode: HoldFeedbackCode.bodyNotVisible,
        engineHoldFeedbackCode: HoldFeedbackCode.holdPosition,
        holdEnginePhase: HoldPhase.holding,
        currentHoldSide: HoldSide.right,
        lastVisibleHoldPosture: HoldPostureDiagnosticsSnapshot(
          hasCompleteMetrics: true,
          hasActivePosture: true,
          signalValidity: HoldSignalValidity(
            values: <HoldSignal, bool>{
              HoldSignal.alignment: true,
              HoldSignal.support: false,
              HoldSignal.extension: true,
            },
          ),
        ),
        currentSignalValues: HoldSignalValues(
          values: <HoldSignal, double>{
            HoldSignal.alignment: 168.0,
            HoldSignal.support: 90.0,
            HoldSignal.extension: 170.0,
          },
        ),
        signalValidity: HoldSignalValidity(
          values: <HoldSignal, bool>{
            HoldSignal.alignment: true,
            HoldSignal.support: false,
            HoldSignal.extension: true,
          },
        ),
        isHoldFormBreakGraceActive: true,
        isHoldVisibilitySuspended: false,
        holdVisibilitySuspendCount: 2,
        holdVisibilityRecoveryCount: 1,
        holdVisibilityAbortCount: 1,
        holdVisibilitySuspendedMsTotal: 1700,
        lastHoldVisibilityGapMs: 1200,
      ),
      onReset: () {},
    );

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Hold typed state'),
      300,
      scrollable: scrollable,
    );

    expect(find.text('Hold typed state'), findsOneWidget);
    expect(find.text('Presented feedback code'), findsOneWidget);
    expect(find.text('body_not_visible'), findsOneWidget);
    expect(find.text('Engine feedback code'), findsOneWidget);
    expect(find.text('hold_position'), findsOneWidget);
    expect(find.text('Feedback family'), findsOneWidget);
    expect(find.text('systemState'), findsOneWidget);
    expect(find.text('Engine phase'), findsOneWidget);
    expect(find.text('holding'), findsOneWidget);
    expect(find.text('Selected hold side'), findsOneWidget);
    expect(find.text('right'), findsOneWidget);
    expect(find.text('Metrics complete'), findsOneWidget);
    expect(find.text('Active posture'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('alignment'),
      200,
      scrollable: scrollable,
    );
    expect(find.text('alignment'), findsOneWidget);
    expect(find.text('support'), findsOneWidget);
    expect(find.text('extension'), findsOneWidget);
    expect(find.text('Body aligned'), findsOneWidget);
    expect(find.text('Arm supported'), findsOneWidget);
    expect(find.text('Legs extended'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Visibility suspended'),
      200,
      scrollable: scrollable,
    );
    expect(find.text('Form-break grace active'), findsOneWidget);
    expect(find.text('Visibility suspended'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Visibility suspend count'),
      200,
      scrollable: scrollable,
    );
    expect(find.text('Visibility suspend count'), findsOneWidget);
    expect(find.text('Visibility recovery count'), findsOneWidget);
    expect(find.text('Visibility abort count'), findsOneWidget);
    expect(find.text('Visibility suspended total'), findsOneWidget);
    expect(find.text('Last visibility gap'), findsOneWidget);
    expect(find.text('1700 ms'), findsOneWidget);
    expect(find.text('1200 ms'), findsOneWidget);
  });

  testWidgets(
    'hollow hold typed state shows generic signals and hides plank compatibility rows',
    (tester) async {
      await _pumpPanel(
        tester,
        snapshotReader: () => _snapshot(
          analysisKind: 'hold',
          presentedHoldFeedbackCode: HoldFeedbackCode.holdPosition,
          engineHoldFeedbackCode: HoldFeedbackCode.holdPosition,
          holdEnginePhase: HoldPhase.holding,
          currentHoldSide: HoldSide.left,
          lastVisibleHoldPosture: HoldPostureDiagnosticsSnapshot(
            hasCompleteMetrics: true,
            hasActivePosture: true,
            signalValidity: HoldSignalValidity(
              values: <HoldSignal, bool>{
                HoldSignal.compression: true,
                HoldSignal.armExtension: true,
                HoldSignal.kneeExtension: true,
              },
            ),
          ),
          currentSignalValues: HoldSignalValues(
            values: <HoldSignal, double>{
              HoldSignal.compression: 164.3,
              HoldSignal.armExtension: 136.3,
              HoldSignal.kneeExtension: 173.0,
            },
          ),
          targetSignalValues: HoldSignalValues(
            values: <HoldSignal, double>{
              HoldSignal.compression: 169.0,
              HoldSignal.armExtension: 135.0,
              HoldSignal.kneeExtension: 165.0,
            },
          ),
          signalValidity: HoldSignalValidity(
            values: <HoldSignal, bool>{
              HoldSignal.compression: true,
              HoldSignal.armExtension: true,
              HoldSignal.kneeExtension: true,
            },
          ),
          isHoldFormBreakGraceActive: false,
          isHoldVisibilitySuspended: false,
        ),
        onReset: () {},
      );

      await tester.scrollUntilVisible(
        find.text('compression'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('compression'), findsOneWidget);
      expect(find.text('armExtension'), findsOneWidget);
      expect(find.text('kneeExtension'), findsOneWidget);
      expect(find.text('Body aligned'), findsNothing);
      expect(find.text('Arm supported'), findsNothing);
      expect(find.text('Legs extended'), findsNothing);
    },
  );

  testWidgets(
    'nullable degerleri yer tutucu olarak gosterir ve unknown commit SHA görünür kalir',
    (tester) async {
      await _pumpPanel(
        tester,
        snapshotReader: () => _snapshot(
          appCommitSha: 'unknown',
          currentSelectedSide: null,
          lastCalibrationOffsetDegrees: null,
          currentCameraFps: null,
          currentAnalysisFps: null,
          frameProcessingMsP50: null,
          frameProcessingMsP95: null,
          frameProcessingMsMax: null,
          repCount: null,
          currentHoldSeconds: null,
          bestHoldSeconds: null,
          currentPhase: null,
          isHolding: null,
          presentedHoldFeedbackCode: null,
          engineHoldFeedbackCode: null,
          holdEnginePhase: null,
          currentHoldSide: null,
          lastVisibleHoldPosture: null,
          isHoldFormBreakGraceActive: null,
          isHoldVisibilitySuspended: null,
        ),
        onReset: () {},
      );

      expect(find.text('Commit SHA'), findsOneWidget);
      expect(find.text('unknown'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(find.text(_missingValue), findsWidgets);
    },
  );

  testWidgets(
    'refresh interval sonrasinda yeni snapshot degerlerini gosterir',
    (tester) async {
      var activeSnapshot = _snapshot(analysisKind: 'rangeRep');
      await _pumpPanel(
        tester,
        snapshotReader: () => activeSnapshot,
        onReset: () {},
      );

      expect(find.text('rangeRep'), findsOneWidget);
      activeSnapshot = _snapshot(analysisKind: 'hold');

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('hold'), findsOneWidget);
    },
  );

  testWidgets('confidence v2 rows render known and null values safely', (
    tester,
  ) async {
    final known = MeasurementConfidenceBreakdown(
      landmarkLikelihood: 0.9,
      signalAvailability: 0.8,
      geometryPlausibility: 1.0,
      temporalContinuity: 0.7,
      combined: 0.84,
      issues: const <MeasurementConfidenceIssue>[
        MeasurementConfidenceIssue.temporalDiscontinuity,
      ],
    );
    await _pumpPanel(
      tester,
      snapshotReader: () => _snapshot(
        currentLeftMeasurementConfidence: known,
        currentRightMeasurementConfidence: null,
        lastRepMeasurementConfidence: known,
        measurementConfidenceKnownRepCount: 1,
        measurementConfidenceUnknownRepCount: 1,
        measurementConfidenceIssueCounts: const <String, int>{
          'temporal_discontinuity': 1,
        },
      ),
      onReset: () {},
    );

    await tester.scrollUntilVisible(
      find.text('Current left confidence'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Current left confidence'), findsOneWidget);
    expect(find.text('Current right confidence'), findsOneWidget);
    expect(find.text('Last rep confidence'), findsOneWidget);
    expect(find.textContaining('combined=0.840'), findsWidgets);
    expect(find.text('temporal_discontinuity=1'), findsOneWidget);
    expect(find.text(_missingValue), findsWidgets);
  });

  testWidgets('JSON kopyalama callbackine gecerli JSON gonderir', (
    tester,
  ) async {
    String? copiedText;
    await _pumpPanel(
      tester,
      snapshotReader: () => _snapshot(),
      onReset: () {},
      copyText: (text) async {
        copiedText = text;
      },
    );

    await tester.tap(find.text("JSON'u Kopyala"));
    await tester.pump();

    final decoded = jsonDecode(copiedText!) as Map<String, dynamic>;
    expect(decoded['analysis_kind'], 'rangeRep');
    expect(decoded['schema_version'], 10);
    expect(decoded.containsKey('presented_hold_feedback_code'), isTrue);
    expect(find.text(_copySuccessText), findsOneWidget);
  });

  testWidgets('JSON icerigi snapshot.toJson ile ayni veriyi tasir', (
    tester,
  ) async {
    var activeSnapshot = _snapshot(repCount: 1);
    String? copiedText;
    await _pumpPanel(
      tester,
      snapshotReader: () => activeSnapshot,
      onReset: () {},
      copyText: (text) async {
        copiedText = text;
      },
    );

    activeSnapshot = _snapshot(repCount: 7, currentPhase: 'HOLDING');

    await tester.tap(find.text("JSON'u Kopyala"));
    await tester.pump();

    final actual = jsonDecode(copiedText!) as Map<String, dynamic>;
    final expected =
        jsonDecode(jsonEncode(activeSnapshot.toJson())) as Map<String, dynamic>;
    expect(actual, expected);
  });

  testWidgets(
    'JSON dosya export callbackine gecerli JSON ve dosya adi gonderir',
    (tester) async {
      String? exportedJson;
      String? exportedFileName;
      Rect? exportedShareOrigin;
      final snapshot = _snapshot();
      await _pumpPanel(
        tester,
        snapshotReader: () => snapshot,
        onReset: () {},
        exportJsonFile:
            ({required json, required fileName, sharePositionOrigin}) async {
              exportedJson = json;
              exportedFileName = fileName;
              exportedShareOrigin = sharePositionOrigin;
            },
      );

      await tester.tap(find.text(_exportButtonText));
      await tester.pump();

      final actual = jsonDecode(exportedJson!) as Map<String, dynamic>;
      final expected =
          jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>;
      expect(actual, expected);
      expect(exportedFileName, 'diagnostics_v10_squat_20300101_000004.json');
      expect(exportedShareOrigin, isNotNull);
    },
  );

  testWidgets('JSON dosya export hatasi kullaniciya bildirilir', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      snapshotReader: () => _snapshot(),
      onReset: () {},
      exportJsonFile:
          ({required json, required fileName, sharePositionOrigin}) async {
            throw StateError('share failed');
          },
    );

    await tester.tap(find.text(_exportButtonText));
    await tester.pump();

    expect(find.text(_exportFailureText), findsOneWidget);
  });

  testWidgets('reset callbacki tam bir kez cagrilir', (tester) async {
    var resetCount = 0;
    await _pumpPanel(
      tester,
      snapshotReader: () => _snapshot(),
      onReset: () {
        resetCount += 1;
      },
    );

    await tester.tap(find.text(_resetButtonText));
    await tester.pump();

    expect(resetCount, 1);
  });

  testWidgets('reset sonrasinda snapshot yeniden okunur', (tester) async {
    var activeSnapshot = _snapshot(analysisKind: 'rangeRep');
    await _pumpPanel(
      tester,
      snapshotReader: () => activeSnapshot,
      onReset: () {
        activeSnapshot = _snapshot(analysisKind: 'hold');
      },
    );

    expect(find.text('rangeRep'), findsOneWidget);

    await tester.tap(find.text(_resetButtonText));
    await tester.pump();

    expect(find.text('hold'), findsOneWidget);
    expect(find.text(_resetSuccessText), findsOneWidget);
  });

  testWidgets('dispose sonrasinda polling durur', (tester) async {
    var readCount = 0;
    await _pumpPanel(
      tester,
      snapshotReader: () {
        readCount += 1;
        return _snapshot();
      },
      onReset: () {},
    );

    expect(readCount, 1);

    await tester.pump(const Duration(milliseconds: 500));
    expect(readCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final countAfterDispose = readCount;
    await tester.pump(const Duration(seconds: 2));
    expect(readCount, countAfterDispose);
  });

  testWidgets('kapat butonu navigator uzerinden paneli kapatir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => WorkoutDiagnosticsPanel(
                        snapshotReader: () => _snapshot(),
                        onReset: () {},
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Beta Diagnostics'), findsOneWidget);

    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    expect(find.text('Beta Diagnostics'), findsNothing);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required WorkoutDiagnosticsSnapshot Function() snapshotReader,
  required VoidCallback onReset,
  Future<void> Function(String text)? copyText,
  DiagnosticsJsonFileExporter? exportJsonFile,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorkoutDiagnosticsPanel(
          snapshotReader: snapshotReader,
          onReset: onReset,
          copyText: copyText,
          exportJsonFile: exportJsonFile,
        ),
      ),
    ),
  );
}

WorkoutDiagnosticsSnapshot _snapshot({
  int schemaVersion = 10,
  String appCommitSha = 'commit-123',
  String buildMode = 'debug',
  String analysisKind = 'rangeRep',
  int elapsedMs = 4200,
  int cameraFrameCount = 14,
  int analysisAttemptCount = 12,
  int analysisCompletedCount = 11,
  int throttledFrameCount = 2,
  int reentrantDropCount = 1,
  int converterDropCount = 0,
  int noPoseFrameCount = 3,
  int multiPoseFrameCount = 1,
  int maxPoseCount = 2,
  int analysisExceptionCount = 0,
  int resyncCount = 1,
  int sideSwitchCount = 2,
  int activeRepSideSwitchCount = 1,
  String? currentSelectedSide = 'left',
  double? lastCalibrationOffsetDegrees = 1.2,
  double? currentCameraFps = 29.9,
  double? currentAnalysisFps = 9.8,
  int fpsSampleCount = 3,
  double? cameraFpsP50 = 29.5,
  double? cameraFpsP95 = 30.0,
  double? analysisFpsP50 = 8.0,
  double? analysisFpsP95 = 9.8,
  int? frameProcessingMsP50 = 105,
  int? frameProcessingMsP95 = 145,
  int? frameProcessingMsMax = 190,
  int? repCount = 4,
  int? currentHoldSeconds = 12,
  int? bestHoldSeconds = 34,
  String? currentPhase = 'ASCENDING',
  bool? isHolding = false,
  HoldFeedbackCode? presentedHoldFeedbackCode,
  HoldFeedbackCode? engineHoldFeedbackCode,
  HoldPhase? holdEnginePhase,
  HoldSide? currentHoldSide,
  HoldPostureDiagnosticsSnapshot? lastVisibleHoldPosture,
  HoldSignalValues? currentSignalValues,
  HoldSignalValues? targetSignalValues,
  HoldSignalValidity? signalValidity,
  bool? isHoldFormBreakGraceActive,
  bool? isHoldVisibilitySuspended,
  int holdVisibilitySuspendCount = 0,
  int holdVisibilityRecoveryCount = 0,
  int holdVisibilityAbortCount = 0,
  int holdVisibilitySuspendedMsTotal = 0,
  int? lastHoldVisibilityGapMs,
  Map<RangeRepSignal, Set<AnalysisSignalRole>> rangeRepSignalRoles =
      const <RangeRepSignal, Set<AnalysisSignalRole>>{},
  Map<HoldSignal, Set<AnalysisSignalRole>> holdSignalRoles =
      const <HoldSignal, Set<AnalysisSignalRole>>{},
  CameraViewContract? cameraViewContract,
  RangeRepTimingTraceSnapshot? activeTimingTrace,
  RangeRepTimingTraceSnapshot? lastEndedTimingTrace,
  TempoMeasurementAssessment? lastTempoMeasurementAssessment,
  int nonMonotonicObservationCount = 0,
  String? lastRangeRepValidationStatus,
  List<String> lastRangeRepValidationReasons = const <String>[],
  List<String> lastRangeRepTempoDiagnosticReasons = const <String>[],
  MeasurementConfidenceBreakdown? currentLeftMeasurementConfidence,
  MeasurementConfidenceBreakdown? currentRightMeasurementConfidence,
  MeasurementConfidenceBreakdown? lastRepMeasurementConfidence,
  int measurementConfidenceKnownRepCount = 0,
  int measurementConfidenceUnknownRepCount = 0,
  Map<String, int> measurementConfidenceIssueCounts = const <String, int>{},
}) {
  final sessionStartedAt = DateTime.utc(2030, 1, 1, 0, 0, 0);
  final snapshotCreatedAt = sessionStartedAt.add(
    Duration(milliseconds: elapsedMs),
  );
  return WorkoutDiagnosticsSnapshot(
    schemaVersion: schemaVersion,
    appCommitSha: appCommitSha,
    buildMode: buildMode,
    analysisKind: analysisKind,
    exerciseType: 'squat',
    configAssetPath: 'assets/config/exercises/squat.json',
    configVersionFingerprint:
        'assets/config/exercises/squat.json@$appCommitSha',
    contractProfile: analysisKind == 'hold' ? 'hold:plank' : 'rangeRep:squat',
    rangeRepSideMode: analysisKind == 'rangeRep' ? 'selectedSide' : null,
    rangeRepPrimaryMetricKind: analysisKind == 'rangeRep' ? 'jointAngle' : null,
    rangeRepPrimaryMetricDirection: analysisKind == 'rangeRep'
        ? 'decreasingToPeak'
        : null,
    holdAnalysisFamily: analysisKind == 'hold' ? 'plank' : null,
    sessionStartedAt: sessionStartedAt,
    snapshotCreatedAt: snapshotCreatedAt,
    elapsedMs: elapsedMs,
    cameraFrameCount: cameraFrameCount,
    analysisAttemptCount: analysisAttemptCount,
    analysisCompletedCount: analysisCompletedCount,
    throttledFrameCount: throttledFrameCount,
    reentrantDropCount: reentrantDropCount,
    converterDropCount: converterDropCount,
    noPoseFrameCount: noPoseFrameCount,
    multiPoseFrameCount: multiPoseFrameCount,
    maxPoseCount: maxPoseCount,
    analysisExceptionCount: analysisExceptionCount,
    resyncCount: resyncCount,
    holdVisibilitySuspendCount: holdVisibilitySuspendCount,
    holdVisibilityRecoveryCount: holdVisibilityRecoveryCount,
    holdVisibilityAbortCount: holdVisibilityAbortCount,
    holdVisibilitySuspendedMsTotal: holdVisibilitySuspendedMsTotal,
    lastHoldVisibilityGapMs: lastHoldVisibilityGapMs,
    cameraViewContract: cameraViewContract ?? _sideViewContract,
    rangeRepDiagnostics: analysisKind == 'rangeRep'
        ? RangeRepWorkoutDiagnostics(
            repCount: repCount,
            currentPhase: currentPhase,
            sideSwitchCount: sideSwitchCount,
            activeRepSideSwitchCount: activeRepSideSwitchCount,
            currentSelectedSide: currentSelectedSide,
            lastCalibrationOffsetDegrees: lastCalibrationOffsetDegrees,
            signalRoles: rangeRepSignalRoles,
            activeTimingTrace: activeTimingTrace,
            lastEndedTimingTrace: lastEndedTimingTrace,
            lastTempoMeasurementAssessment: lastTempoMeasurementAssessment,
            nonMonotonicObservationCount: nonMonotonicObservationCount,
            lastValidationStatus: lastRangeRepValidationStatus,
            lastValidationReasons: lastRangeRepValidationReasons,
            lastTempoDiagnosticReasons: lastRangeRepTempoDiagnosticReasons,
            currentLeftMeasurementConfidence: currentLeftMeasurementConfidence,
            currentRightMeasurementConfidence:
                currentRightMeasurementConfidence,
            lastRepMeasurementConfidence: lastRepMeasurementConfidence,
            measurementConfidenceKnownRepCount:
                measurementConfidenceKnownRepCount,
            measurementConfidenceUnknownRepCount:
                measurementConfidenceUnknownRepCount,
            measurementConfidenceIssueCounts: measurementConfidenceIssueCounts,
          )
        : null,
    holdDiagnostics: analysisKind == 'hold'
        ? HoldWorkoutDiagnostics(
            currentHoldSeconds: currentHoldSeconds,
            bestHoldSeconds: bestHoldSeconds,
            currentPhase: currentPhase,
            isHolding: isHolding,
            presentedHoldFeedbackCode: presentedHoldFeedbackCode,
            engineHoldFeedbackCode: engineHoldFeedbackCode,
            holdEnginePhase: holdEnginePhase,
            currentHoldSide: currentHoldSide,
            lastVisibleHoldPosture: lastVisibleHoldPosture,
            currentSignalValues: currentSignalValues,
            targetSignalValues: targetSignalValues,
            signalValidity: signalValidity,
            isHoldFormBreakGraceActive: isHoldFormBreakGraceActive,
            isHoldVisibilitySuspended: isHoldVisibilitySuspended,
            signalRoles: holdSignalRoles,
          )
        : null,
    currentCameraFps: currentCameraFps,
    currentAnalysisFps: currentAnalysisFps,
    fpsSampleCount: fpsSampleCount,
    cameraFpsP50: cameraFpsP50,
    cameraFpsP95: cameraFpsP95,
    analysisFpsP50: analysisFpsP50,
    analysisFpsP95: analysisFpsP95,
    frameProcessingMsP50: frameProcessingMsP50,
    frameProcessingMsP95: frameProcessingMsP95,
    frameProcessingMsMax: frameProcessingMsMax,
  );
}
