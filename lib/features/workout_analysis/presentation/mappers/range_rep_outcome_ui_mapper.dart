import '../../../../app/localization/app_localizations.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/range_rep_validation_result.dart';
import '../models/range_rep_outcome_view_data.dart';

RangeRepOutcomeViewData mapRangeRepOutcomeToViewData({
  required int repIndex,
  required RangeRepValidationStatus status,
  required List<RangeRepValidationReason> reasons,
  required AppLocalizations localizations,
}) {
  final primaryReason = _selectPrimaryReason(reasons);
  final hasTechniqueCaution = reasons.any(
    (reason) => reason == RangeRepValidationReason.persistentFormBreak,
  );
  final hasLimitedMeasurementConfidence = reasons.any(
    (reason) =>
        reason.isTempoMeasurementReason || reason.isMeasurementQualityReason,
  );

  return switch (status) {
    RangeRepValidationStatus.valid => RangeRepOutcomeViewData(
      repIndex: repIndex,
      status: status,
      title: localizations.pick(tr: 'Geçerli tekrar', en: 'Valid rep'),
      message: localizations.pick(
        tr: 'Tekrar sayıldı. Hareket aralığı ve temel form koşulları karşılandı.',
        en: 'Rep counted. Range of motion and basic form requirements were met.',
      ),
      tone: RangeRepOutcomeTone.positive,
      techniqueOutcome: RangeRepTechniqueOutcome.accepted,
      measurementConfidence: RangeRepMeasurementConfidence.reliable,
    ),
    RangeRepValidationStatus.lowConfidence => RangeRepOutcomeViewData(
      repIndex: repIndex,
      status: status,
      primaryReason: primaryReason,
      title: hasTechniqueCaution
          ? localizations.pick(tr: 'Form uyarısı', en: 'Form caution')
          : localizations.pick(tr: 'Tekrar sayıldı', en: 'Rep counted'),
      message: _lowConfidenceMessage(primaryReason, localizations),
      tone: RangeRepOutcomeTone.caution,
      techniqueOutcome: hasTechniqueCaution
          ? RangeRepTechniqueOutcome.caution
          : RangeRepTechniqueOutcome.accepted,
      measurementConfidence: hasLimitedMeasurementConfidence
          ? RangeRepMeasurementConfidence.limited
          : RangeRepMeasurementConfidence.reliable,
    ),
    RangeRepValidationStatus.invalid => RangeRepOutcomeViewData(
      repIndex: repIndex,
      status: status,
      primaryReason: primaryReason,
      title: localizations.pick(tr: 'Geçersiz tekrar', en: 'Invalid rep'),
      message: _invalidMessage(primaryReason, localizations),
      tone: RangeRepOutcomeTone.invalid,
      techniqueOutcome: RangeRepTechniqueOutcome.rejected,
      measurementConfidence: hasLimitedMeasurementConfidence
          ? RangeRepMeasurementConfidence.limited
          : RangeRepMeasurementConfidence.reliable,
    ),
  };
}

RangeRepValidationReason? _selectPrimaryReason(
  List<RangeRepValidationReason> reasons,
) {
  if (reasons.isEmpty) {
    return null;
  }

  const priority = <RangeRepValidationReason>[
    RangeRepValidationReason.incompletePhase,
    RangeRepValidationReason.insufficientRom,
    RangeRepValidationReason.persistentFormBreak,
    RangeRepValidationReason.coverageLoss,
    RangeRepValidationReason.sideSwitchDuringRep,
    RangeRepValidationReason.excessiveRepSpeed,
    RangeRepValidationReason.excessiveDescentSpeed,
    RangeRepValidationReason.excessiveAscentSpeed,
  ];

  for (final candidate in priority) {
    if (reasons.contains(candidate)) {
      return candidate;
    }
  }
  return reasons.first;
}

