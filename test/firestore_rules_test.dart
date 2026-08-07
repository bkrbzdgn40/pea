import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final String? _firestoreHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
final String? _authHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
final bool _requireFirebaseEmulators =
    Platform.environment['REQUIRE_FIREBASE_EMULATORS'] == 'true';
final List<String> _missingEmulatorEnvironmentVariables = <String>[
  if (_firestoreHost == null) 'FIRESTORE_EMULATOR_HOST',
  if (_authHost == null) 'FIREBASE_AUTH_EMULATOR_HOST',
];
final String _projectId =
    Platform.environment['GCLOUD_PROJECT'] ?? 'pose-estimation-app-dd06c';
final Object _emulatorSkipReason =
    !_requireFirebaseEmulators &&
        _missingEmulatorEnvironmentVariables.isNotEmpty
    ? 'Run via firebase emulators:exec --project pose-estimation-app-dd06c '
          '--only auth,firestore "flutter test test/firestore_rules_test.dart".'
    : false;

void main() {
  setUpAll(() {
    if (_requireFirebaseEmulators &&
        _missingEmulatorEnvironmentVariables.isNotEmpty) {
      fail(
        'REQUIRE_FIREBASE_EMULATORS=true but required emulator environment '
        'variables are missing: '
        '${_missingEmulatorEnvironmentVariables.join(', ')}.',
      );
    }
  });

  group('Firestore session security rules', skip: _emulatorSkipReason, () {
    late _RulesClient unauthenticatedClient;
    late _RulesClient ownerClient;
    late _RulesClient otherClient;

    setUp(() async {
      await _clearEmulators();
      unauthenticatedClient = const _RulesClient();
      ownerClient = await _RulesClient.signUp();
      otherClient = await _RulesClient.signUp();
    });

    test('unauthenticated user cannot read session', () async {
      await _createSession(ownerClient);

      final response = await unauthenticatedClient.getDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('owner can create session', () async {
      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        _validSessionData(ownerId: ownerClient.uid!, id: 'session_a'),
      );

      expect(
        response.statusCode,
        inInclusiveRange(200, 299),
        reason: response.body,
      );
    });

    test('current client can persist captured timezone offset', () async {
      final data = _validSessionData(
        ownerId: ownerClient.uid!,
        id: 'session_a',
      );

      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        data,
      );

      expect(
        response.statusCode,
        inInclusiveRange(200, 299),
        reason: response.body,
      );
    });

    test('legacy client may omit captured timezone offset', () async {
      final data = _validSessionData(ownerId: ownerClient.uid!, id: 'session_a')
        ..remove('timezoneOffsetMinutes');

      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        data,
      );

      expect(
        response.statusCode,
        inInclusiveRange(200, 299),
        reason: response.body,
      );
    });

    test('invalid timezone offset is rejected', () async {
      final data = _validSessionData(ownerId: ownerClient.uid!, id: 'session_a')
        ..['timezoneOffsetMinutes'] = 841;

      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        data,
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('legacy client can still create a session during rollout', () async {
      final data = _validSessionData(ownerId: ownerClient.uid!, id: 'session_a')
        ..remove('preparationOutcome')
        ..remove('measurementQuality')
        ..remove('averageMeasurementConfidence')
        ..remove('measurementSampleCount')
        ..remove('timezoneOffsetMinutes');

      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        data,
      );

      expect(
        response.statusCode,
        inInclusiveRange(200, 299),
        reason: response.body,
      );
    });

    test('partial measurement evidence rollout shape is rejected', () async {
      final data = _validSessionData(ownerId: ownerClient.uid!, id: 'session_a')
        ..remove('measurementQuality');

      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        data,
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('owner can read session', () async {
      await _createSession(ownerClient);

      final response = await ownerClient.getDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
      );

      expect(response.statusCode, 200, reason: response.body);
    });

    test('other user cannot read session', () async {
      await _createSession(ownerClient);

      final response = await otherClient.getDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('owner cannot create session with mismatched ownerId', () async {
      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        _validSessionData(ownerId: otherClient.uid!, id: 'session_a'),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('owner cannot create session with mismatched document id', () async {
      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        _validSessionData(ownerId: ownerClient.uid!, id: 'session_b'),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('accepted validation counts cannot exceed total reps', () async {
      final data = _validSessionData(ownerId: ownerClient.uid!, id: 'session_a')
        ..['validReps'] = 12
        ..['lowConfidenceReps'] = 1;

      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        data,
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('negative low-confidence count is rejected', () async {
      final data = _validSessionData(ownerId: ownerClient.uid!, id: 'session_a')
        ..['lowConfidenceReps'] = -1;

      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        data,
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('unknown preparation outcome is rejected', () async {
      final data = _validSessionData(ownerId: ownerClient.uid!, id: 'session_a')
        ..['preparationOutcome'] = 'forced';

      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        data,
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('unknown session measurement quality is rejected', () async {
      final data = _validSessionData(ownerId: ownerClient.uid!, id: 'session_a')
        ..['measurementQuality'] = 'excellent';

      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        data,
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('overridden preparation cannot claim high quality', () async {
      final data = _validSessionData(ownerId: ownerClient.uid!, id: 'session_a')
        ..['preparationOutcome'] = 'overridden'
        ..['measurementQuality'] = 'high';

      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        data,
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('measurement evidence count must match confidence presence', () async {
      final data = _validSessionData(ownerId: ownerClient.uid!, id: 'session_a')
        ..['averageMeasurementConfidence'] = null
        ..['measurementSampleCount'] = 3;

      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        data,
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('unknown extra session field is rejected', () async {
      final response = await ownerClient.setDocument(
        _sessionPath(ownerClient.uid!, 'session_a'),
        <String, Object?>{
          ..._validSessionData(ownerId: ownerClient.uid!, id: 'session_a'),
          'unexpectedField': true,
        },
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test(
      'production-shaped session and reps succeed as separate writes',
      () async {
        const sessionId = 'session_production_shape';
        final ownerId = ownerClient.uid!;
        final writes = <({String path, Map<String, Object?> data})>[
          (
            path: _repPath(ownerId, sessionId, 'rep_0001'),
            data: _productionRepData(
              ownerId: ownerId,
              sessionId: sessionId,
              id: 'rep_0001',
              repIndex: 1,
              score: 76.93333333333334,
              durationSeconds: 5.945,
              descentMillis: 793,
              ascentMillis: 3753,
              tempoQuality: 'tooSlow',
              tempoReasons: const <String>['concentricTooSlow', 'totalTooSlow'],
              confidence: 0.9847243962512868,
            ),
          ),
          (
            path: _repPath(ownerId, sessionId, 'rep_0002'),
            data: _productionRepData(
              ownerId: ownerId,
              sessionId: sessionId,
              id: 'rep_0002',
              repIndex: 2,
              score: 90.8,
              durationSeconds: 2.7,
              descentMillis: 610,
              ascentMillis: 510,
              tempoQuality: 'tooFast',
              tempoReasons: const <String>['eccentricTooFast'],
              confidence: 0.9831849188658616,
            ),
          ),
          (
            path: _sessionPath(ownerId, sessionId),
            data: _productionSessionData(ownerId: ownerId, id: sessionId),
          ),
        ];

        for (final write in writes) {
          final response = await ownerClient.setDocument(
            write.path,
            write.data,
          );
          expect(
            response.statusCode,
            inInclusiveRange(200, 299),
            reason: '${write.path}: ${response.body}',
          );
        }
      },
    );
  });

  group('Firestore goal security rules', skip: _emulatorSkipReason, () {
    late _RulesClient unauthenticatedClient;
    late _RulesClient ownerClient;
    late _RulesClient otherClient;

    setUp(() async {
      await _clearEmulators();
      unauthenticatedClient = const _RulesClient();
      ownerClient = await _RulesClient.signUp();
      otherClient = await _RulesClient.signUp();
    });

    test('owner can create and read a valid goal', () async {
      final path = _goalPath(ownerClient.uid!, 'weeklySessions');
      final write = await ownerClient.setDocument(
        path,
        _validGoalData(
          ownerId: ownerClient.uid!,
          type: 'weeklySessions',
          period: 'weekly',
          targetValue: 5,
        ),
      );
      final read = await ownerClient.getDocument(path);

      expect(write.statusCode, inInclusiveRange(200, 299), reason: write.body);
      expect(read.statusCode, 200, reason: read.body);
    });

    test('other and unauthenticated users cannot read a goal', () async {
      final path = _goalPath(ownerClient.uid!, 'weeklySessions');
      final write = await ownerClient.setDocument(
        path,
        _validGoalData(
          ownerId: ownerClient.uid!,
          type: 'weeklySessions',
          period: 'weekly',
          targetValue: 5,
        ),
      );
      expect(write.statusCode, inInclusiveRange(200, 299), reason: write.body);

      final otherRead = await otherClient.getDocument(path);
      final unauthenticatedRead = await unauthenticatedClient.getDocument(path);

      expect(otherRead.statusCode, 403, reason: otherRead.body);
      expect(
        unauthenticatedRead.statusCode,
        403,
        reason: unauthenticatedRead.body,
      );
    });

    test('goal document id and type must match', () async {
      final response = await ownerClient.setDocument(
        _goalPath(ownerClient.uid!, 'weeklySessions'),
        _validGoalData(
          ownerId: ownerClient.uid!,
          type: 'weeklyReps',
          period: 'weekly',
          targetValue: 100,
        ),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('goal period must match its type', () async {
      final response = await ownerClient.setDocument(
        _goalPath(ownerClient.uid!, 'averageScore'),
        _validGoalData(
          ownerId: ownerClient.uid!,
          type: 'averageScore',
          period: 'weekly',
          targetValue: 85,
        ),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('goal target must stay within the supported range', () async {
      final response = await ownerClient.setDocument(
        _goalPath(ownerClient.uid!, 'weeklySessions'),
        _validGoalData(
          ownerId: ownerClient.uid!,
          type: 'weeklySessions',
          period: 'weekly',
          targetValue: 50,
        ),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('weekly goals reject fractional targets', () async {
      final response = await ownerClient.setDocument(
        _goalPath(ownerClient.uid!, 'weeklySessions'),
        _validGoalData(
          ownerId: ownerClient.uid!,
          type: 'weeklySessions',
          period: 'weekly',
          targetValue: 2.5,
        ),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('goal updatedAt cannot move backwards', () async {
      final path = _goalPath(ownerClient.uid!, 'weeklySessions');
      final createdAt = DateTime.utc(2026, 8, 5, 10);
      final firstWrite = await ownerClient.setDocument(path, <String, Object?>{
        ..._validGoalData(
          ownerId: ownerClient.uid!,
          type: 'weeklySessions',
          period: 'weekly',
          targetValue: 5,
        ),
        'createdAt': createdAt,
        'updatedAt': DateTime.utc(2026, 8, 5, 12),
      });
      expect(
        firstWrite.statusCode,
        inInclusiveRange(200, 299),
        reason: firstWrite.body,
      );

      final rollback = await ownerClient.setDocument(path, <String, Object?>{
        ..._validGoalData(
          ownerId: ownerClient.uid!,
          type: 'weeklySessions',
          period: 'weekly',
          targetValue: 6,
        ),
        'createdAt': createdAt,
        'updatedAt': DateTime.utc(2026, 8, 5, 11),
      });

      expect(rollback.statusCode, 403, reason: rollback.body);
    });

    test('goal owner cannot be changed by another user', () async {
      final response = await ownerClient.setDocument(
        _goalPath(ownerClient.uid!, 'weeklySessions'),
        _validGoalData(
          ownerId: otherClient.uid!,
          type: 'weeklySessions',
          period: 'weekly',
          targetValue: 5,
        ),
      );

      expect(response.statusCode, 403, reason: response.body);
    });
  });

  group('Firestore rep security rules', skip: _emulatorSkipReason, () {
    late _RulesClient ownerClient;
    late _RulesClient otherClient;

    setUp(() async {
      await _clearEmulators();
      ownerClient = await _RulesClient.signUp();
      otherClient = await _RulesClient.signUp();
      await _createSession(ownerClient);
    });

    test('owner can create rep under own session', () async {
      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        _validRepData(
          ownerId: ownerClient.uid!,
          sessionId: 'session_a',
          id: 'rep_0001',
        ),
      );

      expect(
        response.statusCode,
        inInclusiveRange(200, 299),
        reason: response.body,
      );
    });

    test('owner can create rep with tempo coaching fields', () async {
      final data =
          _validRepData(
            ownerId: ownerClient.uid!,
            sessionId: 'session_a',
            id: 'rep_0001',
          )..addAll(<String, Object?>{
            'tempoMeasurementStatus': 'eligible',
            'tempoMeasurementIssues': const <String>[],
            'tempoQuality': 'tooFast',
            'tempoSeverity': 'mild',
            'tempoReasons': const <String>['eccentricTooFast'],
            'tempoIncludedInScore': true,
            'tempoTotalMillis': 1160,
          });

      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        data,
      );

      expect(
        response.statusCode,
        inInclusiveRange(200, 299),
        reason: response.body,
      );
    });

    test(
      'owner can create rep with measurement confidence breakdown',
      () async {
        final data =
            _validRepData(
              ownerId: ownerClient.uid!,
              sessionId: 'session_a',
              id: 'rep_0001',
            )..addAll(<String, Object?>{
              'measurementConfidence': _validMeasurementConfidenceData(),
              'confidence': 0.89,
            });

        final response = await ownerClient.setDocument(
          _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
          data,
        );

        expect(
          response.statusCode,
          inInclusiveRange(200, 299),
          reason: response.body,
        );
      },
    );

    test('unknown measurement confidence remains writable', () async {
      final data =
          _validRepData(
            ownerId: ownerClient.uid!,
            sessionId: 'session_a',
            id: 'rep_0001',
          )..addAll(<String, Object?>{
            'measurementConfidence': <String, Object?>{
              'landmarkLikelihood': 0.99,
              'signalAvailability': 1.0,
              'geometryPlausibility': 1.0,
              'temporalContinuity': null,
              'combined': null,
              'issues': const <String>['temporal_history_unavailable'],
            },
            'confidence': null,
          });

      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        data,
      );

      expect(
        response.statusCode,
        inInclusiveRange(200, 299),
        reason: response.body,
      );
    });

    test('measurement confidence scalar mismatch is rejected', () async {
      final data =
          _validRepData(
            ownerId: ownerClient.uid!,
            sessionId: 'session_a',
            id: 'rep_0001',
          )..addAll(<String, Object?>{
            'measurementConfidence': _validMeasurementConfidenceData(),
            'confidence': 0.5,
          });

      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        data,
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('out-of-range measurement confidence component is rejected', () async {
      final breakdown = _validMeasurementConfidenceData()
        ..['temporalContinuity'] = 1.2;
      final data =
          _validRepData(
            ownerId: ownerClient.uid!,
            sessionId: 'session_a',
            id: 'rep_0001',
          )..addAll(<String, Object?>{
            'measurementConfidence': breakdown,
            'confidence': 0.89,
          });

      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        data,
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('unknown measurement confidence field is rejected', () async {
      final breakdown = _validMeasurementConfidenceData()
        ..['unexpected'] = true;
      final data =
          _validRepData(
            ownerId: ownerClient.uid!,
            sessionId: 'session_a',
            id: 'rep_0001',
          )..addAll(<String, Object?>{
            'measurementConfidence': breakdown,
            'confidence': 0.89,
          });

      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        data,
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('unknown measurement confidence issue is rejected', () async {
      final breakdown = _validMeasurementConfidenceData()
        ..['issues'] = const <String>['made_up_issue'];
      final data =
          _validRepData(
            ownerId: ownerClient.uid!,
            sessionId: 'session_a',
            id: 'rep_0001',
          )..addAll(<String, Object?>{
            'measurementConfidence': breakdown,
            'confidence': 0.89,
          });

      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        data,
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('invalid tempo enum value is rejected', () async {
      final data = _validRepData(
        ownerId: ownerClient.uid!,
        sessionId: 'session_a',
        id: 'rep_0001',
      )..['tempoQuality'] = 'warpSpeed';

      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        data,
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('owner can read own rep', () async {
      await _createRep(ownerClient);

      final response = await ownerClient.getDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
      );

      expect(response.statusCode, 200, reason: response.body);
    });

    test('other user cannot read rep', () async {
      await _createRep(ownerClient);

      final response = await otherClient.getDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('owner cannot create rep with mismatched ownerId', () async {
      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        _validRepData(
          ownerId: otherClient.uid!,
          sessionId: 'session_a',
          id: 'rep_0001',
        ),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('owner cannot create rep with mismatched sessionId', () async {
      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        _validRepData(
          ownerId: ownerClient.uid!,
          sessionId: 'session_b',
          id: 'rep_0001',
        ),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('owner cannot create rep with mismatched id', () async {
      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        _validRepData(
          ownerId: ownerClient.uid!,
          sessionId: 'session_a',
          id: 'rep_9999',
        ),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('unknown extra rep field is rejected', () async {
      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        <String, Object?>{
          ..._validRepData(
            ownerId: ownerClient.uid!,
            sessionId: 'session_a',
            id: 'rep_0001',
          ),
          'unexpectedField': 'nope',
        },
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('negative repIndex is rejected', () async {
      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        _validRepData(
          ownerId: ownerClient.uid!,
          sessionId: 'session_a',
          id: 'rep_0001',
          repIndex: -1,
        ),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('negative durationSeconds is rejected', () async {
      final response = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        _validRepData(
          ownerId: ownerClient.uid!,
          sessionId: 'session_a',
          id: 'rep_0001',
          durationSeconds: -1.0,
        ),
      );

      expect(response.statusCode, 403, reason: response.body);
    });

    test('score below 0 or above 100 is rejected', () async {
      final belowRangeResponse = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0001'),
        _validRepData(
          ownerId: ownerClient.uid!,
          sessionId: 'session_a',
          id: 'rep_0001',
          score: -0.1,
        ),
      );
      final aboveRangeResponse = await ownerClient.setDocument(
        _repPath(ownerClient.uid!, 'session_a', 'rep_0002'),
        _validRepData(
          ownerId: ownerClient.uid!,
          sessionId: 'session_a',
          id: 'rep_0002',
          repIndex: 2,
          score: 101.0,
        ),
      );

      expect(
        belowRangeResponse.statusCode,
        403,
        reason: belowRangeResponse.body,
      );
      expect(
        aboveRangeResponse.statusCode,
        403,
        reason: aboveRangeResponse.body,
      );
    });
  });

  group(
    'Firestore challenge progress security rules',
    skip: _emulatorSkipReason,
    () {
      late _RulesClient unauthenticatedClient;
      late _RulesClient ownerClient;
      late _RulesClient otherClient;

      setUp(() async {
        await _clearEmulators();
        unauthenticatedClient = const _RulesClient();
        ownerClient = await _RulesClient.signUp();
        otherClient = await _RulesClient.signUp();
      });

      test('owner can write and read contribution and activity day', () async {
        final ownerId = ownerClient.uid!;
        final contributionResponse = await ownerClient.setDocument(
          _progressContributionPath(ownerId, 'session_a'),
          _validProgressContributionData(
            ownerId: ownerId,
            sessionId: 'session_a',
          ),
        );
        final activityDayResponse = await ownerClient.setDocument(
          _activityDayPath(ownerId, '2026-08-07'),
          _validActivityDayData(ownerId: ownerId),
        );

        expect(
          contributionResponse.statusCode,
          inInclusiveRange(200, 299),
          reason: contributionResponse.body,
        );
        expect(
          activityDayResponse.statusCode,
          inInclusiveRange(200, 299),
          reason: activityDayResponse.body,
        );
        expect(
          (await ownerClient.getDocument(
            _progressContributionPath(ownerId, 'session_a'),
          )).statusCode,
          200,
        );
        expect(
          (await ownerClient.getDocument(
            _activityDayPath(ownerId, '2026-08-07'),
          )).statusCode,
          200,
        );
      });

      test('other and unauthenticated users cannot read progress', () async {
        final ownerId = ownerClient.uid!;
        await ownerClient.setDocument(
          _progressContributionPath(ownerId, 'session_a'),
          _validProgressContributionData(
            ownerId: ownerId,
            sessionId: 'session_a',
          ),
        );

        expect(
          (await otherClient.getDocument(
            _progressContributionPath(ownerId, 'session_a'),
          )).statusCode,
          403,
        );
        expect(
          (await unauthenticatedClient.getDocument(
            _progressContributionPath(ownerId, 'session_a'),
          )).statusCode,
          403,
        );
      });

      test('contribution owner and document id must match the path', () async {
        final ownerId = ownerClient.uid!;
        final wrongOwner = await ownerClient.setDocument(
          _progressContributionPath(ownerId, 'session_a'),
          _validProgressContributionData(
            ownerId: otherClient.uid!,
            sessionId: 'session_a',
          ),
        );
        final wrongId = await ownerClient.setDocument(
          _progressContributionPath(ownerId, 'session_a'),
          _validProgressContributionData(
            ownerId: ownerId,
            sessionId: 'session_b',
          ),
        );

        expect(wrongOwner.statusCode, 403, reason: wrongOwner.body);
        expect(wrongId.statusCode, 403, reason: wrongId.body);
      });

      test(
        'rep contributions reject fractional values and hold exercises',
        () async {
          final ownerId = ownerClient.uid!;
          final fractional = _validProgressContributionData(
            ownerId: ownerId,
            sessionId: 'session_a',
          )..['value'] = 10.5;
          final wrongMetric =
              _validProgressContributionData(
                  ownerId: ownerId,
                  sessionId: 'session_b',
                )
                ..['exerciseType'] = 'plank'
                ..['challengeId'] = 'plank_volume';

          expect(
            (await ownerClient.setDocument(
              _progressContributionPath(ownerId, 'session_a'),
              fractional,
            )).statusCode,
            403,
          );
          expect(
            (await ownerClient.setDocument(
              _progressContributionPath(ownerId, 'session_b'),
              wrongMetric,
            )).statusCode,
            403,
          );
        },
      );

      test('activity day rejects malformed aggregates', () async {
        final ownerId = ownerClient.uid!;
        final negative = _validActivityDayData(ownerId: ownerId)
          ..['validRepsByExercise'] = <String, Object?>{'push_up': -1};
        final unknownExercise = _validActivityDayData(ownerId: ownerId)
          ..['validRepsByExercise'] = <String, Object?>{'burpee': 10}
          ..['exerciseTypes'] = <String>['burpee'];

        expect(
          (await ownerClient.setDocument(
            _activityDayPath(ownerId, '2026-08-07'),
            negative,
          )).statusCode,
          403,
        );
        expect(
          (await ownerClient.setDocument(
            _activityDayPath(ownerId, '2026-08-07'),
            unknownExercise,
          )).statusCode,
          403,
        );
      });
    },
  );

  group(
    'Firestore achievement event security rules',
    skip: _emulatorSkipReason,
    () {
      late _RulesClient unauthenticatedClient;
      late _RulesClient ownerClient;
      late _RulesClient otherClient;

      setUp(() async {
        await _clearEmulators();
        unauthenticatedClient = const _RulesClient();
        ownerClient = await _RulesClient.signUp();
        otherClient = await _RulesClient.signUp();
      });

      test('owner can create and read deterministic guide event', () async {
        final ownerId = ownerClient.uid!;
        final eventId = 'guide-step:1';
        final path = _achievementEventPath(ownerId, eventId);
        final data = _validAchievementEventData(
          ownerId: ownerId,
          eventId: eventId,
          type: 'guideStepOpened',
          subjectId: '1',
        );

        final create = await ownerClient.setDocument(path, data);
        final read = await ownerClient.getDocument(path);

        expect(
          create.statusCode,
          inInclusiveRange(200, 299),
          reason: create.body,
        );
        expect(read.statusCode, 200, reason: read.body);
      });

      test('other and unauthenticated users cannot access events', () async {
        final ownerId = ownerClient.uid!;
        final eventId = 'guide-step:1';
        final path = _achievementEventPath(ownerId, eventId);
        final data = _validAchievementEventData(
          ownerId: ownerId,
          eventId: eventId,
          type: 'guideStepOpened',
          subjectId: '1',
        );
        await ownerClient.setDocument(path, data);

        expect((await otherClient.getDocument(path)).statusCode, 403);
        expect((await unauthenticatedClient.getDocument(path)).statusCode, 403);
        expect((await otherClient.setDocument(path, data)).statusCode, 403);
      });

      test(
        'event id and type must match their deterministic subject',
        () async {
          final ownerId = ownerClient.uid!;
          final wrongGuide = _validAchievementEventData(
            ownerId: ownerId,
            eventId: 'guide-step:1',
            type: 'guideStepOpened',
            subjectId: '2',
          );
          final wrongPlan = _validAchievementEventData(
            ownerId: ownerId,
            eventId: 'planned-workout:run-a',
            type: 'controlledTempoSession',
            subjectId: 'run-a',
          );

          expect(
            (await ownerClient.setDocument(
              _achievementEventPath(ownerId, 'guide-step:1'),
              wrongGuide,
            )).statusCode,
            403,
          );
          expect(
            (await ownerClient.setDocument(
              _achievementEventPath(ownerId, 'planned-workout:run-a'),
              wrongPlan,
            )).statusCode,
            403,
          );
        },
      );

      test('event timezone and local date shape are validated', () async {
        final ownerId = ownerClient.uid!;
        final eventId = 'controlled-tempo:session-a';
        final badOffset = _validAchievementEventData(
          ownerId: ownerId,
          eventId: eventId,
          type: 'controlledTempoSession',
          subjectId: 'session-a',
        )..['timezoneOffsetMinutes'] = -841;
        final badDate = _validAchievementEventData(
          ownerId: ownerId,
          eventId: 'controlled-tempo:session-b',
          type: 'controlledTempoSession',
          subjectId: 'session-b',
        )..['localDate'] = '07-08-2026';

        expect(
          (await ownerClient.setDocument(
            _achievementEventPath(ownerId, eventId),
            badOffset,
          )).statusCode,
          403,
        );
        expect(
          (await ownerClient.setDocument(
            _achievementEventPath(ownerId, 'controlled-tempo:session-b'),
            badDate,
          )).statusCode,
          403,
        );
      });

      test('achievement events are immutable once written', () async {
        final ownerId = ownerClient.uid!;
        final eventId = 'planned-workout:run-a';
        final path = _achievementEventPath(ownerId, eventId);
        final data = _validAchievementEventData(
          ownerId: ownerId,
          eventId: eventId,
          type: 'plannedWorkoutCompleted',
          subjectId: 'run-a',
        );
        expect(
          (await ownerClient.setDocument(path, data)).statusCode,
          inInclusiveRange(200, 299),
        );

        final changed = Map<String, Object?>.from(data)
          ..['createdAt'] = DateTime.utc(2026, 8, 7, 9);
        expect((await ownerClient.setDocument(path, changed)).statusCode, 403);
        expect((await ownerClient.deleteDocument(path)).statusCode, 403);
      });
    },
  );

  group(
    'Firestore reward ledger security rules',
    skip: _emulatorSkipReason,
    () {
      late _RulesClient unauthenticatedClient;
      late _RulesClient ownerClient;
      late _RulesClient otherClient;

      setUp(() async {
        await _clearEmulators();
        unauthenticatedClient = const _RulesClient();
        ownerClient = await _RulesClient.signUp();
        otherClient = await _RulesClient.signUp();
      });

      test(
        'owner can create and read one deterministic medal reward',
        () async {
          final ownerId = ownerClient.uid!;
          final rewardId = _dailyPushUpRewardId;
          final create = await ownerClient.setDocument(
            _rewardPath(ownerId, rewardId),
            _validChallengeMedalRewardData(ownerId: ownerId),
          );
          final read = await ownerClient.getDocument(
            _rewardPath(ownerId, rewardId),
          );

          expect(
            create.statusCode,
            inInclusiveRange(200, 299),
            reason: create.body,
          );
          expect(read.statusCode, 200, reason: read.body);
        },
      );

      test('other and unauthenticated users cannot access rewards', () async {
        final ownerId = ownerClient.uid!;
        final path = _rewardPath(ownerId, _dailyPushUpRewardId);
        final data = _validChallengeMedalRewardData(ownerId: ownerId);
        await ownerClient.setDocument(path, data);

        expect((await otherClient.getDocument(path)).statusCode, 403);
        expect((await unauthenticatedClient.getDocument(path)).statusCode, 403);
        expect((await otherClient.setDocument(path, data)).statusCode, 403);
        expect(
          (await unauthenticatedClient.setDocument(path, data)).statusCode,
          403,
        );
      });

      test('reward owner, id, and backfill policy are enforced', () async {
        final ownerId = ownerClient.uid!;
        final wrongOwner = _validChallengeMedalRewardData(
          ownerId: otherClient.uid!,
        );
        final wrongId = _validChallengeMedalRewardData(ownerId: ownerId)
          ..['id'] = 'medal:push_up_volume:daily:2026-08-08';
        final backfilled = _validChallengeMedalRewardData(ownerId: ownerId)
          ..['isBackfilled'] = true;

        expect(
          (await ownerClient.setDocument(
            _rewardPath(ownerId, _dailyPushUpRewardId),
            wrongOwner,
          )).statusCode,
          403,
        );
        expect(
          (await ownerClient.setDocument(
            _rewardPath(ownerId, _dailyPushUpRewardId),
            wrongId,
          )).statusCode,
          403,
        );
        expect(
          (await ownerClient.setDocument(
            _rewardPath(ownerId, _dailyPushUpRewardId),
            backfilled,
          )).statusCode,
          403,
        );
      });

      test('tier timestamps must exactly match the highest medal', () async {
        final ownerId = ownerClient.uid!;
        final malformed = _validChallengeMedalRewardData(ownerId: ownerId)
          ..['highestTier'] = 'silver'
          ..['progressValueAtHighestTier'] = 20;
        final inconsistentProgress = _validChallengeMedalRewardData(
          ownerId: ownerId,
        )..['progressValueAtHighestTier'] = 5;

        final response = await ownerClient.setDocument(
          _rewardPath(ownerId, _dailyPushUpRewardId),
          malformed,
        );

        expect(response.statusCode, 403, reason: response.body);
        expect(
          (await ownerClient.setDocument(
            _rewardPath(ownerId, _dailyPushUpRewardId),
            inconsistentProgress,
          )).statusCode,
          403,
        );
      });

      test(
        'a reward can only upgrade and keeps prior tier timestamps',
        () async {
          final ownerId = ownerClient.uid!;
          final bronze = _validChallengeMedalRewardData(ownerId: ownerId);
          expect(
            (await ownerClient.setDocument(
              _rewardPath(ownerId, _dailyPushUpRewardId),
              bronze,
            )).statusCode,
            inInclusiveRange(200, 299),
          );

          final silverAt = DateTime.utc(2026, 8, 7, 10);
          final silver = Map<String, Object?>.from(bronze)
            ..['highestTier'] = 'silver'
            ..['progressValueAtHighestTier'] = 20
            ..['tierEarnedAt'] = <String, Object?>{
              'bronze': DateTime.utc(2026, 8, 7, 8),
              'silver': silverAt,
            }
            ..['highestTierEarnedAt'] = silverAt
            ..['historyAt'] = silverAt
            ..['qualifyingEventId'] = 'session_b'
            ..['updatedAt'] = silverAt;
          final upgraded = await ownerClient.setDocument(
            _rewardPath(ownerId, _dailyPushUpRewardId),
            silver,
          );
          expect(
            upgraded.statusCode,
            inInclusiveRange(200, 299),
            reason: upgraded.body,
          );

          final sameTier = Map<String, Object?>.from(silver)
            ..['updatedAt'] = silverAt.add(const Duration(minutes: 1));
          expect(
            (await ownerClient.setDocument(
              _rewardPath(ownerId, _dailyPushUpRewardId),
              sameTier,
            )).statusCode,
            403,
          );

          final changedBronzeTimestamp = Map<String, Object?>.from(silver)
            ..['highestTier'] = 'gold'
            ..['progressValueAtHighestTier'] = 30
            ..['tierEarnedAt'] = <String, Object?>{
              'bronze': DateTime.utc(2026, 8, 7, 9),
              'silver': silverAt,
              'gold': silverAt.add(const Duration(hours: 1)),
            }
            ..['highestTierEarnedAt'] = silverAt.add(const Duration(hours: 1))
            ..['historyAt'] = silverAt.add(const Duration(hours: 1))
            ..['updatedAt'] = silverAt.add(const Duration(hours: 1));
          expect(
            (await ownerClient.setDocument(
              _rewardPath(ownerId, _dailyPushUpRewardId),
              changedBronzeTimestamp,
            )).statusCode,
            403,
          );

          final goldAt = silverAt.add(const Duration(hours: 1));
          final gold = Map<String, Object?>.from(silver)
            ..['highestTier'] = 'gold'
            ..['progressValueAtHighestTier'] = 30
            ..['tierEarnedAt'] = <String, Object?>{
              'bronze': DateTime.utc(2026, 8, 7, 8),
              'silver': silverAt,
              'gold': goldAt,
            }
            ..['highestTierEarnedAt'] = goldAt
            ..['historyAt'] = goldAt
            ..['qualifyingEventId'] = 'session_c'
            ..['updatedAt'] = goldAt;
          final goldUpgrade = await ownerClient.setDocument(
            _rewardPath(ownerId, _dailyPushUpRewardId),
            gold,
          );
          expect(
            goldUpgrade.statusCode,
            inInclusiveRange(200, 299),
            reason: goldUpgrade.body,
          );
        },
      );

      test('owner can create an immutable achievement reward', () async {
        final ownerId = ownerClient.uid!;
        final rewardId = 'achievement:first_reliable_analysis';
        final data = _validAchievementRewardData(ownerId: ownerId);

        final create = await ownerClient.setDocument(
          _rewardPath(ownerId, rewardId),
          data,
        );
        expect(
          create.statusCode,
          inInclusiveRange(200, 299),
          reason: create.body,
        );

        final changed = Map<String, Object?>.from(data)
          ..['updatedAt'] = DateTime.utc(2026, 8, 7, 9);
        expect(
          (await ownerClient.setDocument(
            _rewardPath(ownerId, rewardId),
            changed,
          )).statusCode,
          403,
        );
      });

      test(
        'achievement backfill is restricted to the approved catalog subset',
        () async {
          final ownerId = ownerClient.uid!;
          final allowed = _validAchievementRewardData(ownerId: ownerId)
            ..['isBackfilled'] = true;
          expect(
            (await ownerClient.setDocument(
              _rewardPath(ownerId, 'achievement:first_reliable_analysis'),
              allowed,
            )).statusCode,
            inInclusiveRange(200, 299),
          );

          final denied = _validAchievementRewardData(
            ownerId: ownerId,
            achievementId: 'guide_completed',
            qualifyingEventId: 'guide-complete',
          )..['isBackfilled'] = true;
          expect(
            (await ownerClient.setDocument(
              _rewardPath(ownerId, 'achievement:guide_completed'),
              denied,
            )).statusCode,
            403,
          );
        },
      );

      test('earned rewards cannot be deleted by the client', () async {
        final ownerId = ownerClient.uid!;
        await ownerClient.setDocument(
          _rewardPath(ownerId, _dailyPushUpRewardId),
          _validChallengeMedalRewardData(ownerId: ownerId),
        );

        final response = await ownerClient.deleteDocument(
          _rewardPath(ownerId, _dailyPushUpRewardId),
        );

        expect(response.statusCode, 403, reason: response.body);
      });
    },
  );

  group(
    'Firestore reward full-flow release contract',
    skip: _emulatorSkipReason,
    () {
      late _RulesClient ownerClient;

      setUp(() async {
        await _clearEmulators();
        ownerClient = await _RulesClient.signUp();
      });

      test(
        'trusted workout can persist session, progress, event, medal and achievement',
        () async {
          final ownerId = ownerClient.uid!;
          const sessionId = 'session_release_flow';
          final startedAt = DateTime.utc(2026, 8, 6, 20, 58);
          final endedAt = DateTime.utc(2026, 8, 6, 21);
          final sessionData = _validSessionData(ownerId: ownerId, id: sessionId)
            ..['exerciseType'] = 'push_up'
            ..['startedAt'] = startedAt
            ..['endedAt'] = endedAt
            ..['durationSeconds'] = 120
            ..['totalReps'] = 12
            ..['validReps'] = 12
            ..['lowConfidenceReps'] = 0
            ..['invalidReps'] = 0
            ..['measurementQuality'] = 'high'
            ..['averageMeasurementConfidence'] = 0.94
            ..['measurementSampleCount'] = 12
            ..['createdAt'] = startedAt
            ..['updatedAt'] = endedAt;
          final contribution = _validProgressContributionData(
            ownerId: ownerId,
            sessionId: sessionId,
          );
          final eventId = 'controlled-tempo:$sessionId';
          final event = _validAchievementEventData(
            ownerId: ownerId,
            eventId: eventId,
            type: 'controlledTempoSession',
            subjectId: sessionId,
          );
          final medal = _validChallengeMedalRewardData(ownerId: ownerId)
            ..['timezoneOffsetMinutes'] = 180
            ..['progressValueAtHighestTier'] = 12
            ..['qualifyingEventId'] = sessionId;
          final achievement = _validAchievementRewardData(
            ownerId: ownerId,
            achievementId: 'controlled_tempo',
            qualifyingEventId: eventId,
          );

          final writes = <({String path, Map<String, Object?> data})>[
            (path: _sessionPath(ownerId, sessionId), data: sessionData),
            (
              path: _progressContributionPath(ownerId, sessionId),
              data: contribution,
            ),
            (
              path: _activityDayPath(ownerId, '2026-08-07'),
              data: _validActivityDayData(ownerId: ownerId),
            ),
            (path: _achievementEventPath(ownerId, eventId), data: event),
            (path: _rewardPath(ownerId, _dailyPushUpRewardId), data: medal),
            (
              path: _rewardPath(ownerId, 'achievement:controlled_tempo'),
              data: achievement,
            ),
          ];

          for (final write in writes) {
            final response = await ownerClient.setDocument(
              write.path,
              write.data,
            );
            expect(
              response.statusCode,
              inInclusiveRange(200, 299),
              reason: '${write.path}: ${response.body}',
            );
          }

          for (final write in writes) {
            final response = await ownerClient.getDocument(write.path);
            expect(response.statusCode, 200, reason: write.path);
          }
        },
      );
    },
  );
}

Future<void> _createSession(_RulesClient client) async {
  final response = await client.setDocument(
    _sessionPath(client.uid!, 'session_a'),
    _validSessionData(ownerId: client.uid!, id: 'session_a'),
  );

  expect(
    response.statusCode,
    inInclusiveRange(200, 299),
    reason: response.body,
  );
}

Future<void> _createRep(_RulesClient client) async {
  final response = await client.setDocument(
    _repPath(client.uid!, 'session_a', 'rep_0001'),
    _validRepData(ownerId: client.uid!, sessionId: 'session_a', id: 'rep_0001'),
  );

  expect(
    response.statusCode,
    inInclusiveRange(200, 299),
    reason: response.body,
  );
}

Future<void> _clearEmulators() async {
  final firestoreResponse = await _sendRequest(
    method: 'DELETE',
    uri: Uri.parse(
      'http://$_firestoreHost/emulator/v1/projects/$_projectId/databases/(default)/documents',
    ),
  );
  final authResponse = await _sendRequest(
    method: 'DELETE',
    uri: Uri.parse(
      'http://$_authHost/emulator/v1/projects/$_projectId/accounts',
    ),
  );

  expect(
    firestoreResponse.statusCode,
    inInclusiveRange(200, 299),
    reason: firestoreResponse.body,
  );
  expect(
    authResponse.statusCode,
    inInclusiveRange(200, 299),
    reason: authResponse.body,
  );
}

String _goalPath(String ownerId, String goalId) {
  return 'users/$ownerId/goals/$goalId';
}

Map<String, Object?> _validGoalData({
  required String ownerId,
  required String type,
  required String period,
  required num targetValue,
  String status = 'active',
}) {
  final now = DateTime.utc(2026, 8, 5, 12);

  return <String, Object?>{
    'id': type,
    'ownerId': ownerId,
    'type': type,
    'period': period,
    'targetValue': targetValue,
    'status': status,
    'createdAt': now,
    'updatedAt': now,
  };
}

String _progressContributionPath(String ownerId, String sessionId) {
  return 'users/$ownerId/progressContributions/$sessionId';
}

String _activityDayPath(String ownerId, String localDate) {
  return 'users/$ownerId/activityDays/$localDate';
}

String _achievementEventPath(String ownerId, String eventId) {
  return 'users/$ownerId/achievementEvents/$eventId';
}

Map<String, Object?> _validAchievementEventData({
  required String ownerId,
  required String eventId,
  required String type,
  required String subjectId,
}) {
  final occurredAt = DateTime.utc(2026, 8, 7, 8);
  return <String, Object?>{
    'id': eventId,
    'ownerId': ownerId,
    'type': type,
    'subjectId': subjectId,
    'occurredAt': occurredAt,
    'localDate': '2026-08-07',
    'timezoneOffsetMinutes': 180,
    'createdAt': occurredAt.add(const Duration(minutes: 1)),
  };
}

const String _dailyPushUpRewardId = 'medal:push_up_volume:daily:2026-08-07';

String _rewardPath(String ownerId, String rewardId) {
  return 'users/$ownerId/rewards/$rewardId';
}

Map<String, Object?> _validChallengeMedalRewardData({required String ownerId}) {
  final earnedAt = DateTime.utc(2026, 8, 7, 8);
  return <String, Object?>{
    'schemaVersion': 1,
    'id': _dailyPushUpRewardId,
    'ownerId': ownerId,
    'kind': 'challengeMedal',
    'challengeId': 'push_up_volume',
    'catalogVersion': 1,
    'exerciseType': 'push_up',
    'metric': 'validRepetitions',
    'period': 'daily',
    'periodKey': '2026-08-07',
    'timezoneOffsetMinutes': 0,
    'highestTier': 'bronze',
    'progressValueAtHighestTier': 10,
    'thresholdsAtAward': <String, Object?>{
      'bronze': 10,
      'silver': 20,
      'gold': 30,
    },
    'tierEarnedAt': <String, Object?>{'bronze': earnedAt},
    'firstEarnedAt': earnedAt,
    'highestTierEarnedAt': earnedAt,
    'historyAt': earnedAt,
    'qualifyingEventId': 'session_a',
    'isBackfilled': false,
    'createdAt': earnedAt,
    'updatedAt': earnedAt,
  };
}

Map<String, Object?> _validAchievementRewardData({
  required String ownerId,
  String achievementId = 'first_reliable_analysis',
  String qualifyingEventId = 'session_a',
}) {
  final unlockedAt = DateTime.utc(2026, 8, 7, 8);
  return <String, Object?>{
    'schemaVersion': 1,
    'id': 'achievement:$achievementId',
    'ownerId': ownerId,
    'kind': 'achievement',
    'achievementId': achievementId,
    'definitionVersion': 1,
    'unlockedAt': unlockedAt,
    'historyAt': unlockedAt,
    'qualifyingEventId': qualifyingEventId,
    'isBackfilled': false,
    'createdAt': unlockedAt,
    'updatedAt': unlockedAt,
  };
}

Map<String, Object?> _validProgressContributionData({
  required String ownerId,
  required String sessionId,
}) {
  final endedAt = DateTime.utc(2026, 8, 6, 21);
  final createdAt = endedAt.add(const Duration(minutes: 1));
  return <String, Object?>{
    'id': sessionId,
    'ownerId': ownerId,
    'challengeId': 'push_up_volume',
    'catalogVersion': 1,
    'exerciseType': 'push_up',
    'metric': 'validRepetitions',
    'evidenceQuality': 'high',
    'value': 12,
    'endedAt': endedAt,
    'timezoneOffsetMinutes': 180,
    'localDate': '2026-08-07',
    'createdAt': createdAt,
    'updatedAt': createdAt,
  };
}

Map<String, Object?> _validActivityDayData({required String ownerId}) {
  final createdAt = DateTime.utc(2026, 8, 6, 21, 1);
  return <String, Object?>{
    'id': '2026-08-07',
    'ownerId': ownerId,
    'localDate': '2026-08-07',
    'trustedSessionCount': 1,
    'highReliabilitySessionCount': 1,
    'validRepsByExercise': <String, Object?>{'push_up': 12},
    'holdSecondsByExercise': <String, Object?>{},
    'exerciseTypes': <String>['push_up'],
    'createdAt': createdAt,
    'updatedAt': createdAt,
  };
}

String _sessionPath(String ownerId, String sessionId) {
  return 'users/$ownerId/sessions/$sessionId';
}

String _repPath(String ownerId, String sessionId, String repId) {
  return 'users/$ownerId/sessions/$sessionId/reps/$repId';
}

Map<String, Object?> _validSessionData({
  required String ownerId,
  required String id,
}) {
  final now = DateTime.utc(2026, 1, 1, 12);

  return <String, Object?>{
    'id': id,
    'ownerId': ownerId,
    'exerciseType': 'squat',
    'analysisKind': 'rangeRep',
    'startedAt': now,
    'endedAt': now.add(const Duration(minutes: 10)),
    'durationSeconds': 600,
    'totalReps': 12,
    'validReps': 10,
    'lowConfidenceReps': 1,
    'invalidReps': 1,
    'averageScore': 82.5,
    'bestScore': 95.0,
    'worstScore': 70.0,
    'formWarningCount': 2,
    'holdDurationSeconds': 0.0,
    'bestHoldSeconds': 0.0,
    'holdFormBreakCount': 0,
    'preparationOutcome': 'passed',
    'measurementQuality': 'moderate',
    'averageMeasurementConfidence': 0.86,
    'measurementSampleCount': 11,
    'timezoneOffsetMinutes': 180,
    'createdAt': now,
    'updatedAt': now.add(const Duration(minutes: 10)),
  };
}

Map<String, Object?> _productionSessionData({
  required String ownerId,
  required String id,
}) {
  final startedAt = DateTime.utc(2026, 8, 2, 11, 16, 16, 688, 252);
  final endedAt = DateTime.utc(2026, 8, 2, 11, 16, 34, 899, 764);
  final createdAt = DateTime.utc(2026, 8, 2, 11, 16, 34, 909, 724);

  return <String, Object?>{
    'id': id,
    'ownerId': ownerId,
    'exerciseType': 'squat',
    'analysisKind': 'rangeRep',
    'startedAt': startedAt,
    'endedAt': endedAt,
    'durationSeconds': 18,
    'totalReps': 2,
    'validReps': 2,
    'lowConfidenceReps': 0,
    'invalidReps': 0,
    'averageScore': 83.86666666666667,
    'bestScore': 90.8,
    'worstScore': 76.93333333333334,
    'formWarningCount': 0,
    'holdDurationSeconds': 0.0,
    'bestHoldSeconds': 0.0,
    'holdFormBreakCount': 0,
    'preparationOutcome': 'passed',
    'measurementQuality': 'high',
    'averageMeasurementConfidence': 0.94,
    'measurementSampleCount': 2,
    'timezoneOffsetMinutes': 180,
    'createdAt': createdAt,
    'updatedAt': createdAt,
  };
}

Map<String, Object?> _productionRepData({
  required String ownerId,
  required String sessionId,
  required String id,
  required int repIndex,
  required double score,
  required double durationSeconds,
  required int descentMillis,
  required int ascentMillis,
  required String tempoQuality,
  required List<String> tempoReasons,
  required double confidence,
}) {
  final endedAt = DateTime.utc(2026, 8, 2, 11, 16, 26 + repIndex * 4);

  return <String, Object?>{
    'id': id,
    'ownerId': ownerId,
    'sessionId': sessionId,
    'exerciseType': 'squat',
    'analysisKind': 'rangeRep',
    'repIndex': repIndex,
    'score': score,
    'isValid': true,
    'validationStatus': 'valid',
    'invalidReason': null,
    'validationReasons': const <String>[],
    'endedAt': endedAt,
    'durationSeconds': durationSeconds,
    'minPrimaryMetric': 56.296195603296475,
    'worstFormMetric': 65.87748853136596,
    'descentMillis': descentMillis,
    'ascentMillis': ascentMillis,
    'hadFormViolation': false,
    'hadCoverageDrop': false,
    'switchedSideDuringRep': false,
    'completedPhaseSequence': true,
    'selectedSide': 'left',
    'measurementConfidence': <String, Object?>{
      'landmarkLikelihood': 0.9953839961363344,
      'signalAvailability': 1.0,
      'geometryPlausibility': 1.0,
      'temporalContinuity': 0.9165476994411055,
      'combined': confidence,
      'issues': const <String>[],
    },
    'confidence': confidence,
    'primaryRom': 85.68277770450246,
    'eccentricMillis': descentMillis,
    'concentricMillis': ascentMillis,
    'tempoMeasurementStatus': 'eligible',
    'tempoMeasurementIssues': const <String>[],
    'tempoQuality': tempoQuality,
    'tempoSeverity': 'mild',
    'tempoReasons': tempoReasons,
    'tempoIncludedInScore': true,
    'tempoTotalMillis': (durationSeconds * 1000).round(),
    'techniqueObservations': const <Map<String, Object?>>[
      <String, Object?>{
        'code': 'squat_torso_drift_observed',
        'type': 'torsoDrift',
        'severity': 'info',
        'phase': 'peak',
        'referencePhase': 'descending',
        'measuredValue': 18.0,
        'referenceValue': 14.0,
      },
      <String, Object?>{
        'code': 'squat_torso_drift_observed',
        'type': 'torsoDrift',
        'severity': 'info',
        'phase': 'ascending',
        'referencePhase': 'peak',
        'measuredValue': 1.0,
        'referenceValue': 18.0,
      },
    ],
    'coverageQuality': 1.0,
    'feedback': 'Rep completed!',
    'createdAt': endedAt,
  };
}

Map<String, Object?> _validMeasurementConfidenceData() {
  return <String, Object?>{
    'landmarkLikelihood': 0.98,
    'signalAvailability': 1.0,
    'geometryPlausibility': 1.0,
    'temporalContinuity': 0.76,
    'combined': 0.89,
    'issues': const <String>['temporal_discontinuity'],
  };
}

Map<String, Object?> _validRepData({
  required String ownerId,
  required String sessionId,
  required String id,
  int repIndex = 1,
  double? score = 87.5,
  double? durationSeconds = 1.4,
}) {
  final endedAt = DateTime.utc(2026, 1, 1, 12, 0, 3);

  return <String, Object?>{
    'id': id,
    'ownerId': ownerId,
    'sessionId': sessionId,
    'exerciseType': 'squat',
    'analysisKind': 'rangeRep',
    'repIndex': repIndex,
    'score': score,
    'isValid': true,
    'validationStatus': 'valid',
    'validationReasons': const <String>[],
    'endedAt': endedAt,
    'durationSeconds': durationSeconds,
    'minPrimaryMetric': 94.0,
    'worstFormMetric': 42.0,
    'descentMillis': 620,
    'ascentMillis': 540,
    'hadFormViolation': false,
    'hadCoverageDrop': false,
    'switchedSideDuringRep': false,
    'completedPhaseSequence': true,
    'selectedSide': 'right',
    'feedback': 'Kontrol iyi',
    'createdAt': endedAt,
  };
}

class _RulesClient {
  const _RulesClient({this.idToken, this.uid});

  final String? idToken;
  final String? uid;

  static Future<_RulesClient> signUp() async {
    final response = await _sendRequest(
      method: 'POST',
      uri: Uri.parse(
        'http://$_authHost/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key',
      ),
      body: <String, Object?>{'returnSecureToken': true},
    );

    expect(response.statusCode, 200, reason: response.body);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _RulesClient(
      idToken: decoded['idToken'] as String,
      uid: decoded['localId'] as String,
    );
  }

  Future<_RestResponse> getDocument(String path) {
    return _sendRequest(
      method: 'GET',
      uri: Uri.parse(
        'http://$_firestoreHost/v1/projects/$_projectId/databases/(default)/documents/$path',
      ),
      idToken: idToken,
    );
  }

  Future<_RestResponse> setDocument(String path, Map<String, Object?> data) {
    return _sendRequest(
      method: 'PATCH',
      uri: Uri.parse(
        'http://$_firestoreHost/v1/projects/$_projectId/databases/(default)/documents/$path',
      ),
      idToken: idToken,
      body: <String, Object?>{'fields': _encodeFields(data)},
    );
  }

  Future<_RestResponse> deleteDocument(String path) {
    return _sendRequest(
      method: 'DELETE',
      uri: Uri.parse(
        'http://$_firestoreHost/v1/projects/$_projectId/databases/(default)/documents/$path',
      ),
      idToken: idToken,
    );
  }
}

Future<_RestResponse> _sendRequest({
  required String method,
  required Uri uri,
  String? idToken,
  Object? body,
}) async {
  final client = HttpClient();

  try {
    final request = await client.openUrl(method, uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    if (idToken != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
    }
    if (body != null) {
      request.add(utf8.encode(jsonEncode(body)));
    }

    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);
    return _RestResponse(response.statusCode, responseBody);
  } finally {
    client.close(force: true);
  }
}

Map<String, Object?> _encodeFields(Map<String, Object?> data) {
  return data.map(
    (key, value) => MapEntry<String, Object?>(key, _encodeValue(value)),
  );
}

Map<String, Object?> _encodeValue(Object? value) {
  if (value == null) {
    return <String, Object?>{'nullValue': null};
  }
  if (value is bool) {
    return <String, Object?>{'booleanValue': value};
  }
  if (value is int) {
    return <String, Object?>{'integerValue': value.toString()};
  }
  if (value is double) {
    return <String, Object?>{'doubleValue': value};
  }
  if (value is String) {
    return <String, Object?>{'stringValue': value};
  }
  if (value is DateTime) {
    return <String, Object?>{'timestampValue': value.toUtc().toIso8601String()};
  }
  if (value is Map) {
    final fields = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw UnsupportedError('Unsupported Firestore map key: $key');
      }
      fields[key] = entry.value;
    }
    return <String, Object?>{
      'mapValue': <String, Object?>{'fields': _encodeFields(fields)},
    };
  }
  if (value is List) {
    return <String, Object?>{
      'arrayValue': <String, Object?>{
        'values': value.map(_encodeValue).toList(growable: false),
      },
    };
  }

  throw UnsupportedError('Unsupported Firestore test value: $value');
}

class _RestResponse {
  const _RestResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}
