import '../../../../app/localization/app_localizations.dart';
import '../../application/exercise_definition.dart';
import '../../domain/models/camera_view_contract.dart';
import '../../domain/models/exercise_setup_contract.dart';
import '../../domain/models/exercise_type.dart';
import '../models/exercise_setup_view_data.dart';

/// Projects exercise setup metadata into localized, presentation-ready copy.
///
/// Camera orientation is read from [CameraViewContract], while body coverage,
/// support, camera height, and environment copy are read from
/// [ExerciseSetupContract]. The mapper does not maintain a parallel setup
/// contract.
ExerciseSetupViewData mapExerciseSetupToViewData({
  required ExerciseDefinition definition,
  required AppLocalizations localizations,
}) {
  if (!definition.isAnalysisSupported) {
    throw StateError(
      'Setup presentation is unavailable for unsupported ${definition.type}.',
    );
  }

  final cameraView = _singlePreferredCameraView(
    definition.analysisCameraViewContract,
    definition.type,
  );
  final setup = definition.analysisSetupContract;

  return ExerciseSetupViewData(
    exerciseId: definition.id,
    exerciseName: localizations.exerciseTitle(definition.id),
    cameraViewLabel: _cameraViewLabel(cameraView, localizations),
    cameraViewInstruction: _cameraViewInstruction(cameraView, localizations),
    bodyCoverageInstruction: _bodyCoverageInstruction(
      setup.bodyCoverage,
      localizations,
    ),
    startPoseInstruction: _startPoseInstruction(
      definition.type,
      setup.startPoseFamily,
      localizations,
    ),
    setupPositionLabel: _setupPositionLabel(
      setup.supportSurface,
      localizations,
    ),
    cameraPlacementInstruction: _cameraPlacementInstruction(
      setup.cameraHeight,
      localizations,
    ),
    environmentInstructions: _environmentInstructions(
      setup.environmentRequirements,
      setup.supportSurface,
      localizations,
    ),
  );
}

CameraView _singlePreferredCameraView(
  CameraViewContract contract,
  ExerciseType exerciseType,
) {
  final preferredViews = contract.preferredViews;
  if (preferredViews.length != 1) {
    throw StateError(
      '$exerciseType must declare exactly one preferred camera view for setup '
      'presentation, but found ${preferredViews.length}.',
    );
  }
  return preferredViews.single;
}

String _cameraViewLabel(CameraView cameraView, AppLocalizations localizations) {
  return switch (cameraView) {
    CameraView.side => localizations.pick(
      tr: 'Yandan görünüm',
      en: 'Side view',
    ),
    CameraView.front => localizations.pick(
      tr: 'Önden görünüm',
      en: 'Front view',
    ),
  };
}

String _cameraViewInstruction(
  CameraView cameraView,
  AppLocalizations localizations,
) {
  return switch (cameraView) {
    CameraView.side => localizations.pick(
      tr: 'Sağ veya sol yanını kameraya dön.',
      en: 'Turn your left or right side toward the camera.',
    ),
    CameraView.front => localizations.pick(
      tr: 'Doğrudan kameraya dön.',
      en: 'Face the camera directly.',
    ),
  };
}

String _bodyCoverageInstruction(
  SetupBodyCoverage coverage,
  AppLocalizations localizations,
) {
  final visibleRegions = SetupBodyRegion.values
      .where(coverage.requires)
      .map((region) => _bodyRegionLabel(region, localizations))
      .toList(growable: false);
  final joinedRegions = _joinLocalized(visibleRegions, localizations);

  if (localizations.isTurkish) {
    return '${_capitalize(joinedRegions)} kadrajda tamamen görünsün.';
  }
  return 'Keep your $joinedRegions fully inside the frame.';
}

