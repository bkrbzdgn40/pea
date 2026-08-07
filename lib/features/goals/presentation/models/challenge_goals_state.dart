import '../../../challenges/domain/models/challenge_period.dart';
import '../../../challenges/domain/models/challenge_period_window.dart';
import '../../../challenges/domain/models/challenge_progress.dart';
import '../../../challenges/domain/models/medal_tier.dart';
import '../../../workout_analysis/domain/models/exercise_type.dart';

/// Presentation-ready challenge progress for the selected calendar period.
class ChallengeGoalsState {
  ChallengeGoalsState({
    required this.period,
    required this.window,
    required List<ChallengeProgress> progresses,
    Map<ExerciseType, PersistedMedalSnapshot> earnedMedals =
        const <ExerciseType, PersistedMedalSnapshot>{},
  }) : progresses = List.unmodifiable(progresses),
       earnedMedals = Map.unmodifiable(earnedMedals) {
    if (progresses.isEmpty) {
      throw ArgumentError.value(
        progresses,
        'progresses',
        'Challenge catalog progress must not be empty.',
      );
    }
    final supportedExercises = progresses
        .map((progress) => progress.definition.exerciseType)
        .toSet();
    if (!supportedExercises.containsAll(earnedMedals.keys)) {
      throw ArgumentError.value(
        earnedMedals,
        'earnedMedals',
        'Earned medals must belong to catalog exercises.',
      );
    }
  }

  final ChallengePeriod period;
  final ChallengePeriodWindow window;
  final List<ChallengeProgress> progresses;
  final Map<ExerciseType, PersistedMedalSnapshot> earnedMedals;

  bool get hasTrustedActivity => views.any((view) => view.displayValue > 0);

  ChallengeGoalProgressView get recommendedFocus {
    final active =
        views
            .where((view) => view.displayValue > 0 && !view.hasReachedGold)
            .toList(growable: false)
          ..sort(_compareByCloseness);
    if (active.isNotEmpty) {
      return active.first;
    }

    final earned =
        views
            .where(
              (view) =>
                  view.displayValue > 0 || view.effectiveTier != MedalTier.none,
            )
            .toList(growable: false)
          ..sort((left, right) {
            final tierComparison = right.effectiveTier.rank.compareTo(
              left.effectiveTier.rank,
            );
            if (tierComparison != 0) {
              return tierComparison;
            }
            return right.displayValue.compareTo(left.displayValue);
          });
    if (earned.isNotEmpty) {
      return earned.first;
    }

    return viewFor(ExerciseType.pushUp);
  }

  List<ChallengeGoalProgressView> get views => progresses
      .map(
        (progress) => ChallengeGoalProgressView(
          progress: progress,
          earnedMedal: earnedMedals[progress.definition.exerciseType],
        ),
      )
      .toList(growable: false);

  ChallengeProgress progressFor(ExerciseType exerciseType) {
    return progresses.singleWhere(
      (progress) => progress.definition.exerciseType == exerciseType,
    );
  }

  ChallengeGoalProgressView viewFor(ExerciseType exerciseType) {
    final progress = progressFor(exerciseType);
    return ChallengeGoalProgressView(
      progress: progress,
      earnedMedal: earnedMedals[exerciseType],
    );
  }

  List<ChallengeGoalProgressView> nearbyProgresses({
    required ExerciseType excluding,
    int limit = 3,
  }) {
    final candidates =
        views
            .where(
              (view) =>
                  view.progress.definition.exerciseType != excluding &&
                  view.displayValue > 0 &&
                  !view.hasReachedGold,
            )
            .toList(growable: false)
          ..sort(_compareByCloseness);
    return candidates.take(limit).toList(growable: false);
  }
}

class PersistedMedalSnapshot {
  PersistedMedalSnapshot({required this.tier, required this.progressValue}) {
    if (tier == MedalTier.none) {
      throw ArgumentError.value(
        tier,
        'tier',
        'A persisted medal must contain an earned tier.',
      );
    }
    if (!progressValue.isFinite || progressValue <= 0) {
      throw ArgumentError.value(
        progressValue,
        'progressValue',
        'Persisted medal progress must be finite and positive.',
      );
    }
  }

  final MedalTier tier;
  final double progressValue;
}

class ChallengeGoalProgressView {
  const ChallengeGoalProgressView({
    required this.progress,
    required this.earnedMedal,
  });

  final ChallengeProgress progress;
  final PersistedMedalSnapshot? earnedMedal;

  MedalTier get effectiveTier {
    final earnedTier = earnedMedal?.tier ?? MedalTier.none;
    return earnedTier.rank > progress.tier.rank ? earnedTier : progress.tier;
  }

  double get displayValue {
    final persistedValue = earnedMedal?.progressValue ?? 0;
    return persistedValue > progress.value ? persistedValue : progress.value;
  }

  bool get hasReachedGold => effectiveTier == MedalTier.gold;

  MedalTier? get nextTier => switch (effectiveTier) {
    MedalTier.none => MedalTier.bronze,
    MedalTier.bronze => MedalTier.silver,
    MedalTier.silver => MedalTier.gold,
    MedalTier.gold => null,
  };

  int? get nextThreshold {
    final tier = nextTier;
    return tier == null ? null : progress.thresholds.thresholdFor(tier);
  }

  double? get remainingToNextTier {
    final threshold = nextThreshold;
    if (threshold == null) {
      return null;
    }
    return (threshold - displayValue).clamp(0, double.infinity).toDouble();
  }
}

int _compareByCloseness(
  ChallengeGoalProgressView left,
  ChallengeGoalProgressView right,
) {
  final leftScore = _remainingRatio(left);
  final rightScore = _remainingRatio(right);
  final comparison = leftScore.compareTo(rightScore);
  if (comparison != 0) {
    return comparison;
  }
  return right.displayValue.compareTo(left.displayValue);
}

double _remainingRatio(ChallengeGoalProgressView view) {
  final remaining = view.remainingToNextTier;
  final nextThreshold = view.nextThreshold;
  if (remaining == null || nextThreshold == null) {
    return double.infinity;
  }
  final previousThreshold = switch (view.effectiveTier) {
    MedalTier.none => 0,
    MedalTier.bronze => view.progress.thresholds.bronze,
    MedalTier.silver => view.progress.thresholds.silver,
    MedalTier.gold => view.progress.thresholds.gold,
  };
  final segment = nextThreshold - previousThreshold;
  return segment <= 0 ? double.infinity : remaining / segment;
}
