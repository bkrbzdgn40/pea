import '../../../../app/localization/app_localizations.dart';
import '../../domain/models/range_rep_validation_result.dart';
import '../models/range_rep_outcome_view_data.dart';

RangeRepOutcomeViewData mapRangeRepOutcomeToViewData({
  required int repIndex,
  required RangeRepValidationStatus status,
  required List<RangeRepValidationReason> reasons,
  required AppLocalizations localizations,
}) {
  final primaryReason = _selectPrimaryReason(reasons);

  return switch (status) {
    RangeRepValidationStatus.valid => RangeRepOutcomeViewData(
      repIndex: repIndex,
      status: status,
      title: localizations.pick(tr: 'Geçerli tekrar', en: 'Valid rep'),
      message: localizations.pick(
        tr: 'İyi tekrar. Hareket aralığı ve kontrol koşulları karşılandı.',
        en: 'Good rep. Range of motion and control requirements were met.',
      ),
      tone: RangeRepOutcomeTone.positive,
    ),
    RangeRepValidationStatus.lowConfidence => RangeRepOutcomeViewData(
      repIndex: repIndex,
      status: status,
      primaryReason: primaryReason,
      title: localizations.pick(tr: 'Tekrar tamamlandı', en: 'Rep completed'),
      message: _lowConfidenceMessage(primaryReason, localizations),
      tone: RangeRepOutcomeTone.caution,
    ),
    RangeRepValidationStatus.invalid => RangeRepOutcomeViewData(
      repIndex: repIndex,
      status: status,
      primaryReason: primaryReason,
      title: localizations.pick(tr: 'Geçersiz tekrar', en: 'Invalid rep'),
      message: _invalidMessage(primaryReason, localizations),
      tone: RangeRepOutcomeTone.invalid,
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
    RangeRepValidationReason.coverageLoss,
    RangeRepValidationReason.sideSwitchDuringRep,
    RangeRepValidationReason.persistentFormBreak,
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
    RangeRepValidationReason.excessiveDescentSpeed => localizations.pick(
      tr: 'İniş çok hızlı olduğu için tekrar güvenilir biçimde değerlendirilemedi.',
      en: 'The rep could not be evaluated reliably because the descent was too fast.',
    ),
    RangeRepValidationReason.excessiveAscentSpeed => localizations.pick(
      tr: 'Yükseliş çok hızlı olduğu için tekrar güvenilir biçimde değerlendirilemedi.',
      en: 'The rep could not be evaluated reliably because the ascent was too fast.',
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
      tr: 'Tekrar tamamlandı, ancak kadraj kısa süre kayboldu.',
      en: 'The rep was completed, but framing was briefly lost.',
    ),
    RangeRepValidationReason.sideSwitchDuringRep => localizations.pick(
      tr: 'Tekrar tamamlandı, ancak analiz edilen taraf hareket sırasında değişti.',
      en: 'The rep was completed, but the analyzed side changed during the movement.',
    ),
    RangeRepValidationReason.persistentFormBreak => localizations.pick(
      tr: 'Tekrar tamamlandı, ancak form bozulması algılandı.',
      en: 'The rep was completed, but a persistent form break was detected.',
    ),
    RangeRepValidationReason.excessiveDescentSpeed => localizations.pick(
      tr: 'Tekrar tamamlandı, ancak iniş çok hızlıydı.',
      en: 'The rep was completed, but the descent was too fast.',
    ),
    RangeRepValidationReason.excessiveAscentSpeed => localizations.pick(
      tr: 'Tekrar tamamlandı, ancak yükseliş çok hızlıydı.',
      en: 'The rep was completed, but the ascent was too fast.',
    ),
    RangeRepValidationReason.incompletePhase => localizations.pick(
      tr: 'Tekrar tamamlandı, ancak hareket dizisi tam doğrulanamadı.',
      en: 'The rep was completed, but the full movement sequence could not be verified.',
    ),
    RangeRepValidationReason.insufficientRom => localizations.pick(
      tr: 'Tekrar tamamlandı, ancak hareket aralığı sınırlıydı.',
      en: 'The rep was completed, but the range of motion was limited.',
    ),
    null => localizations.pick(
      tr: 'Tekrar tamamlandı, ancak ölçüm güveni düşüktü.',
      en: 'The rep was completed, but measurement confidence was low.',
    ),
  };
}
