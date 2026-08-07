import '../../workout_analysis/domain/models/exercise_type.dart';
import 'models/challenge_definition.dart';
import 'models/challenge_period_thresholds.dart';
import 'models/challenge_volume_profile.dart';
import 'models/medal_thresholds.dart';

/// Versioned, product-owned challenge definitions for all supported exercises.
class ChallengeCatalog {
  const ChallengeCatalog();

  static const int version = 1;

  static final Map<ChallengeVolumeProfile, ChallengePeriodThresholds>
  _thresholdsByProfile =
      Map.unmodifiable(<ChallengeVolumeProfile, ChallengePeriodThresholds>{
        ChallengeVolumeProfile.r1LowVolume: ChallengePeriodThresholds(
          daily: MedalThresholds(bronze: 5, silver: 10, gold: 20),
          weekly: MedalThresholds(bronze: 25, silver: 50, gold: 100),
          monthly: MedalThresholds(bronze: 80, silver: 160, gold: 320),
        ),
        ChallengeVolumeProfile.r2Standard: ChallengePeriodThresholds(
          daily: MedalThresholds(bronze: 10, silver: 20, gold: 30),
          weekly: MedalThresholds(bronze: 70, silver: 140, gold: 210),
          monthly: MedalThresholds(bronze: 200, silver: 400, gold: 600),
        ),
        ChallengeVolumeProfile.r3MediumHigh: ChallengePeriodThresholds(
          daily: MedalThresholds(bronze: 15, silver: 30, gold: 50),
          weekly: MedalThresholds(bronze: 100, silver: 200, gold: 350),
          monthly: MedalThresholds(bronze: 300, silver: 600, gold: 1000),
        ),
        ChallengeVolumeProfile.r4HighVolume: ChallengePeriodThresholds(
          daily: MedalThresholds(bronze: 20, silver: 40, gold: 60),
          weekly: MedalThresholds(bronze: 140, silver: 280, gold: 420),
          monthly: MedalThresholds(bronze: 400, silver: 800, gold: 1200),
        ),
        ChallengeVolumeProfile.r5CardioVolume: ChallengePeriodThresholds(
          daily: MedalThresholds(bronze: 25, silver: 50, gold: 100),
          weekly: MedalThresholds(bronze: 175, silver: 350, gold: 700),
          monthly: MedalThresholds(bronze: 500, silver: 1000, gold: 2000),
        ),
        ChallengeVolumeProfile.h1AdvancedShort: ChallengePeriodThresholds(
          daily: MedalThresholds(bronze: 15, silver: 30, gold: 45),
          weekly: MedalThresholds(bronze: 90, silver: 180, gold: 300),
          monthly: MedalThresholds(bronze: 300, silver: 600, gold: 900),
        ),
        ChallengeVolumeProfile.h2SideHold: ChallengePeriodThresholds(
          daily: MedalThresholds(bronze: 20, silver: 40, gold: 60),
          weekly: MedalThresholds(bronze: 120, silver: 240, gold: 360),
          monthly: MedalThresholds(bronze: 400, silver: 800, gold: 1200),
        ),
        ChallengeVolumeProfile.h3StandardHold: ChallengePeriodThresholds(
          daily: MedalThresholds(bronze: 30, silver: 60, gold: 90),
          weekly: MedalThresholds(bronze: 180, silver: 360, gold: 540),
          monthly: MedalThresholds(bronze: 600, silver: 1200, gold: 1800),
        ),
        ChallengeVolumeProfile.h4EnduranceHold: ChallengePeriodThresholds(
          daily: MedalThresholds(bronze: 30, silver: 60, gold: 120),
          weekly: MedalThresholds(bronze: 210, silver: 420, gold: 840),
          monthly: MedalThresholds(bronze: 600, silver: 1200, gold: 2400),
        ),
      });

