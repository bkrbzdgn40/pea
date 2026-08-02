import '../../../../app/localization/app_localizations.dart';
import '../../application/feedback_delivery_controller.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/hold_feedback_code.dart';
import '../../domain/models/range_rep_feedback_code.dart';
import 'hold_feedback_ui_mapper.dart';
import 'range_rep_feedback_ui_mapper.dart';

class ResolvedWorkoutFeedback {
  const ResolvedWorkoutFeedback({required this.message, required this.cue});

  final String message;
  final FeedbackDeliveryCue cue;
}

class WorkoutFeedbackResolver {
  final Map<_RangeRepFeedbackCacheKey, ResolvedWorkoutFeedback> _rangeRepCache =
      <_RangeRepFeedbackCacheKey, ResolvedWorkoutFeedback>{};
  final Map<_HoldFeedbackCacheKey, ResolvedWorkoutFeedback> _holdCache =
      <_HoldFeedbackCacheKey, ResolvedWorkoutFeedback>{};

  ResolvedWorkoutFeedback resolveRangeRep({
    required RangeRepFeedbackCode code,
    required AppLocalizations localizations,
    required ExerciseType exerciseType,
  }) {
    final key = _RangeRepFeedbackCacheKey(
      languageCode: localizations.locale.languageCode.toLowerCase(),
      exerciseType: exerciseType,
      code: code,
    );
    return _rangeRepCache.putIfAbsent(key, () {
      final message = mapRangeRepFeedbackCodeToMessage(
        code,
        localizations: localizations,
        exerciseType: exerciseType,
      );
      return ResolvedWorkoutFeedback(
        message: message,
        cue: FeedbackDeliveryCue(
          id: 'range:${code.code}',
          message: message,
          kind: _deliveryKindForRangeRepFeedback(code),
        ),
      );
    });
  }

  ResolvedWorkoutFeedback resolveHold({
    required HoldFeedbackCode? code,
    required AppLocalizations localizations,
  }) {
    final effectiveCode = code ?? HoldFeedbackCode.preparePosition;
    final key = _HoldFeedbackCacheKey(
      languageCode: localizations.locale.languageCode.toLowerCase(),
      code: effectiveCode,
      isFallback: code == null,
    );
    return _holdCache.putIfAbsent(key, () {
      final message = mapHoldFeedbackCodeToMessage(
        effectiveCode,
        localizations: localizations,
      );
      return ResolvedWorkoutFeedback(
        message: message,
        cue: FeedbackDeliveryCue(
          id: code == null
              ? 'hold:fallback:$message'
              : 'hold:${effectiveCode.code}',
          message: message,
          kind: _deliveryKindForHoldFeedback(effectiveCode),
        ),
      );
    });
  }
}

FeedbackDeliveryKind _deliveryKindForRangeRepFeedback(
  RangeRepFeedbackCode code,
) {
  return switch (code) {
    RangeRepFeedbackCode.waitForBody ||
    RangeRepFeedbackCode.bodyNotVisible => FeedbackDeliveryKind.blocking,
    RangeRepFeedbackCode.awaitNeutral ||
    RangeRepFeedbackCode.ready => FeedbackDeliveryKind.status,
    RangeRepFeedbackCode.descend ||
    RangeRepFeedbackCode.ascend ||
    RangeRepFeedbackCode.repCompleted ||
    RangeRepFeedbackCode.repIncomplete => FeedbackDeliveryKind.movement,
    RangeRepFeedbackCode.legacyFormThresholdViolation ||
    RangeRepFeedbackCode.controlDescent ||
    RangeRepFeedbackCode.controlAscent ||
    RangeRepFeedbackCode.stabilizeTransition ||
    RangeRepFeedbackCode.maintainForm => FeedbackDeliveryKind.corrective,
  };
}

FeedbackDeliveryKind _deliveryKindForHoldFeedback(HoldFeedbackCode code) {
  return switch (code) {
    HoldFeedbackCode.bodyNotVisible => FeedbackDeliveryKind.blocking,
    HoldFeedbackCode.preparePosition ||
    HoldFeedbackCode.holdPosition => FeedbackDeliveryKind.status,
    HoldFeedbackCode.alignHips ||
    HoldFeedbackCode.liftHips ||
    HoldFeedbackCode.adjustElbowSupport ||
    HoldFeedbackCode.placeSupportElbowUnderShoulder ||
    HoldFeedbackCode.useForearmSupport ||
    HoldFeedbackCode.extendLegs ||
    HoldFeedbackCode.increaseHollowCompression ||
    HoldFeedbackCode.extendArmsOverhead ||
    HoldFeedbackCode.straightenKnees ||
    HoldFeedbackCode.adjustWallSitDepth ||
    HoldFeedbackCode.alignWallSitTorso ||
    HoldFeedbackCode.correctForm => FeedbackDeliveryKind.corrective,
  };
}

class _RangeRepFeedbackCacheKey {
  const _RangeRepFeedbackCacheKey({
    required this.languageCode,
    required this.exerciseType,
    required this.code,
  });

  final String languageCode;
  final ExerciseType exerciseType;
  final RangeRepFeedbackCode code;

  @override
  bool operator ==(Object other) {
    return other is _RangeRepFeedbackCacheKey &&
        languageCode == other.languageCode &&
        exerciseType == other.exerciseType &&
        code == other.code;
  }

  @override
  int get hashCode => Object.hash(languageCode, exerciseType, code);
}

class _HoldFeedbackCacheKey {
  const _HoldFeedbackCacheKey({
    required this.languageCode,
    required this.code,
    required this.isFallback,
  });

  final String languageCode;
  final HoldFeedbackCode code;
  final bool isFallback;

  @override
  bool operator ==(Object other) {
    return other is _HoldFeedbackCacheKey &&
        languageCode == other.languageCode &&
        code == other.code &&
        isFallback == other.isFallback;
  }

  @override
  int get hashCode => Object.hash(languageCode, code, isFallback);
}
