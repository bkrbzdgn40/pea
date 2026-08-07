import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/challenge_contribution.dart';
import '../../domain/models/challenge_contribution_record.dart';
import '../../domain/models/challenge_evidence_quality.dart';
import '../../domain/models/challenge_metric.dart';
import '../../../workout_analysis/domain/models/exercise_type.dart';

class ChallengeContributionFirestoreMapper {
  const ChallengeContributionFirestoreMapper();

  Map<String, Object?> toDocument(ChallengeContributionRecord record) {
    final contribution = record.contribution;
    if (record.id != contribution.sessionId ||
        record.localDate != contribution.dailyWindow.key) {
      throw ArgumentError.value(
        record,
        'record',
        'Invalid contribution record.',
      );
    }

    return <String, Object?>{
      'id': record.id,
      'ownerId': record.ownerId,
      'challengeId': contribution.challengeId,
      'catalogVersion': contribution.catalogVersion,
      'exerciseType': contribution.exerciseType.id,
      'metric': contribution.metric.storageValue,
      'evidenceQuality': contribution.evidenceQuality.storageValue,
      'value': contribution.metric == ChallengeMetric.validRepetitions
          ? contribution.value.toInt()
          : contribution.value,
      'endedAt': Timestamp.fromDate(contribution.endedAtUtc),
      'timezoneOffsetMinutes': contribution.timezoneOffset.inMinutes,
      'localDate': record.localDate,
      'createdAt': Timestamp.fromDate(record.createdAtUtc),
      'updatedAt': Timestamp.fromDate(record.updatedAtUtc),
    };
  }

  ChallengeContributionRecord fromDocument({
    required String documentId,
    required Map<String, Object?> data,
  }) {
    final id = data['id'];
    final ownerId = data['ownerId'];
    final challengeId = data['challengeId'];
    final catalogVersion = data['catalogVersion'];
    final exerciseTypeValue = data['exerciseType'];
    final metricValue = data['metric'];
    final evidenceQualityValue = data['evidenceQuality'];
    final exerciseType = exerciseTypeValue is String
        ? ExerciseType.fromIdOrNull(exerciseTypeValue)
        : null;
    final metric = metricValue is String
        ? ChallengeMetric.tryParse(metricValue)
        : null;
    final evidenceQuality = evidenceQualityValue is String
        ? ChallengeEvidenceQuality.tryParse(evidenceQualityValue)
        : null;
    final value = data['value'];
    final endedAt = data['endedAt'];
    final timezoneOffsetMinutes = data['timezoneOffsetMinutes'];
    final localDate = data['localDate'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];

    if (id is! String ||
        id != documentId ||
        ownerId is! String ||
        ownerId.isEmpty ||
        challengeId is! String ||
        challengeId.isEmpty ||
        catalogVersion is! int ||
        exerciseType == null ||
        metric == null ||
        evidenceQuality == null ||
        value is! num ||
        endedAt is! Timestamp ||
        timezoneOffsetMinutes is! int ||
        localDate is! String ||
        createdAt is! Timestamp ||
        updatedAt is! Timestamp) {
      throw const FormatException('Invalid progress contribution document.');
    }

    try {
      final contribution = ChallengeContribution(
        sessionId: id,
        challengeId: challengeId,
        catalogVersion: catalogVersion,
        exerciseType: exerciseType,
        metric: metric,
        evidenceQuality: evidenceQuality,
        value: value.toDouble(),
        endedAt: endedAt.toDate(),
        timezoneOffset: Duration(minutes: timezoneOffsetMinutes),
      );
      final record = ChallengeContributionRecord(
        ownerId: ownerId,
        contribution: contribution,
        createdAt: createdAt.toDate(),
        updatedAt: updatedAt.toDate(),
      );
      if (record.localDate != localDate) {
        throw const FormatException('Contribution local date is inconsistent.');
      }
      return record;
    } on ArgumentError catch (error) {
      throw FormatException('Invalid progress contribution document: $error');
    }
  }
}