  static const Map<ExerciseType, ChallengeVolumeProfile>
  _profileByExercise = <ExerciseType, ChallengeVolumeProfile>{
    ExerciseType.squat: ChallengeVolumeProfile.r3MediumHigh,
    ExerciseType.plank: ChallengeVolumeProfile.h3StandardHold,
    ExerciseType.hollowHold: ChallengeVolumeProfile.h1AdvancedShort,
    ExerciseType.lunge: ChallengeVolumeProfile.r2Standard,
    ExerciseType.pushUp: ChallengeVolumeProfile.r2Standard,
    ExerciseType.sitUp: ChallengeVolumeProfile.r2Standard,
    ExerciseType.crunch: ChallengeVolumeProfile.r3MediumHigh,
    ExerciseType.reverseCrunch: ChallengeVolumeProfile.r2Standard,
    ExerciseType.bicepsCurl: ChallengeVolumeProfile.r2Standard,
    ExerciseType.lyingLegRaise: ChallengeVolumeProfile.r2Standard,
    ExerciseType.bentKneeLegRaise: ChallengeVolumeProfile.r2Standard,
    ExerciseType.standingHamstringCurl: ChallengeVolumeProfile.r3MediumHigh,
    ExerciseType.standingHipAbduction: ChallengeVolumeProfile.r3MediumHigh,
    ExerciseType.tricepsDip: ChallengeVolumeProfile.r1LowVolume,
    ExerciseType.romanianDeadlift: ChallengeVolumeProfile.r2Standard,
    ExerciseType.goodMorning: ChallengeVolumeProfile.r2Standard,
    ExerciseType.lateralRaise: ChallengeVolumeProfile.r2Standard,
    ExerciseType.shoulderPress: ChallengeVolumeProfile.r1LowVolume,
    ExerciseType.overheadTricepsExtension: ChallengeVolumeProfile.r2Standard,
    ExerciseType.uprightRow: ChallengeVolumeProfile.r2Standard,
    ExerciseType.calfRaise: ChallengeVolumeProfile.r4HighVolume,
    ExerciseType.frontRaise: ChallengeVolumeProfile.r2Standard,
    ExerciseType.gluteBridge: ChallengeVolumeProfile.r3MediumHigh,
    ExerciseType.wallSit: ChallengeVolumeProfile.h4EnduranceHold,
    ExerciseType.sidePlank: ChallengeVolumeProfile.h2SideHold,
    ExerciseType.jumpingJack: ChallengeVolumeProfile.r5CardioVolume,
    ExerciseType.standingHipExtension: ChallengeVolumeProfile.r3MediumHigh,
    ExerciseType.standingKneeRaise: ChallengeVolumeProfile.r4HighVolume,
    ExerciseType.standingStraightLegRaise: ChallengeVolumeProfile.r2Standard,
    ExerciseType.vUp: ChallengeVolumeProfile.r1LowVolume,
    ExerciseType.frogPump: ChallengeVolumeProfile.r4HighVolume,
    ExerciseType.lyingTricepsExtension: ChallengeVolumeProfile.r1LowVolume,
    ExerciseType.floorChestPress: ChallengeVolumeProfile.r2Standard,
    ExerciseType.yRaise: ChallengeVolumeProfile.r2Standard,
  };

  static final List<ChallengeDefinition> _definitions = List.unmodifiable(
    ExerciseType.values.map((exerciseType) {
      final profile = _profileByExercise[exerciseType];
      if (profile == null) {
        throw StateError('Missing challenge profile for ${exerciseType.id}.');
      }
      final thresholds = _thresholdsByProfile[profile];
      if (thresholds == null) {
        throw StateError(
          'Missing challenge thresholds for ${profile.storageValue}.',
        );
      }
      return ChallengeDefinition(
        exerciseType: exerciseType,
        profile: profile,
        thresholds: thresholds,
        catalogVersion: version,
      );
    }),
  );

  List<ChallengeDefinition> get definitions => _definitions;

  ChallengeDefinition definitionFor(ExerciseType exerciseType) {
    return _definitions.singleWhere(
      (definition) => definition.exerciseType == exerciseType,
    );
  }

  ChallengeDefinition? definitionForExerciseId(String exerciseId) {
    final exerciseType = ExerciseType.fromIdOrNull(exerciseId);
    return exerciseType == null ? null : definitionFor(exerciseType);
  }

  ChallengeDefinition? definitionForId(String challengeId) {
    for (final definition in _definitions) {
      if (definition.id == challengeId) {
        return definition;
      }
    }
    return null;
  }
}
