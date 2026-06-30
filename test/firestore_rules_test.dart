import 'package:flutter_test/flutter_test.dart';

const _rulesEmulatorSkipReason =
    'Rules test skeleton only. Wire this file to the Firestore/Auth emulators '
    'before enabling these checks.';

void main() {
  group('Firestore session security rules', () {
    test(
      'unauthenticated users cannot read session data',
      () {
        expect(_sessionPath('owner-a', 'session-a'), isNotEmpty);
      },
      skip: _rulesEmulatorSkipReason,
    );

    test(
      'users can read their own session data',
      () {
        expect(_sessionPath('owner-a', 'session-a'), contains('owner-a'));
      },
      skip: _rulesEmulatorSkipReason,
    );

    test(
      'users cannot read another user session data',
      () {
        expect(_sessionPath('owner-b', 'session-a'), contains('owner-b'));
      },
      skip: _rulesEmulatorSkipReason,
    );

    test(
      'users can create their own session data',
      () {
        expect(_validSessionData(ownerId: 'owner-a', id: 'session-a'), isMap);
      },
      skip: _rulesEmulatorSkipReason,
    );

    test(
      'users cannot create session data for another owner',
      () {
        final data = _validSessionData(ownerId: 'owner-b', id: 'session-a');

        expect(data['ownerId'], 'owner-b');
      },
      skip: _rulesEmulatorSkipReason,
    );

    test(
      'users cannot change ownerId during update',
      () {
        final original = _validSessionData(ownerId: 'owner-a', id: 'session-a');
        final updated = <String, Object?>{...original, 'ownerId': 'owner-b'};

        expect(updated['ownerId'], isNot(original['ownerId']));
      },
      skip: _rulesEmulatorSkipReason,
    );

    test(
      'users can delete their own session data',
      () {
        expect(_sessionPath('owner-a', 'session-a'), 'users/owner-a/sessions/session-a');
      },
      skip: _rulesEmulatorSkipReason,
    );

    test(
      'users cannot delete another user session data',
      () {
        expect(_sessionPath('owner-b', 'session-a'), 'users/owner-b/sessions/session-a');
      },
      skip: _rulesEmulatorSkipReason,
    );
  });
}

String _sessionPath(String ownerId, String sessionId) {
  return 'users/$ownerId/sessions/$sessionId';
}

Map<String, Object?> _validSessionData({
  required String ownerId,
  required String id,
}) {
  final now = DateTime.utc(2026);

  return <String, Object?>{
    'id': id,
    'ownerId': ownerId,
    'exerciseType': 'squat',
    'startedAt': now,
    'endedAt': now.add(const Duration(minutes: 10)),
    'durationSec': 600,
    'totalReps': 12,
    'averageScore': 82.5,
    'bestScore': 95.0,
    'formWarningCount': 2,
    'createdAt': now,
    'updatedAt': now,
  };
}
