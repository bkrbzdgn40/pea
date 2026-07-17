import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_validity.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/workout_diagnostics_panel.dart';

const String _missingValue = '\u2014';
const String _resetButtonText = 'Saya\u00e7lar\u0131 S\u0131f\u0131rla';
const String _copySuccessText = 'Diagnostics JSON panoya kopyaland\u0131.';
const String _resetSuccessText =
    'Diagnostics saya\u00e7lar\u0131 s\u0131f\u0131rland\u0131.';

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
    expect(find.text('Schema version'), findsOneWidget);
    expect(find.text('Elapsed time'), findsOneWidget);
    expect(find.text('5 sn'), findsOneWidget);
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
      ),
      onReset: () {},
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();

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
    expect(find.text('alignment'), findsOneWidget);
    expect(find.text('support'), findsOneWidget);
    expect(find.text('extension'), findsOneWidget);
    expect(find.text('Body aligned'), findsOneWidget);
    expect(find.text('Arm supported'), findsOneWidget);
    expect(find.text('Legs extended'), findsOneWidget);
    expect(find.text('Form-break grace active'), findsOneWidget);
    expect(find.text('Visibility suspended'), findsOneWidget);
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

      await tester.drag(find.byType(ListView), const Offset(0, -1400));
      await tester.pumpAndSettle();

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
    expect(decoded['schema_version'], 3);
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

  testWidgets('debug test buildinde diagnostics UI flag etkindir', (
    tester,
  ) async {
    expect(workoutDiagnosticsUiEnabled, isTrue);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required WorkoutDiagnosticsSnapshot Function() snapshotReader,
  required VoidCallback onReset,
  Future<void> Function(String text)? copyText,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorkoutDiagnosticsPanel(
          snapshotReader: snapshotReader,
          onReset: onReset,
          copyText: copyText,
        ),
      ),
    ),
  );
}

WorkoutDiagnosticsSnapshot _snapshot({
  int schemaVersion = 3,
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
    rangeRepDiagnostics: analysisKind == 'rangeRep'
        ? RangeRepWorkoutDiagnostics(
            repCount: repCount,
            currentPhase: currentPhase,
            sideSwitchCount: sideSwitchCount,
            activeRepSideSwitchCount: activeRepSideSwitchCount,
            currentSelectedSide: currentSelectedSide,
            lastCalibrationOffsetDegrees: lastCalibrationOffsetDegrees,
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
          )
        : null,
    currentCameraFps: currentCameraFps,
    currentAnalysisFps: currentAnalysisFps,
    frameProcessingMsP50: frameProcessingMsP50,
    frameProcessingMsP95: frameProcessingMsP95,
    frameProcessingMsMax: frameProcessingMsMax,
  );
}
