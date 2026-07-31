import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_tempo_voice_confirmation_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';

void main() {
  group('RangeRepTempoVoiceConfirmationPolicy', () {
    test('keeps the first tempo caution visual-only', () {
      final policy = RangeRepTempoVoiceConfirmationPolicy();

      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.lowConfidence,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.excessiveDescentSpeed,
          ],
        ),
        isFalse,
      );
    });

    test('keeps repeated tempo outcomes silent while quarantine is active', () {
      final policy = RangeRepTempoVoiceConfirmationPolicy();

      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.lowConfidence,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.excessiveAscentSpeed,
          ],
        ),
        isFalse,
      );
      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.lowConfidence,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.excessiveAscentSpeed,
          ],
        ),
        isFalse,
      );
    });

    test('keeps repeated invalid tempo outcomes visual-only', () {
      final policy = RangeRepTempoVoiceConfirmationPolicy();

      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.invalid,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.excessiveRepSpeed,
          ],
        ),
        isFalse,
      );
      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.invalid,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.excessiveRepSpeed,
          ],
        ),
        isFalse,
      );
    });

    test('can opt into consecutive tempo confirmation for V2 validation', () {
      final policy = RangeRepTempoVoiceConfirmationPolicy(
        tempoAnnouncementsEnabled: true,
      );

      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.lowConfidence,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.excessiveAscentSpeed,
          ],
        ),
        isFalse,
      );
      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.lowConfidence,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.excessiveAscentSpeed,
          ],
        ),
        isTrue,
      );
    });

    test(
      'does not combine different tempo directions when opt-in is enabled',
      () {
        final policy = RangeRepTempoVoiceConfirmationPolicy(
          tempoAnnouncementsEnabled: true,
        );

        expect(
          policy.shouldAnnounce(
            status: RangeRepValidationStatus.lowConfidence,
            reasons: const <RangeRepValidationReason>[
              RangeRepValidationReason.excessiveDescentSpeed,
            ],
          ),
          isFalse,
        );
        expect(
          policy.shouldAnnounce(
            status: RangeRepValidationStatus.lowConfidence,
            reasons: const <RangeRepValidationReason>[
              RangeRepValidationReason.excessiveAscentSpeed,
            ],
          ),
          isFalse,
        );
      },
    );

    test('keeps measurement-quality cautions visual-only', () {
      final policy = RangeRepTempoVoiceConfirmationPolicy();

      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.lowConfidence,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.coverageLoss,
          ],
        ),
        isFalse,
      );
    });

    test('delivers technique outcomes immediately', () {
      final policy = RangeRepTempoVoiceConfirmationPolicy();

      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.lowConfidence,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.persistentFormBreak,
          ],
        ),
        isTrue,
      );
      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.invalid,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.insufficientRom,
          ],
        ),
        isTrue,
      );
    });

    test(
      'does not let a quarantined tempo reason suppress technique feedback',
      () {
        final policy = RangeRepTempoVoiceConfirmationPolicy();

        expect(
          policy.shouldAnnounce(
            status: RangeRepValidationStatus.invalid,
            reasons: const <RangeRepValidationReason>[
              RangeRepValidationReason.insufficientRom,
              RangeRepValidationReason.excessiveRepSpeed,
            ],
          ),
          isTrue,
        );
      },
    );

    test('a clean rep resets pending tempo confirmation', () {
      final policy = RangeRepTempoVoiceConfirmationPolicy(
        tempoAnnouncementsEnabled: true,
      );

      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.lowConfidence,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.excessiveRepSpeed,
          ],
        ),
        isFalse,
      );
      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.valid,
          reasons: const <RangeRepValidationReason>[],
        ),
        isTrue,
      );
      expect(
        policy.shouldAnnounce(
          status: RangeRepValidationStatus.lowConfidence,
          reasons: const <RangeRepValidationReason>[
            RangeRepValidationReason.excessiveRepSpeed,
          ],
        ),
        isFalse,
      );
    });
  });
}