String _bodyRegionLabel(
  SetupBodyRegion region,
  AppLocalizations localizations,
) {
  return switch (region) {
    SetupBodyRegion.head => localizations.pick(tr: 'başın', en: 'head'),
    SetupBodyRegion.shoulders => localizations.pick(
      tr: 'omuzların',
      en: 'shoulders',
    ),
    SetupBodyRegion.elbows => localizations.pick(
      tr: 'dirseklerin',
      en: 'elbows',
    ),
    SetupBodyRegion.wrists => localizations.pick(
      tr: 'bileklerin',
      en: 'wrists',
    ),
    SetupBodyRegion.hips => localizations.pick(tr: 'kalçan', en: 'hips'),
    SetupBodyRegion.knees => localizations.pick(tr: 'dizlerin', en: 'knees'),
    SetupBodyRegion.ankles => localizations.pick(
      tr: 'ayak bileklerin',
      en: 'ankles',
    ),
    SetupBodyRegion.feet => localizations.pick(tr: 'ayakların', en: 'feet'),
  };
}

String _startPoseInstruction(
  ExerciseType exerciseType,
  StartPoseFamily startPoseFamily,
  AppLocalizations localizations,
) {
  _ensureStartPoseFamilyMatches(exerciseType, startPoseFamily);

  return switch (exerciseType) {
    ExerciseType.squat => localizations.pick(
      tr: 'Ayaklarını omuz genişliğinde aç; dik ve dengeli dur.',
      en: 'Stand tall and balanced with your feet about shoulder-width apart.',
    ),
    ExerciseType.plank => localizations.pick(
      tr: 'Dirseklerini omuzlarının altına yerleştir ve başından topuklarına düz bir hat kur.',
      en: 'Place your elbows under your shoulders and form a straight line from head to heels.',
    ),
    ExerciseType.hollowHold => localizations.pick(
      tr: 'Sırt üstü uzan; omuzlarını hafif kaldır, kollarını baş üstüne uzat ve bacaklarını yerden kaldır.',
      en: 'Lie on your back, lift your shoulders slightly, reach your arms overhead, and raise your legs.',
    ),
    ExerciseType.lunge => localizations.pick(
      tr: 'Kameraya yakın bacağını öne al ve ayakların sabit kalacak şekilde rahat bir adım pozisyonu kur.',
      en: 'Place the leg closest to the camera in front and settle into a comfortable split stance with both feet fixed.',
    ),
    ExerciseType.pushUp => localizations.pick(
      tr: 'Ellerini omuzlarından biraz geniş yerleştir ve başından topuklarına düz bir hat kur.',
      en: 'Place your hands slightly wider than your shoulders and form a straight line from head to heels.',
    ),
    ExerciseType.sitUp => localizations.pick(
      tr: 'Sırt üstü uzan, dizlerini bük, ayaklarını yere bas ve ellerini boynunu çekmeyecek şekilde yerleştir.',
      en: 'Lie on your back, bend your knees, plant your feet, and place your hands without pulling on your neck.',
    ),
    ExerciseType.crunch => localizations.pick(
      tr: 'Sırt üstü uzan, dizlerini bük, ayaklarını yere bas ve omuzlarını zeminden kaldırmaya hazırlan.',
      en: 'Lie on your back, bend your knees, plant your feet, and prepare to lift your shoulders from the floor.',
    ),
    ExerciseType.reverseCrunch => localizations.pick(
      tr: 'Sırt üstü uzan, dizlerini bük ve kalçanı kontrollü kaldırabileceğin dengeli bir pozisyon kur.',
      en: 'Lie on your back, bend your knees, and settle into a balanced position for a controlled hip lift.',
    ),
    ExerciseType.bicepsCurl => localizations.pick(
      tr: 'Kollarını aşağıda başlat ve dirseklerini gövdene yakın tut.',
      en: 'Start with both arms down and keep your elbows close to your torso.',
    ),
    ExerciseType.lyingLegRaise => localizations.pick(
      tr: 'Sırt üstü uzan; bacaklarını birleştir, dizlerini uzat ve bacaklarını zemine yakın başlat.',
      en: 'Lie on your back with your legs together, knees extended, and legs starting close to the floor.',
    ),
    ExerciseType.bentKneeLegRaise => localizations.pick(
      tr: 'Sırt üstü uzan, dizlerini rahatça bük ve bacaklarını birlikte hareket ettirmeye hazırlan.',
      en: 'Lie on your back, bend your knees comfortably, and prepare to move both legs together.',
    ),
    ExerciseType.standingHamstringCurl => localizations.pick(
      tr: 'Yan dur, ağırlığını destek bacağına aktar ve çalışan bacağını düz pozisyonda başlat.',
      en: 'Stand side-on, shift your weight to the support leg, and begin with the working leg extended.',
    ),
    ExerciseType.standingHipAbduction => localizations.pick(
      tr: 'Kameraya dön, dik dur ve çalışan bacağını yana kaldırmak için ayaklarını yakın başlat.',
      en: 'Face the camera, stand tall, and begin with your feet close before raising the working leg to the side.',
    ),
    ExerciseType.tricepsDip => localizations.pick(
      tr: 'Ellerini sağlam yükseltinin kenarına yerleştir, kalçanı yüzeyin önüne al ve ayaklarını öne uzat.',
      en: 'Place your hands on the edge of the stable raised surface, move your hips just in front of it, and place your feet forward.',
    ),
    ExerciseType.romanianDeadlift => localizations.pick(
      tr: 'Ayaklarını kalça genişliğinde aç, dizlerini hafif bük ve gövdeni dik başlat.',
      en: 'Stand with your feet about hip-width apart, keep a soft bend in your knees, and begin upright.',
    ),
    ExerciseType.goodMorning => localizations.pick(
      tr: 'Ayaklarını kalça genişliğinde aç, dizlerini hafifçe yumuşak tut ve gövdeni dik başlat.',
      en: 'Stand with your feet about hip-width apart, keep a soft bend in your knees, and begin upright.',
    ),
    ExerciseType.lateralRaise => localizations.pick(
      tr: 'Kollarını yanlarda aşağıda başlat ve dirseklerini hafif yumuşak tut.',
      en: 'Start with both arms down by your sides and keep a soft bend in your elbows.',
    ),
    ExerciseType.shoulderPress => localizations.pick(
      tr: 'Dirseklerini bük, ellerini omuz hizasına getir ve gövdeni dik tut.',
      en: 'Bend your elbows, bring your hands to shoulder level, and keep your torso upright.',
    ),
    ExerciseType.overheadTricepsExtension => localizations.pick(
      tr: 'Kollarını baş üstüne al, dirseklerini bük ve üst kollarını başına yakın tut.',
      en: 'Bring your arms overhead, bend your elbows, and keep your upper arms close to your head.',
    ),
    ExerciseType.uprightRow => localizations.pick(
      tr: 'Kollarını gövdenin önünde aşağıda başlat ve omuzlarını rahat tut.',
      en: 'Start with your arms down in front of your body and keep your shoulders relaxed.',
    ),
    ExerciseType.calfRaise => localizations.pick(
      tr: 'Ayaklarını kalça genişliğinde aç, dizlerini uzat ve topuklarını yere basarak dengeli dur.',
      en: 'Stand balanced with your feet about hip-width apart, knees extended, and heels on the floor.',
    ),
    ExerciseType.frontRaise => localizations.pick(
      tr: 'Kollarını gövdenin önünde aşağıda başlat ve gövdeni dik tut.',
      en: 'Start with your arms down in front of your body and keep your torso upright.',
    ),
    ExerciseType.gluteBridge => localizations.pick(
      tr: 'Sırt üstü uzan, dizlerini bük ve ayaklarını kalça genişliğinde yere bas.',
      en: 'Lie on your back, bend your knees, and plant your feet about hip-width apart.',
    ),
    ExerciseType.wallSit => localizations.pick(
      tr: 'Sırtını duvara ver, ayaklarını öne al ve kontrollü biçimde oturuş pozisyonuna in.',
      en: 'Place your back against the wall, step your feet forward, and lower into the hold with control.',
    ),
    ExerciseType.sidePlank => localizations.pick(
      tr: 'Yan yat; dirseğini veya elini omzunun altına yerleştir, bacaklarını uzat ve kalçanı kaldır.',
      en: 'Lie on your side, place your elbow or hand under your shoulder, extend your legs, and lift your hips.',
    ),
    ExerciseType.jumpingJack => localizations.pick(
      tr: 'Ayaklarını yakın, kollarını yanlarda aşağıda tut ve dengeli dur.',
      en: 'Stand balanced with your feet close together and your arms down by your sides.',
    ),
  };
}

