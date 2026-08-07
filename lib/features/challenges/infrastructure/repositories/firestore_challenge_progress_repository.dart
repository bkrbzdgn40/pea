import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_paths.dart';
import '../../application/repositories/challenge_progress_repository.dart';
import '../../domain/models/activity_day_summary.dart';
import '../../domain/models/challenge_contribution.dart';
import '../../domain/models/challenge_contribution_record.dart';
import '../../domain/models/challenge_progress_mutation.dart';
import '../mappers/activity_day_summary_firestore_mapper.dart';
import '../mappers/challenge_contribution_firestore_mapper.dart';

class FirestoreChallengeProgressRepository
    implements ChallengeProgressRepository {
  FirestoreChallengeProgressRepository(
    this._firestore, {
    ChallengeContributionFirestoreMapper contributionMapper =
        const ChallengeContributionFirestoreMapper(),
    ActivityDaySummaryFirestoreMapper activityDayMapper =
        const ActivityDaySummaryFirestoreMapper(),
  }) : _contributionMapper = contributionMapper,
       _activityDayMapper = activityDayMapper;

  final FirebaseFirestore _firestore;
  final ChallengeContributionFirestoreMapper _contributionMapper;
  final ActivityDaySummaryFirestoreMapper _activityDayMapper;

  @override
  Future<ChallengeContributionWriteResult> upsertContribution({
    required String ownerId,
    required ChallengeContribution contribution,
    required DateTime now,
  }) {
    _validateOwnerId(ownerId);
    final nowUtc = now.toUtc();
    final contributionReference = _contributionDocument(
      ownerId,
      contribution.sessionId,
    );

    return _firestore.runTransaction((transaction) async {
      final existingSnapshot = await transaction.get(contributionReference);
      final existing = existingSnapshot.exists
          ? _decodeContribution(existingSnapshot, expectedOwnerId: ownerId)
          : null;

      if (existing != null &&
          existing.contribution.hasSamePayloadAs(contribution)) {
        final dayReference = _activityDayDocument(ownerId, existing.localDate);
        final daySnapshot = await transaction.get(dayReference);
        if (!daySnapshot.exists) {
          throw StateError(
            'Missing activity day for contribution ${existing.id}.',
          );
        }
        final day = _decodeActivityDay(daySnapshot, expectedOwnerId: ownerId);
        day.removeContribution(existing.contribution, now: day.updatedAtUtc);
        return ChallengeContributionWriteResult(
          status: ChallengeContributionWriteStatus.unchanged,
          affectedLocalDates: <String>{existing.localDate},
        );
      }

      final newLocalDate = contribution.dailyWindow.key;
      final newDayReference = _activityDayDocument(ownerId, newLocalDate);

      if (existing == null) {
        final newDaySnapshot = await transaction.get(newDayReference);
        final currentDay = newDaySnapshot.exists
            ? _decodeActivityDay(newDaySnapshot, expectedOwnerId: ownerId)
            : null;
        final updatedDay = currentDay == null
            ? ActivityDaySummary.fromContribution(
                ownerId: ownerId,
                contribution: contribution,
                now: nowUtc,
              )
            : currentDay.addContribution(contribution, now: nowUtc);
        final record = ChallengeContributionRecord(
          ownerId: ownerId,
          contribution: contribution,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        );

        transaction.set(
          newDayReference,
          _activityDayMapper.toDocument(updatedDay),
        );
        transaction.set(
          contributionReference,
          _contributionMapper.toDocument(record),
        );
        return ChallengeContributionWriteResult(
          status: ChallengeContributionWriteStatus.created,
          affectedLocalDates: <String>{newLocalDate},
        );
      }

      final oldLocalDate = existing.localDate;
      if (oldLocalDate == newLocalDate) {
        final daySnapshot = await transaction.get(newDayReference);
        if (!daySnapshot.exists) {
          throw StateError(
            'Missing activity day for contribution ${existing.id}.',
          );
        }
        final currentDay = _decodeActivityDay(
          daySnapshot,
          expectedOwnerId: ownerId,
        );
        final updatedDay = currentDay
            .removeContribution(existing.contribution, now: nowUtc)
            .addContribution(contribution, now: nowUtc);
        final record = ChallengeContributionRecord(
          ownerId: ownerId,
          contribution: contribution,
          createdAt: existing.createdAtUtc,
          updatedAt: _notBefore(nowUtc, existing.updatedAtUtc),
        );

        transaction.set(
          newDayReference,
          _activityDayMapper.toDocument(updatedDay),
        );
        transaction.set(
          contributionReference,
          _contributionMapper.toDocument(record),
        );
        return ChallengeContributionWriteResult(
          status: ChallengeContributionWriteStatus.replaced,
          affectedLocalDates: <String>{newLocalDate},
        );
      }

      final oldDayReference = _activityDayDocument(ownerId, oldLocalDate);
      final oldDaySnapshot = await transaction.get(oldDayReference);
      final newDaySnapshot = await transaction.get(newDayReference);
      if (!oldDaySnapshot.exists) {
        throw StateError(
          'Missing activity day for contribution ${existing.id}.',
        );
      }

      final oldDay = _decodeActivityDay(
        oldDaySnapshot,
        expectedOwnerId: ownerId,
      );
      final reducedOldDay = oldDay.removeContribution(
        existing.contribution,
        now: nowUtc,
      );
      final currentNewDay = newDaySnapshot.exists
          ? _decodeActivityDay(newDaySnapshot, expectedOwnerId: ownerId)
          : null;
      final updatedNewDay = currentNewDay == null
          ? ActivityDaySummary.fromContribution(
              ownerId: ownerId,
              contribution: contribution,
              now: nowUtc,
            )
          : currentNewDay.addContribution(contribution, now: nowUtc);
      final record = ChallengeContributionRecord(
        ownerId: ownerId,
        contribution: contribution,
        createdAt: existing.createdAtUtc,
        updatedAt: _notBefore(nowUtc, existing.updatedAtUtc),
      );

      if (reducedOldDay.isEmpty) {
        transaction.delete(oldDayReference);
      } else {
        transaction.set(
          oldDayReference,
          _activityDayMapper.toDocument(reducedOldDay),
        );
      }
      transaction.set(
        newDayReference,
        _activityDayMapper.toDocument(updatedNewDay),
      );
      transaction.set(
        contributionReference,
        _contributionMapper.toDocument(record),
      );
      return ChallengeContributionWriteResult(
        status: ChallengeContributionWriteStatus.replaced,
        affectedLocalDates: <String>{oldLocalDate, newLocalDate},
      );
    });
  }

  @override
  Future<bool> removeContribution({
    required String ownerId,
    required String sessionId,
    required DateTime now,
  }) {
    _validateOwnerId(ownerId);
    _validateDocumentId(sessionId, 'sessionId');
    final contributionReference = _contributionDocument(ownerId, sessionId);
    final nowUtc = now.toUtc();

    return _firestore.runTransaction((transaction) async {
      final contributionSnapshot = await transaction.get(contributionReference);
      if (!contributionSnapshot.exists) {
        return false;
      }
      final record = _decodeContribution(
        contributionSnapshot,
        expectedOwnerId: ownerId,
      );
      final dayReference = _activityDayDocument(ownerId, record.localDate);
      final daySnapshot = await transaction.get(dayReference);
      if (!daySnapshot.exists) {
        throw StateError('Missing activity day for contribution $sessionId.');
      }
      final day = _decodeActivityDay(daySnapshot, expectedOwnerId: ownerId);
      final updatedDay = day.removeContribution(
        record.contribution,
        now: nowUtc,
      );

      if (updatedDay.isEmpty) {
        transaction.delete(dayReference);
      } else {
        transaction.set(
          dayReference,
          _activityDayMapper.toDocument(updatedDay),
        );
      }
      transaction.delete(contributionReference);
      return true;
    });
  }

  @override
  Future<List<ChallengeContributionRecord>> listContributions({
    required String ownerId,
  }) async {
    _validateOwnerId(ownerId);
    final snapshot = await _contributionsCollection(
      ownerId,
    ).orderBy('endedAt').get();
    return snapshot.docs
        .map(
          (document) => _decodeContribution(document, expectedOwnerId: ownerId),
        )
        .toList(growable: false);
  }

  @override
  Future<ChallengeContributionRecord?> getContribution({
    required String ownerId,
    required String sessionId,
  }) async {
    _validateOwnerId(ownerId);
    _validateDocumentId(sessionId, 'sessionId');
    final snapshot = await _contributionDocument(ownerId, sessionId).get();
    if (!snapshot.exists) {
      return null;
    }
    return _decodeContribution(snapshot, expectedOwnerId: ownerId);
  }

  @override
  Future<ActivityDaySummary?> getActivityDay({
    required String ownerId,
    required String localDate,
  }) async {
    _validateOwnerId(ownerId);
    _validateLocalDate(localDate, 'localDate');
    final snapshot = await _activityDayDocument(ownerId, localDate).get();
    if (!snapshot.exists) {
      return null;
    }
    return _decodeActivityDay(snapshot, expectedOwnerId: ownerId);
  }

  @override
  Future<List<ActivityDaySummary>> listActivityDays({
    required String ownerId,
    required String startLocalDateInclusive,
    required String endLocalDateExclusive,
  }) async {
    _validateOwnerId(ownerId);
    _validateLocalDate(startLocalDateInclusive, 'startLocalDateInclusive');
    _validateLocalDate(endLocalDateExclusive, 'endLocalDateExclusive');
    if (startLocalDateInclusive.compareTo(endLocalDateExclusive) >= 0) {
      throw ArgumentError('Activity day range must be increasing.');
    }

    final snapshot = await _activityDaysCollection(ownerId)
        .where('localDate', isGreaterThanOrEqualTo: startLocalDateInclusive)
        .where('localDate', isLessThan: endLocalDateExclusive)
        .orderBy('localDate')
        .get();
    return snapshot.docs
        .map(
          (document) => _decodeActivityDay(document, expectedOwnerId: ownerId),
        )
        .toList(growable: false);
  }

  ChallengeContributionRecord _decodeContribution(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required String expectedOwnerId,
  }) {
    final record = _contributionMapper.fromDocument(
      documentId: snapshot.id,
      data: snapshot.data()!,
    );
    if (record.ownerId != expectedOwnerId) {
      throw const FormatException(
        'Contribution owner does not match its path.',
      );
    }
    return record;
  }

  ActivityDaySummary _decodeActivityDay(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required String expectedOwnerId,
  }) {
    final day = _activityDayMapper.fromDocument(
      documentId: snapshot.id,
      data: snapshot.data()!,
    );
    if (day.ownerId != expectedOwnerId) {
      throw const FormatException(
        'Activity day owner does not match its path.',
      );
    }
    return day;
  }

  CollectionReference<Map<String, dynamic>> _contributionsCollection(
    String ownerId,
  ) {
    return _firestore.collection(
      FirestorePaths.userProgressContributions(ownerId),
    );
  }

  DocumentReference<Map<String, dynamic>> _contributionDocument(
    String ownerId,
    String sessionId,
  ) {
    return _firestore.doc(
      FirestorePaths.userProgressContributionDoc(ownerId, sessionId),
    );
  }

  CollectionReference<Map<String, dynamic>> _activityDaysCollection(
    String ownerId,
  ) {
    return _firestore.collection(FirestorePaths.userActivityDays(ownerId));
  }

  DocumentReference<Map<String, dynamic>> _activityDayDocument(
    String ownerId,
    String localDate,
  ) {
    return _firestore.doc(
      FirestorePaths.userActivityDayDoc(ownerId, localDate),
    );
  }
}

void _validateOwnerId(String ownerId) {
  _validateDocumentId(ownerId, 'ownerId');
}

void _validateLocalDate(String value, String name) {
  if (!isValidActivityLocalDate(value)) {
    throw ArgumentError.value(value, name, 'Expected a real YYYY-MM-DD date.');
  }
}

void _validateDocumentId(String value, String name) {
  if (value.isEmpty || value.contains('/')) {
    throw ArgumentError.value(
      value,
      name,
      'Must be a non-empty Firestore document id.',
    );
  }
}

DateTime _notBefore(DateTime candidate, DateTime floor) {
  final candidateUtc = candidate.toUtc();
  final floorUtc = floor.toUtc();
  return candidateUtc.isBefore(floorUtc) ? floorUtc : candidateUtc;
}
