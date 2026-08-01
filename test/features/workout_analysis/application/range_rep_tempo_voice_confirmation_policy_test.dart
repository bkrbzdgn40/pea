import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_tempo_voice_confirmation_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/rep_tempo_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/tempo_measurement_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/tempo_engine.dart';

void main() {
  group('RangeRepTempoVoiceConfirmationPolicy', () {
    test('requires two matching eligible fast outcomes', () {
      final policy = RangeRepTempoVoiceConfirmationPolicy(
        tempoAnnouncementsEnabled: true,
      );
      final assessment = _assessment(RepTempoQuality.tooFast);

      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.valid,
          reasons: const <RangeRepValidationReason>[],
          tempoAssessment: assessment,
        ),
        isFalse,
      );
      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.valid,
          reasons: const <RangeRepValidationReason>[],
          tempoAssessment: assessment,
        ),
        isTrue,
      );
    });

    test('does not combine fast and slow outcomes', () {
      final policy = RangeRepTempoVoiceConfirmationPolicy(
        tempoAnnouncementsEnabled: true,
      );

      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.valid,
          reasons: const <RangeRepValidationReason>[],
          tempoAssessment: _assessment(RepTempoQuality.tooFast),
        ),
        isFalse,
      );
      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.valid,
          reasons: const <RangeRepValidationReason>[],
          tempoAssessment: _assessment(RepTempoQuality.tooSlow),
        ),
        isFalse,
      );
    });

    test('keeps unavailable measurement silent', () {
      final policy = RangeRepTempoVoiceConfirmationPolicy(
        tempoAnnouncementsEnabled: true,
      );

      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.valid,
          reasons: const <RangeRepValidationReason>[],
          tempoAssessment: _assessment(RepTempoQuality.unavailable),
        ),
        isFalse,
      );
    });

    test('delivers technique outcomes immediately', () {
      final policy = RangeRepTempoVoiceConfirmationPolicy(
        tempoAnnouncementsEnabled: true,
      );

      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.lowConfidence,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.persistentFormBreak,
          ],
          tempoAssessment: _assessment(RepTempoQuality.tooFast),
        ),
        isTrue,
      );
    });

    test('keeps measurement-quality cautions visual-only', () {
      final policy = RangeRepTempoVoiceConfirmationPolicy(
        tempoAnnouncementsEnabled: true,
      );

      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.lowConfidence,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.coverageLoss,
          ],
          tempoAssessment: _assessment(RepTempoQuality.tooFast),
        ),
        isFalse,
      );
    });
  });
}

RepTempoAssessment _assessment(RepTempoQuality quality) {
  final measurement = TempoMeasurementAssessment(
    status: quality == RepTempoQuality.unavailable
        ? TempoMeasurementStatus.unavailable
        : TempoMeasurementStatus.eligible,
    issues: quality == RepTempoQuality.unavailable
        ? const <TempoMeasurementIssue>[
            TempoMeasurementIssue.visibilityInterrupted,
          ]
        : const <TempoMeasurementIssue>[],
    measuredTempo: const TempoRepResult(
      repIndex: 1,
      eccentricDuration: Duration(milliseconds: 600),
      bottomPauseDuration: Duration.zero,
      concentricDuration: Duration(milliseconds: 600),
      topPauseDuration: Duration.zero,
      totalRepDuration: Duration(milliseconds: 1200),
      towardPeakDuration: Duration(milliseconds: 600),
      returnDuration: Duration(milliseconds: 600),
    ),
    trace: null,
  );
  return RepTempoAssessment(
    quality: quality,
    severity:
        quality == RepTempoQuality.target ||
            quality == RepTempoQuality.unavailable
        ? RepTempoSeverity.none
        : RepTempoSeverity.mild,
    reasons: switch (quality) {
      RepTempoQuality.tooFast => const <RepTempoReason>[
        RepTempoReason.totalTooFast,
      ],
      RepTempoQuality.tooSlow => const <RepTempoReason>[
        RepTempoReason.totalTooSlow,
      ],
      RepTempoQuality.unavailable => const <RepTempoReason>[
        RepTempoReason.measurementUnavailable,
      ],
      RepTempoQuality.target => const <RepTempoReason>[],
    },
    measurement: measurement,
    coachingEnabled: true,
  );
}