void _ensureStartPoseFamilyMatches(
  ExerciseType exerciseType,
  StartPoseFamily startPoseFamily,
) {
  final expectedFamily = switch (exerciseType) {
    ExerciseType.squat ||
    ExerciseType.romanianDeadlift ||
    ExerciseType.goodMorning ||
    ExerciseType.standingHamstringCurl ||
    ExerciseType.calfRaise => StartPoseFamily.standingNeutralSide,
    ExerciseType.plank ||
    ExerciseType.pushUp => StartPoseFamily.floorProneSupport,
    ExerciseType.hollowHold ||
    ExerciseType.sitUp ||
    ExerciseType.crunch ||
    ExerciseType.reverseCrunch ||
    ExerciseType.lyingLegRaise ||
    ExerciseType.bentKneeLegRaise ||
    ExerciseType.gluteBridge => StartPoseFamily.floorSupine,
    ExerciseType.lunge => StartPoseFamily.splitStanceSide,
    ExerciseType.bicepsCurl ||
    ExerciseType.lateralRaise ||
    ExerciseType.standingHipAbduction ||
    ExerciseType.uprightRow => StartPoseFamily.standingArmsDownFront,
    ExerciseType.tricepsDip => StartPoseFamily.dipSupport,
    ExerciseType.shoulderPress || ExerciseType.overheadTricepsExtension =>
      StartPoseFamily.standingElbowsBentFront,
    ExerciseType.frontRaise => StartPoseFamily.standingArmsDownSide,
    ExerciseType.wallSit => StartPoseFamily.wallSupportedHold,
    ExerciseType.sidePlank => StartPoseFamily.sideSupport,
    ExerciseType.jumpingJack => StartPoseFamily.dynamicBilateralNeutral,
  };

  if (startPoseFamily != expectedFamily) {
    throw StateError(
      '$exerciseType setup copy expects ${expectedFamily.name}, but the '
      'contract declares ${startPoseFamily.name}.',
    );
  }
}