String _invalidMessage(
  RangeRepValidationReason? reason,
  AppLocalizations localizations,
) {
  return switch (reason) {
    RangeRepValidationReason.incompletePhase => localizations.pick(
      tr: 'Hareket dizisi tamamlanmadığı için tekrar geçerli sayılmadı.',
      en: 'The rep was invalid because the full movement sequence was not completed.',
    ),
    RangeRepValidationReason.insufficientRom => localizations.pick(
      tr: 'Yeterli hareket aralığı oluşmadığı için tekrar geçerli sayılmadı.',
      en: 'The rep was invalid because the required range of motion was not reached.',
    ),
    RangeRepValidationReason.coverageLoss => localizations.pick(
      tr: 'Kadraj kaybı nedeniyle tekrar güvenilir biçimde değerlendirilemedi.',
      en: 'The rep could not be evaluated reliably because framing was lost.',
    ),
    RangeRepValidationReason.sideSwitchDuringRep => localizations.pick(
      tr: 'Analiz edilen taraf tekrar sırasında değiştiği için sonuç geçersiz oldu.',
      en: 'The result was invalid because the analyzed side changed during the rep.',
    ),
    RangeRepValidationReason.persistentFormBreak => localizations.pick(
      tr: 'Form bozulması tekrar boyunca sürdüğü için sonuç geçersiz oldu.',
      en: 'The result was invalid because the form break persisted through the rep.',
    ),
    RangeRepValidationReason.excessiveDescentSpeed ||
    RangeRepValidationReason.excessiveAscentSpeed ||
    RangeRepValidationReason.excessiveRepSpeed => _tempoQuarantineMessage(
      localizations,
      counted: false,
    ),
    null => localizations.pick(
      tr: 'Tekrar doğrulama koşullarını karşılamadı.',
      en: 'The rep did not meet the validation requirements.',
    ),
  };
}

String _lowConfidenceMessage(
  RangeRepValidationReason? reason,
  AppLocalizations localizations,
) {
  return switch (reason) {
    RangeRepValidationReason.coverageLoss => localizations.pick(
      tr: 'Tekrar sayıldı. Kadraj kısa süre kaybolduğu için ölçüm güveni sınırlıydı.',
      en: 'The rep was counted. Measurement confidence was limited because framing was briefly lost.',
    ),
    RangeRepValidationReason.sideSwitchDuringRep => localizations.pick(
      tr: 'Tekrar sayıldı. Analiz edilen taraf hareket sırasında değiştiği için ölçüm güveni sınırlıydı.',
      en: 'The rep was counted. Measurement confidence was limited because the analyzed side changed during the movement.',
    ),
    RangeRepValidationReason.persistentFormBreak => localizations.pick(
      tr: 'Tekrar sayıldı, ancak hareket boyunca bir form uyarısı algılandı.',
      en: 'The rep was counted, but a form caution was detected during the movement.',
    ),
    RangeRepValidationReason.excessiveDescentSpeed ||
    RangeRepValidationReason.excessiveAscentSpeed ||
    RangeRepValidationReason.excessiveRepSpeed => _tempoQuarantineMessage(
      localizations,
      counted: true,
    ),
    RangeRepValidationReason.incompletePhase => localizations.pick(
      tr: 'Tekrar sayıldı, ancak hareket dizisi tam doğrulanamadı.',
      en: 'The rep was counted, but the full movement sequence could not be verified.',
    ),
    RangeRepValidationReason.insufficientRom => localizations.pick(
      tr: 'Tekrar sayıldı, ancak hareket aralığı sınırlıydı.',
      en: 'The rep was counted, but the range of motion was limited.',
    ),
    null => localizations.pick(
      tr: 'Tekrar sayıldı, ancak ölçüm güveni sınırlıydı.',
      en: 'The rep was counted, but measurement confidence was limited.',
    ),
  };
}

