import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_paths.dart';
import '../../application/repositories/achievement_event_repository.dart';
import '../../domain/models/achievement_event.dart';
import '../../domain/models/achievement_event_record.dart';
import '../mappers/achievement_event_firestore_mapper.dart';

class FirestoreAchievementEventRepository
    implements AchievementEventRepository {
  FirestoreAchievementEventRepository(
    this._firestore, {
    AchievementEventFirestoreMapper mapper =
        const AchievementEventFirestoreMapper(),
  }) : _mapper = mapper;

  final FirebaseFirestore _firestore;
  final AchievementEventFirestoreMapper _mapper;

  @override
  Future<AchievementEventWriteResult> recordEvent({
    required String ownerId,
    required AchievementEvent event,
    required Duration timezoneOffset,
    required DateTime now,
  }) {
    _validateDocumentId(ownerId, 'ownerId');
    _validateDocumentId(event.eventId, 'eventId');
    final reference = _eventDocument(ownerId, event.eventId);
    final nowUtc = now.toUtc();
    if (nowUtc.isBefore(event.occurredAtUtc)) {
      throw ArgumentError('now must not precede occurredAt.');
    }
    final localDate = _localDateFor(event.occurredAtUtc, timezoneOffset);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (snapshot.exists) {
        final existing = _decode(snapshot, expectedOwnerId: ownerId);
        if (existing.event.type != event.type ||
            existing.event.subjectId != event.subjectId) {
          throw StateError('Achievement event id collision: ${event.eventId}.');
        }
        return AchievementEventWriteResult(
          status: AchievementEventWriteStatus.unchanged,
          record: existing,
        );
      }

      final record = AchievementEventRecord(
        ownerId: ownerId,
        event: event,
        localDate: localDate,
        timezoneOffset: timezoneOffset,
        createdAt: nowUtc,
      );
      transaction.set(reference, _mapper.toDocument(record));
      return AchievementEventWriteResult(
        status: AchievementEventWriteStatus.created,
        record: record,
      );
    });
  }

  @override
  Future<List<AchievementEventRecord>> listEvents({
    required String ownerId,
  }) async {
    _validateDocumentId(ownerId, 'ownerId');
    final snapshot = await _eventsCollection(
      ownerId,
    ).orderBy('occurredAt').get();
    return snapshot.docs
        .map((document) => _decode(document, expectedOwnerId: ownerId))
        .toList(growable: false);
  }

  AchievementEventRecord _decode(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required String expectedOwnerId,
  }) {
    final record = _mapper.fromDocument(
      documentId: snapshot.id,
      data: snapshot.data()!,
    );
    if (record.ownerId != expectedOwnerId) {
      throw const FormatException('Achievement event owner mismatch.');
    }
    return record;
  }

  CollectionReference<Map<String, dynamic>> _eventsCollection(String ownerId) {
    return _firestore.collection(FirestorePaths.userAchievementEvents(ownerId));
  }

  DocumentReference<Map<String, dynamic>> _eventDocument(
    String ownerId,
    String eventId,
  ) {
    return _firestore.doc(
      FirestorePaths.userAchievementEventDoc(ownerId, eventId),
    );
  }
}

String _localDateFor(DateTime instant, Duration offset) {
  if (offset.abs() > const Duration(hours: 14) || offset.inSeconds % 60 != 0) {
    throw ArgumentError.value(offset, 'timezoneOffset');
  }
  final wall = instant.toUtc().add(offset);
  return '${wall.year.toString().padLeft(4, '0')}-'
      '${wall.month.toString().padLeft(2, '0')}-'
      '${wall.day.toString().padLeft(2, '0')}';
}

void _validateDocumentId(String value, String name) {
  if (value.isEmpty || value.contains('/')) {
    throw ArgumentError.value(value, name, 'Invalid Firestore document id.');
  }
}