String _setupPositionLabel(
  SetupSupportSurface supportSurface,
  AppLocalizations localizations,
) {
  return switch (supportSurface) {
    SetupSupportSurface.none => localizations.pick(
      tr: 'Ayakta',
      en: 'Standing',
    ),
    SetupSupportSurface.floor => localizations.pick(
      tr: 'Yerde',
      en: 'On the floor',
    ),
    SetupSupportSurface.wall => localizations.pick(
      tr: 'Duvar destekli',
      en: 'Wall-supported',
    ),
    SetupSupportSurface.raisedSurface => localizations.pick(
      tr: 'Yükselti destekli',
      en: 'Raised-surface support',
    ),
  };
}

String _cameraPlacementInstruction(
  SetupCameraHeight cameraHeight,
  AppLocalizations localizations,
) {
  return switch (cameraHeight) {
    SetupCameraHeight.floorLevel => localizations.pick(
      tr: 'Telefonu yere yakın ve hareket alanının karşısına sabitle.',
      en: 'Secure the phone close to floor level and opposite the movement area.',
    ),
    SetupCameraHeight.lowerBodyLevel => localizations.pick(
      tr: 'Kamerayı yaklaşık kalça ile diz hizası arasına yerleştir.',
      en: 'Place the camera approximately between hip and knee height.',
    ),
    SetupCameraHeight.midBodyLevel => localizations.pick(
      tr: 'Kamerayı yaklaşık kalça ile göbek hizası arasına yerleştir.',
      en: 'Place the camera approximately between hip and waist height.',
    ),
    SetupCameraHeight.upperBodyLevel => localizations.pick(
      tr: 'Kamerayı yaklaşık göğüs ile omuz hizası arasına yerleştir.',
      en: 'Place the camera approximately between chest and shoulder height.',
    ),
  };
}