String _tempoQuarantineMessage(
  AppLocalizations localizations, {
  required bool counted,
}) {
  return localizations.pick(
    tr: counted
        ? 'Tekrar sayıldı. Tempo bu tekrar için güvenilir biçimde değerlendirilemedi ve skora dahil edilmedi.'
        : 'Tempo bu deneme için güvenilir biçimde değerlendirilemedi ve skora dahil edilmedi.',
    en: counted
        ? 'Rep counted. Tempo could not be evaluated reliably for this rep and was not included in the score.'
        : 'Tempo could not be evaluated reliably for this attempt and was not included in the score.',
  );
}

String rangeRepTempoPhaseLabel(
  AppLocalizations localizations, {
  required ExerciseType? exerciseType,
  required bool towardPeak,
}) {
  final labels = switch (exerciseType) {
    ExerciseType.squat || ExerciseType.lunge => (
      trTowardPeak: 'Aşağı iniş',
      trTowardNeutral: 'Yukarı çıkış',
      enTowardPeak: 'The lowering phase',
      enTowardNeutral: 'The rising phase',
    ),
    ExerciseType.pushUp || ExerciseType.tricepsDip => (
      trTowardPeak: 'Aşağı iniş',
      trTowardNeutral: 'Yukarı itiş',
      enTowardPeak: 'The lowering phase',
      enTowardNeutral: 'The upward press',
    ),
    ExerciseType.sitUp => (
      trTowardPeak: 'Gövdeyi kaldırma',
      trTowardNeutral: 'Başlangıç pozisyonuna dönüş',
      enTowardPeak: 'The torso lift',
      enTowardNeutral: 'The return to the starting position',
    ),
    ExerciseType.crunch => (
      trTowardPeak: 'Gövdeyi toplama',
      trTowardNeutral: 'Başlangıç pozisyonuna dönüş',
      enTowardPeak: 'The crunch phase',
      enTowardNeutral: 'The return to the starting position',
    ),
    ExerciseType.reverseCrunch => (
      trTowardPeak: 'Dizleri gövdeye çekme',
      trTowardNeutral: 'Başlangıç pozisyonuna dönüş',
      enTowardPeak: 'The knee tuck',
      enTowardNeutral: 'The return to the starting position',
    ),
    ExerciseType.bicepsCurl => (
      trTowardPeak: 'Ağırlığı kaldırma',
      trTowardNeutral: 'Kolu indirme',
      enTowardPeak: 'The lifting phase',
      enTowardNeutral: 'The lowering phase',
    ),
    ExerciseType.lyingLegRaise || ExerciseType.standingStraightLegRaise => (
      trTowardPeak: 'Bacağı kaldırma',
      trTowardNeutral: 'Bacağı indirme',
      enTowardPeak: 'The leg lift',
      enTowardNeutral: 'The leg lowering phase',
    ),
    ExerciseType.bentKneeLegRaise => (
      trTowardPeak: 'Dizleri kaldırma',
      trTowardNeutral: 'Bacakları indirme',
      enTowardPeak: 'The knee lift',
      enTowardNeutral: 'The leg lowering phase',
    ),
    ExerciseType.standingHamstringCurl => (
      trTowardPeak: 'Dizi bükme',
      trTowardNeutral: 'Bacağı indirme',
      enTowardPeak: 'The knee flexion phase',
      enTowardNeutral: 'The leg lowering phase',
    ),
    ExerciseType.standingHipAbduction => (
      trTowardPeak: 'Bacağı yana açma',
      trTowardNeutral: 'Bacağı kapatma',
      enTowardPeak: 'The outward leg movement',
      enTowardNeutral: 'The return inward',
    ),
    ExerciseType.romanianDeadlift || ExerciseType.goodMorning => (
      trTowardPeak: 'Kalçadan öne eğilme',
      trTowardNeutral: 'Dik pozisyona dönüş',
      enTowardPeak: 'The hip-hinge descent',
      enTowardNeutral: 'The return to standing',
    ),
    ExerciseType.lateralRaise ||
    ExerciseType.frontRaise ||
    ExerciseType.yRaise => (
      trTowardPeak: 'Kolları kaldırma',
      trTowardNeutral: 'Kolları indirme',
      enTowardPeak: 'The arm lift',
      enTowardNeutral: 'The arm lowering phase',
    ),
    ExerciseType.shoulderPress => (
      trTowardPeak: 'Yukarı itiş',
      trTowardNeutral: 'Ağırlığı indirme',
      enTowardPeak: 'The overhead press',
      enTowardNeutral: 'The lowering phase',
    ),
    ExerciseType.overheadTricepsExtension => (
      trTowardPeak: 'Dirseği açma',
      trTowardNeutral: 'Başlangıç pozisyonuna dönüş',
      enTowardPeak: 'The elbow extension',
      enTowardNeutral: 'The return to the starting position',
    ),
    ExerciseType.uprightRow => (
      trTowardPeak: 'Ağırlığı yukarı çekme',
      trTowardNeutral: 'Ağırlığı indirme',
      enTowardPeak: 'The upward pull',
      enTowardNeutral: 'The lowering phase',
    ),
    ExerciseType.calfRaise => (
      trTowardPeak: 'Topukları kaldırma',
      trTowardNeutral: 'Topukları indirme',
      enTowardPeak: 'The heel raise',
      enTowardNeutral: 'The heel lowering phase',
    ),
    ExerciseType.gluteBridge || ExerciseType.frogPump => (
      trTowardPeak: 'Kalçayı yükseltme',
      trTowardNeutral: 'Kalçayı indirme',
      enTowardPeak: 'The hip lift',
      enTowardNeutral: 'The hip lowering phase',
    ),
    ExerciseType.jumpingJack => (
      trTowardPeak: 'Kolları ve bacakları açma',
      trTowardNeutral: 'Başlangıç pozisyonuna dönüş',
      enTowardPeak: 'The opening phase',
      enTowardNeutral: 'The return to the starting position',
    ),
    ExerciseType.standingHipExtension => (
      trTowardPeak: 'Bacağı geriye uzatma',
      trTowardNeutral: 'Başlangıç pozisyonuna dönüş',
      enTowardPeak: 'The backward leg extension',
      enTowardNeutral: 'The return to the starting position',
    ),
    ExerciseType.standingKneeRaise => (
      trTowardPeak: 'Dizi kaldırma',
      trTowardNeutral: 'Bacağı indirme',
      enTowardPeak: 'The knee lift',
      enTowardNeutral: 'The leg lowering phase',
    ),
    ExerciseType.vUp => (
      trTowardPeak: 'Gövde ve bacakları toplama',
      trTowardNeutral: 'Başlangıç pozisyonuna dönüş',
      enTowardPeak: 'The body and leg lift',
      enTowardNeutral: 'The return to the starting position',
    ),
    ExerciseType.lyingTricepsExtension => (
      trTowardPeak: 'Kolları uzatma',
      trTowardNeutral: 'Dirsekleri bükerek indirme',
      enTowardPeak: 'The arm extension',
      enTowardNeutral: 'The elbow-bending descent',
    ),
    ExerciseType.floorChestPress => (
      trTowardPeak: 'Yukarı itiş',
      trTowardNeutral: 'Ağırlığı indirme',
      enTowardPeak: 'The upward press',
      enTowardNeutral: 'The lowering phase',
    ),
    ExerciseType.plank ||
    ExerciseType.hollowHold ||
    ExerciseType.wallSit ||
    ExerciseType.sidePlank ||
    null => (
      trTowardPeak: 'Hareketin ilk fazı',
      trTowardNeutral: 'Başlangıç pozisyonuna dönüş',
      enTowardPeak: 'The first movement phase',
      enTowardNeutral: 'The return to the starting position',
    ),
  };

  return localizations.pick(
    tr: towardPeak ? labels.trTowardPeak : labels.trTowardNeutral,
    en: towardPeak ? labels.enTowardPeak : labels.enTowardNeutral,
  );
}