List<String> _environmentInstructions(
  Set<SetupEnvironmentRequirement> requirements,
  SetupSupportSurface supportSurface,
  AppLocalizations localizations,
) {
  return SetupEnvironmentRequirement.values
      .where(requirements.contains)
      .map(
        (requirement) =>
            _environmentInstruction(requirement, supportSurface, localizations),
      )
      .toList(growable: false);
}

String _environmentInstruction(
  SetupEnvironmentRequirement requirement,
  SetupSupportSurface supportSurface,
  AppLocalizations localizations,
) {
  return switch (requirement) {
    SetupEnvironmentRequirement.stableCamera => localizations.pick(
      tr: 'Telefonu kaymayacak ve titreşmeyecek sabit bir yere koy.',
      en: 'Place the phone on a stable surface where it cannot slide or shake.',
    ),
    SetupEnvironmentRequirement.adequateLighting => localizations.pick(
      tr: 'Eklemlerin net görüneceği kadar aydınlık bir ortam kullan.',
      en: 'Use enough light for your joints to remain clearly visible.',
    ),
    SetupEnvironmentRequirement.clearStandingArea => localizations.pick(
      tr: 'Ayakta hareket edebileceğin boş ve güvenli bir alan bırak.',
      en: 'Leave a clear and safe area for standing movement.',
    ),
    SetupEnvironmentRequirement.clearFloorArea =>
      supportSurface == SetupSupportSurface.raisedSurface
          ? localizations.pick(
              tr: 'Yükseltinin çevresinde ayaklarını güvenle yerleştireceğin boş alan bırak.',
              en: 'Leave a clear area around the raised surface for safe foot placement.',
            )
          : localizations.pick(
              tr: 'Yerde uzanabileceğin boş ve güvenli bir alan hazırla.',
              en: 'Prepare a clear and safe floor area where you can lie down.',
            ),
    SetupEnvironmentRequirement.clearOverheadSpace => localizations.pick(
      tr: 'Kollarını baş üstüne kaldırabileceğin boşluk bırak.',
      en: 'Leave enough overhead space to raise your arms safely.',
    ),
    SetupEnvironmentRequirement.unobstructedWall => localizations.pick(
      tr: 'Sırtını yaslayabileceğin engelsiz ve sabit bir duvar kullan.',
      en: 'Use a clear, stable wall that can support your back.',
    ),
    SetupEnvironmentRequirement.stableRaisedSurface => localizations.pick(
      tr: 'Kaymayan, devrilmeyen sağlam bir bench veya yükselti kullan.',
      en: 'Use a stable bench or raised surface that will not slide or tip.',
    ),
  };
}

String _joinLocalized(List<String> values, AppLocalizations localizations) {
  if (values.isEmpty) {
    throw StateError('At least one setup body region is required.');
  }
  if (values.length == 1) {
    return values.single;
  }
  if (values.length == 2) {
    return '${values.first} ${localizations.isTurkish ? 've' : 'and'} ${values.last}';
  }

  final leading = values.take(values.length - 1).join(', ');
  if (localizations.isTurkish) {
    return '$leading ve ${values.last}';
  }
  return '$leading, and ${values.last}';
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
