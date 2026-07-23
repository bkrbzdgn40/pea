import 'package:flutter/widgets.dart';

/// Application copy for every locale currently exposed in Settings.
///
/// The project intentionally keeps localization deterministic and local. There
/// is no remote translation layer and no generated runtime dependency. Feature
/// screens consume this class from [BuildContext], while non-widget code can
/// construct it from the active locale when localized copy is required.
class AppLocalizations {
  const AppLocalizations(this.locale);

  static const supportedLocales = <Locale>[Locale('tr'), Locale('en')];

  static AppLocalizations of(BuildContext context) {
    return AppLocalizations(Localizations.localeOf(context));
  }

  final Locale locale;

  bool get isTurkish => locale.languageCode.toLowerCase() == 'tr';

  String pick({required String tr, required String en}) => isTurkish ? tr : en;

  // Global / shell
  String get appName => 'Pose Analysis';
  String get workoutAnalysis =>
      pick(tr: 'Antrenman Analizi', en: 'Workout Analysis');
  String get settings => pick(tr: 'Ayarlar', en: 'Settings');
  String get language => pick(tr: 'Dil', en: 'Language');
  String get appLanguage => pick(tr: 'Uygulama dili', en: 'App language');
  String get turkish => pick(tr: 'Türkçe', en: 'Turkish');
  String get english => pick(tr: 'İngilizce', en: 'English');
  String get camera => pick(tr: 'Kamera', en: 'Camera');
  String get cameraPreference =>
      pick(tr: 'Kamera tercihi', en: 'Camera preference');
  String get frontCamera => pick(tr: 'Ön kamera', en: 'Front camera');
  String get backCamera => pick(tr: 'Arka kamera', en: 'Back camera');
  String get imageQuality => pick(tr: 'Görüntü kalitesi', en: 'Image quality');
  String get low => pick(tr: 'Düşük', en: 'Low');
  String get medium => pick(tr: 'Orta', en: 'Medium');
  String get high => pick(tr: 'Yüksek', en: 'High');
  String get settingsLoadFailed =>
      pick(tr: 'Ayarlar yüklenemedi.', en: 'Settings could not be loaded.');
  String get dataLoadFailed =>
      pick(tr: 'Veriler yüklenemedi.', en: 'Data could not be loaded.');
  String get retry => pick(tr: 'Tekrar Dene', en: 'Retry');
  String get loading => pick(tr: 'Yükleniyor...', en: 'Loading...');
  String get home => pick(tr: 'Ana Sayfa', en: 'Home');
  String get howToUse => pick(tr: 'Nasıl Kullanılır', en: 'How to Use');
  String get selectExercise => pick(tr: 'Hareket Seç', en: 'Select Exercise');
  String get sessionHistory =>
      pick(tr: 'Geçmiş Oturumlar', en: 'Session History');
  String get exerciseGuide => pick(tr: 'Hareket Rehberi', en: 'Exercise Guide');
  String get workoutMenu => pick(tr: 'Antrenman menüsü', en: 'Workout menu');
  String get achievements => pick(tr: 'Başarılar', en: 'Achievements');
  String get goals => pick(tr: 'Hedefler', en: 'Goals');
  String get open => pick(tr: 'Açık', en: 'Unlocked');
  String get locked => pick(tr: 'Kilitli', en: 'Locked');
  String get comingSoon => pick(tr: 'Yakında', en: 'Coming soon');
  String get completed => pick(tr: 'Tamamlandı', en: 'Completed');

  // Authentication
  String get preparingSession =>
      pick(tr: 'Oturum hazırlanıyor...', en: 'Preparing session...');
  String get sessionPreparationFailed => pick(
    tr: 'Kullanıcı oturumu hazırlanamadı.',
    en: 'User session could not be prepared.',
  );

  // Home
  String get homeReadyPrompt => pick(
    tr: 'Bugünkü formunu takip etmeye hazır mısın?',
    en: 'Ready to track your form today?',
  );
  String greetingForHour(int hour) {
    if (hour >= 5 && hour < 12) {
      return pick(tr: 'Günaydın', en: 'Good morning');
    }
    if (hour >= 12 && hour < 17) {
      return pick(tr: 'İyi öğlenler', en: 'Good afternoon');
    }
    if (hour >= 17 && hour < 22) {
      return pick(tr: 'İyi akşamlar', en: 'Good evening');
    }
    return pick(tr: 'İyi geceler', en: 'Good night');
  }

  String get weeklyGoal => pick(tr: 'Haftalık Hedef', en: 'Weekly Goal');
  String get weeklyGoalEmpty => pick(
    tr: 'İlk analizinden sonra hedeflerin burada şekillenir.',
    en: 'Your goals will take shape here after your first analysis.',
  );
  String get achievementsEmptyPreview => pick(
    tr: 'Rozetlerin analizlerini tamamladıkça açılır.',
    en: 'Your badges unlock as you complete analyses.',
  );
  String get exerciseDistribution =>
      pick(tr: 'Egzersiz Dağılımı', en: 'Exercise Distribution');
  String get exerciseDistributionSubtitle => pick(
    tr: 'Oturumlarının hareketlere göre dağılımı',
    en: 'How your sessions are distributed across exercises',
  );
  String get exerciseDistributionEmpty => pick(
    tr: 'Kaydedilen oturumların hareket dağılımı burada toplanır.',
    en: 'The exercise distribution of saved sessions will appear here.',
  );
  String get aiCoach => 'AI Coach';
  String get aiCoachComingSoonDescription => pick(
    tr: 'Form analizi, günlük öneriler ve antrenman ipuçları yakında burada olacak.',
    en: 'Form analysis, daily suggestions, and workout tips will be available here soon.',
  );
  String get chooseExerciseAndStart => pick(
    tr: 'Hareket seç ve analize başla',
    en: 'Choose an exercise and start analysis',
  );
  String startExerciseAnalysis(String exerciseName) => pick(
    tr: '$exerciseName analizine başla',
    en: 'Start $exerciseName analysis',
  );
  String get chooseExerciseFirstStep => pick(
    tr: 'İlk adımda hangi hareketi analiz edeceğini seç.',
    en: 'First choose which exercise you want to analyze.',
  );
  String get continueToPreparation => pick(
    tr: 'Tek dokunuşla izin ve hazırlık akışına geç.',
    en: 'Continue to permissions and preparation with one tap.',
  );
  String get changeExercise =>
      pick(tr: 'Hareketi Değiştir', en: 'Change Exercise');
  String get viewSupportedExercises =>
      pick(tr: 'Desteklenen hareketleri gör', en: 'View supported exercises');
  String get chooseDifferentAnalysis => pick(
    tr: 'Farklı bir analiz hattı seç',
    en: 'Choose a different analysis',
  );
  String get techniqueTipsAndMistakes =>
      pick(tr: 'Teknik ipuçları ve hatalar', en: 'Technique tips and mistakes');
  String get savedAnalyses =>
      pick(tr: 'Kaydedilmiş analizler', en: 'Saved analyses');
  String get plannedWorkout =>
      pick(tr: 'Planlı Antrenman', en: 'Planned Workout');
  String get plannedWorkoutSubtitle =>
      pick(tr: 'Set, tur ve hedef akışı', en: 'Sets, rounds, and target flow');
  String get assessment => pick(tr: 'Değerlendirme', en: 'Assessment');
  String get assessmentSubtitle => pick(
    tr: 'Squat, denge ve omuz ölçümü',
    en: 'Squat, balance, and shoulder measurement',
  );
  String selectedExercise(String exerciseName) => pick(
    tr: 'Seçili hareket: $exerciseName',
    en: 'Selected exercise: $exerciseName',
  );
  String get noExerciseSelected =>
      pick(tr: 'Henüz hareket seçilmedi', en: 'No exercise selected yet');
  String get quickStartUsesSelection => pick(
    tr: 'Hızlı başlatma bu hareket üzerinden devam eder.',
    en: 'Quick start will continue with this exercise.',
  );
  String get quickStartNeedsSelection => pick(
    tr: 'Hızlı başlatma için önce analiz edeceğin hareketi seç.',
    en: 'Choose an exercise before using quick start.',
  );
  String get change => pick(tr: 'Değiştir', en: 'Change');
  String get select => pick(tr: 'Seç', en: 'Select');
  String get progressWillAppearHere => pick(
    tr: 'İlerlemen burada birikecek',
    en: 'Your progress will build up here',
  );
  String get firstAnalysisProgressDescription => pick(
    tr: 'İlk analizini tamamladığında oturumların ve haftalık özetin burada görünür.',
    en: 'Your sessions and weekly summary will appear here after your first analysis.',
  );
  String get totalAnalyses => pick(tr: 'Toplam Analiz', en: 'Total Analyses');
  String get thisWeek => pick(tr: 'Bu Hafta', en: 'This Week');

  // Achievements
  String get achievementsLoadFailed => pick(
    tr: 'Başarılar yüklenemedi. Lütfen daha sonra tekrar dene.',
    en: 'Achievements could not be loaded. Please try again later.',
  );
  String get achievementsHeaderTitle => pick(
    tr: 'İlerlemeni ve açılan rozetleri burada göreceksin',
    en: 'Track your progress and unlocked badges here',
  );
  String get achievementsHeaderSubtitle => pick(
    tr: 'Analizlerini tamamladıkça rozetlerin burada açılır.',
    en: 'Badges unlock here as you complete your analyses.',
  );
  String achievementsEmptyMessage(bool hasError) => hasError
      ? pick(
          tr: 'Rozetler şu an hazırlanamadı. Daha sonra tekrar bakabilirsin.',
          en: 'Badges are unavailable right now. Please check again later.',
        )
      : pick(
          tr: 'İlk analizini tamamladığında rozetlerin burada görünür.',
          en: 'Your badges will appear here after you complete your first analysis.',
        );
  String achievementTitle(String id, {String? fallback}) {
    return switch (id) {
      'first_analysis' => pick(tr: 'İlk Analiz', en: 'First Analysis'),
      'score_90_plus' => pick(tr: '90+ Skor', en: '90+ Score'),
      'hundred_reps' => pick(tr: '100 Tekrar', en: '100 Reps'),
      'ten_sessions' => pick(tr: '10 Oturum', en: '10 Sessions'),
      _ => fallback ?? id,
    };
  }

  String achievementDescription(String id, {String? fallback}) {
    return switch (id) {
      'first_analysis' => pick(
        tr: 'İlk canlı analiz oturumunu tamamladın.',
        en: 'Complete your first live analysis session.',
      ),
      'score_90_plus' => pick(
        tr: 'Yüksek form kalitesiyle güçlü bir oturum çıkar.',
        en: 'Complete a strong session with high form quality.',
      ),
      'hundred_reps' => pick(
        tr: 'Toplam tekrar hacmini istikrarlı şekilde artır.',
        en: 'Build your total rep volume consistently.',
      ),
      'ten_sessions' => pick(
        tr: 'Antrenman geçmişini büyüt ve ritmini koru.',
        en: 'Build your workout history and keep your rhythm.',
      ),
      _ => fallback ?? id,
    };
  }

  String achievementRequirement(String id, {String? fallback}) {
    return switch (id) {
      'first_analysis' => pick(
        tr: '1 analiz tamamla',
        en: 'Complete 1 analysis',
      ),
      'score_90_plus' => pick(
        tr: 'Bir oturumda 90+ en iyi skor al',
        en: 'Reach a best score of 90+ in one session',
      ),
      'hundred_reps' => pick(
        tr: 'Toplam 100 tekrar tamamla',
        en: 'Complete 100 total reps',
      ),
      'ten_sessions' => pick(
        tr: '10 analiz oturumu tamamla',
        en: 'Complete 10 analysis sessions',
      ),
      _ => fallback ?? id,
    };
  }

  // Goals
  String get goalsLoadFailed => pick(
    tr: 'Hedefler yüklenemedi. Lütfen daha sonra tekrar dene.',
    en: 'Goals could not be loaded. Please try again later.',
  );
  String get goalsHeaderTitle => pick(
    tr: 'Haftalık ilerlemeni burada takip edeceksin',
    en: 'Track your weekly progress here',
  );
  String get goalsHeaderSubtitle => pick(
    tr: 'Analizlerin tamamlandıkça haftalık hedeflerin burada netleşir.',
    en: 'Your weekly goals become clearer as you complete analyses.',
  );
  String goalsEmptyMessage(bool hasError) => hasError
      ? pick(
          tr: 'Hedefler şu an hazırlanamadı. Daha sonra tekrar bakabilirsin.',
          en: 'Goals are unavailable right now. Please check again later.',
        )
      : pick(
          tr: 'İlk analizini tamamladığında hedef ilerlemen burada görünür.',
          en: 'Your goal progress will appear here after your first analysis.',
        );
  String goalTitle(String id, {String? fallback}) {
    return switch (id) {
      'weekly_analysis_count' => pick(
        tr: 'Haftalık 5 analiz',
        en: '5 analyses per week',
      ),
      'average_score_85' => pick(
        tr: 'Ortalama skoru 85 üstüne çıkar',
        en: 'Raise average score above 85',
      ),
      'total_reps_200' => pick(
        tr: 'Haftalık 200 tekrar',
        en: '200 reps per week',
      ),
      _ => fallback ?? id,
    };
  }

  String goalDescription(String id, {String? fallback}) {
    return switch (id) {
      'weekly_analysis_count' => pick(
        tr: 'Bu hafta en az 5 canlı analiz tamamla.',
        en: 'Complete at least 5 live analyses this week.',
      ),
      'average_score_85' => pick(
        tr: 'Form kalitesini koruyarak ortalama skorunu yükselt.',
        en: 'Raise your average score while maintaining form quality.',
      ),
      'total_reps_200' => pick(
        tr: 'Haftalık toplam tekrar hacmini kontrollü şekilde artır.',
        en: 'Increase your weekly total rep volume in a controlled way.',
      ),
      _ => fallback ?? id,
    };
  }

  String goalUnit(String id, {String? fallback}) {
    return switch (id) {
      'weekly_analysis_count' => pick(tr: 'analiz', en: 'analyses'),
      'average_score_85' => pick(tr: 'skor', en: 'score'),
      'total_reps_200' => pick(tr: 'tekrar', en: 'reps'),
      _ => fallback ?? '',
    };
  }

  // Chat shell
  String get aiCoachSubtitle => pick(
    tr: 'Form, tempo ve antrenman önerileri için demo sohbet alanı.',
    en: 'Demo chat for form, tempo, and workout suggestions.',
  );
  String get coachInputHint =>
      pick(tr: 'Coach’a bir soru yaz...', en: 'Ask the coach a question...');
  String get messagesLoadFailed => pick(
    tr: 'Mesajlar yüklenemedi. Lütfen tekrar dene.',
    en: 'Messages could not be loaded. Please try again.',
  );
  String get messageSendFailed => pick(
    tr: 'Mesaj gönderilemedi. Lütfen tekrar dene.',
    en: 'Message could not be sent. Please try again.',
  );

  // How to use
  String get quickFlow => pick(tr: 'Kısa Akış', en: 'Quick Flow');
  String get smallTips => pick(tr: 'Küçük İpuçları', en: 'Quick Tips');
  String get howToUseIntroTitle => pick(
    tr: 'Antrenmanını daha okunur hale getir',
    en: 'Make your workout easier to understand',
  );
  String get howToUseIntroBody => pick(
    tr: 'Bu uygulama, hareket formunu kameradan takip ederek tekrar, skor ve temel geri bildirim üretir. Oturum sonunda sonuçlarını kaydeder, böylece ilerlemeni sonradan inceleyebilirsin.',
    en: 'This app tracks your movement form through the camera to produce rep counts, scores, and basic feedback. It saves your results at the end of the session so you can review your progress later.',
  );
  String get chooseExerciseStep =>
      pick(tr: 'Hareketi seç', en: 'Choose an exercise');
  String get chooseExerciseStepBody => pick(
    tr: 'Analiz için hazır olan hareketle devam et.',
    en: 'Continue with an exercise that is ready for analysis.',
  );
  String get positionCameraStep =>
      pick(tr: 'Kamerayı konumla', en: 'Position the camera');
  String get positionCameraStepBody => pick(
    tr: 'Vücudun kadrajda net görünsün, telefon sabit kalsın.',
    en: 'Keep your whole body clearly visible and the phone stable.',
  );
  String get startAnalysisStep =>
      pick(tr: 'Analizi başlat', en: 'Start the analysis');
  String get startAnalysisStepBody => pick(
    tr: 'Hareketi kontrollü yap, anlık geri bildirimi takip et.',
    en: 'Move with control and follow the live feedback.',
  );
  String get reviewSummaryStep =>
      pick(tr: 'Özetini incele', en: 'Review your summary');
  String get reviewSummaryStepBody => pick(
    tr: 'Oturum sonunda skorunu ve tekrarlarını gözden geçir.',
    en: 'Review your score and reps at the end of the session.',
  );
  String get tipFullBodyVisible => pick(
    tr: 'Tüm vücudunu mümkün olduğunca kadrajda tut.',
    en: 'Keep your whole body in frame whenever possible.',
  );
  String get tipStableCamera => pick(
    tr: 'Telefonu sabit bir yüzeye yerleştir.',
    en: 'Place the phone on a stable surface.',
  );
  String get tipLighting => pick(
    tr: 'Eklem noktalarının seçilebilmesi için yeterli ışık kullan.',
    en: 'Use enough light for your joints to remain visible.',
  );
  String get tipControlledMovement => pick(
    tr: 'Tekrarları kontrollü yap; hızlı hareket ölçümü zorlaştırabilir.',
    en: 'Perform reps with control; moving too quickly can reduce measurement quality.',
  );

  // Exercise selection / guide shell
  String get analysisActive => pick(tr: 'Analiz aktif', en: 'Analysis active');
  String get guideOnlyForNow =>
      pick(tr: 'Şimdilik rehber içeriği', en: 'Guide content only for now');
  String get exerciseNotActiveForAnalysis => pick(
    tr: 'Bu hareket şu an analiz için aktif değil. Rehberden inceleyebilirsin.',
    en: 'This exercise is not active for analysis yet. You can review it in the guide.',
  );
  String get all => pick(tr: 'Tümü', en: 'All');
  String get purpose => pick(tr: 'Amaç', en: 'Purpose');
  String get setup => pick(tr: 'Kurulum', en: 'Setup');
  String get techniqueTips => pick(tr: 'Teknik İpuçları', en: 'Technique Tips');
  String get commonMistakes =>
      pick(tr: 'Yaygın Hatalar', en: 'Common Mistakes');
  String source(String label) {
    final localizedLabel = isTurkish
        ? switch (label) {
            'Technique reference' => 'Teknik referans',
            'Beginner technique video' => 'Başlangıç teknik videosu',
            'Simultaneous standing curl demo' =>
              'Eş zamanlı ayakta biseps büküş demosu',
            'Bench dip technique reference' => 'Bench dip teknik referansı',
            _ => label,
          }
        : label;
    return pick(tr: 'Kaynak: $localizedLabel', en: 'Source: $localizedLabel');
  }

  String get watchOnYoutube =>
      pick(tr: 'YouTube’da İzle', en: 'Watch on YouTube');
  String get videoLinkOpenFailed => pick(
    tr: 'Video bağlantısı açılamadı.',
    en: 'The video link could not be opened.',
  );
  String get noGuideContentForDifficulty => pick(
    tr: 'Bu zorlukta rehber içeriği bulunamadı.',
    en: 'No guide content was found for this difficulty.',
  );
  String difficultyLabel(String name) {
    return switch (name) {
      'beginner' => pick(tr: 'Başlangıç', en: 'Beginner'),
      'intermediate' => pick(tr: 'Orta', en: 'Intermediate'),
      'advanced' => pick(tr: 'İleri', en: 'Advanced'),
      _ => name,
    };
  }

  String exerciseTitle(String id) {
    return switch (id) {
      'squat' => 'Squat',
      'plank' => 'Plank',
      'hollow_hold' => 'Hollow Hold',
      'lunge' => pick(tr: 'Sabit Lunge', en: 'Stationary Lunge'),
      'push_up' => pick(tr: 'Şınav', en: 'Push-up'),
      'sit_up' => pick(tr: 'Mekik', en: 'Sit-up'),
      'biceps_curl' => pick(tr: 'Biseps Curl', en: 'Biceps Curl'),
      'lying_leg_raise' => pick(
        tr: 'Yatarak Bacak Kaldırma',
        en: 'Lying Leg Raise',
      ),
      'triceps_dip' => pick(tr: 'Bench Dip', en: 'Bench Dip'),
      'romanian_deadlift' => pick(
        tr: 'Romen Deadlift',
        en: 'Romanian Deadlift',
      ),
      'lateral_raise' => pick(tr: 'Yana Kol Kaldırma', en: 'Lateral Raise'),
      'shoulder_press' => pick(tr: 'Omuz Press', en: 'Shoulder Press'),
      'calf_raise' => pick(tr: 'Baldır Kaldırma', en: 'Calf Raise'),
      'front_raise' => pick(tr: 'Öne Kol Kaldırma', en: 'Front Raise'),
      'glute_bridge' => pick(tr: 'Kalça Köprüsü', en: 'Glute Bridge'),
      'wall_sit' => pick(tr: 'Duvar Oturuşu', en: 'Wall Sit'),
      'side_plank' => pick(tr: 'Yan Plank', en: 'Side Plank'),
      'jumping_jack' => 'Jumping Jack',
      _ =>
        id
            .split('_')
            .where((part) => part.isNotEmpty)
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(' '),
    };
  }

  // Workout / assessment / session surfaces
  String get close => pick(tr: 'Kapat', en: 'Close');
  String get back => pick(tr: 'Geri Dön', en: 'Go Back');
  String get openSettings => pick(tr: 'Ayarları Aç', en: 'Open Settings');
  String get checking => pick(tr: 'Kontrol Ediliyor', en: 'Checking');
  String get grantCameraPermission =>
      pick(tr: 'Kamera İzni Ver', en: 'Grant Camera Permission');
  String get cameraPermission =>
      pick(tr: 'Kamera İzni', en: 'Camera Permission');
  String get cameraPermissionRequired =>
      pick(tr: 'Kamera İzni Gerekli', en: 'Camera Permission Required');
  String get cameraPermissionRestrictedMessage => pick(
    tr: 'Bu cihazda kamera izni kısıtlanmış görünüyor. Devam etmek için cihaz ayarlarını kontrol et.',
    en: 'Camera access appears to be restricted on this device. Check the device settings to continue.',
  );
  String get cameraPermissionPermanentlyDeniedMessage => pick(
    tr: 'Kamera izni kalıcı olarak kapalı. Analize devam etmek için telefon ayarlarından kamera iznini açman gerekiyor.',
    en: 'Camera permission is permanently disabled. Enable camera access in your phone settings to continue the analysis.',
  );
  String get cameraPermissionDeniedMessage => pick(
    tr: 'Kamera izni verilmedi. Hazır olduğunda tekrar deneyebilirsin; izin verilene kadar burada güvenli şekilde bekleyeceğiz.',
    en: 'Camera permission was not granted. You can try again when you are ready; the app will wait here until permission is available.',
  );
  String get cameraPermissionPromptMessage => pick(
    tr: 'Analize başlamadan önce kamera iznine ihtiyacımız var. İzin istemek için aşağıdaki butona dokun.',
    en: 'Camera permission is required before analysis can start. Tap the button below to request access.',
  );
  String get cameraPermissionRationale => pick(
    tr: 'Vücut eklemlerini algılamak, hareket formunu analiz etmek ve tekrarları gerçek zamanlı saymak için kamera izni gerekiyor.',
    en: 'Camera access is required to detect body joints, analyze movement form, and count repetitions in real time.',
  );
  String get cameraDetectsJoints =>
      pick(tr: 'Vücut eklemlerini algılar.', en: 'Detects body joints.');
  String get cameraEvaluatesForm => pick(
    tr: 'Hareket formunu gerçek zamanlı değerlendirir.',
    en: 'Evaluates movement form in real time.',
  );
  String get cameraCountsReps => pick(
    tr: 'Doğru tekrarları saymaya yardımcı olur.',
    en: 'Helps count valid repetitions.',
  );
  String get cameraPrivacyNotice => pick(
    tr: 'Görüntüler kesinlikle depolanmaz veya bir yere gönderilmez.',
    en: 'Camera images are never stored or sent anywhere.',
  );
  String get selectExerciseBeforeCameraTitle => pick(
    tr: 'Analiz için hareket seç',
    en: 'Choose an exercise for analysis',
  );
  String get selectExerciseBeforeCameraMessage => pick(
    tr: 'Kamera izni akışına girmeden önce hangi hareketi analiz etmek istediğini seçmelisin.',
    en: 'Choose the exercise you want to analyze before entering the camera permission flow.',
  );
  String get preparation => pick(tr: 'Hazırlık', en: 'Preparation');
  String get selectExerciseBeforePreparationTitle => pick(
    tr: 'Hazırlıktan önce hareket seç',
    en: 'Choose an exercise before preparation',
  );
  String get selectExerciseBeforePreparationMessage => pick(
    tr: 'Kalibrasyon ve analiz adımlarına geçmeden önce geçerli bir hareket seçimi gerekiyor.',
    en: 'A valid exercise selection is required before calibration and analysis can begin.',
  );
  String preparationForExercise(String exerciseName) => pick(
    tr: '$exerciseName analizi öncesi',
    en: 'Before $exerciseName analysis',
  );
  String get preparationSubtitle => pick(
    tr: 'Daha doğru sonuçlar için kısa bir hazırlık kontrolü yap.',
    en: 'Complete a quick preparation check for more reliable results.',
  );
  String unsupportedExerciseFallback(String selected, String active) => pick(
    tr: '$selected henüz aktif analiz için desteklenmiyor. Şimdilik $active analizi ile devam edebilirsin.',
    en: '$selected is not supported for active analysis yet. You can continue with $active analysis for now.',
  );
  String get preparationTipStablePhone => pick(
    tr: 'Telefonu sabit bir yere koy.',
    en: 'Place the phone on a stable surface.',
  );
  String get preparationTipFullBody => pick(
    tr: 'Tüm vücudun kamerada görünsün.',
    en: 'Keep your whole body visible in the camera.',
  );
  String get preparationTipLighting => pick(
    tr: 'Ortam ışığı yeterli olsun.',
    en: 'Make sure the lighting is sufficient.',
  );
  String get preparationTipControlledMovement => pick(
    tr: 'Hareketi kontrollü yap.',
    en: 'Perform the movement with control.',
  );
  String get analysisConfigLoadFailed => pick(
    tr: 'Analiz yapılandırması yüklenemedi.',
    en: 'Analysis configuration could not be loaded.',
  );
  String get analysisConfigLoading => pick(
    tr: 'Analiz yapılandırması hazırlanıyor...',
    en: 'Preparing analysis configuration...',
  );
  String get analysisConfigRequiredMessage => pick(
    tr: 'Egzersiz ayarları hazır olmadan canlı analiz başlatılamaz.',
    en: 'Live analysis cannot start until the exercise configuration is ready.',
  );

  // Assessment surfaces
  String get assessmentMode =>
      pick(tr: 'Değerlendirme Modu', en: 'Assessment Mode');
  String get assessmentDisclaimer => pick(
    tr: 'Bu sonuçlar kamera tabanlı ürün ölçümleridir; klinik tanı veya tıbbi değerlendirme değildir.',
    en: 'These results are camera-based product measurements; they are not a clinical diagnosis or medical assessment.',
  );
  String assessmentTitle(String typeName) {
    return switch (typeName) {
      'squat' => pick(tr: 'Squat Değerlendirmesi', en: 'Squat Assessment'),
      'balance' => pick(tr: 'Denge Değerlendirmesi', en: 'Balance Assessment'),
      'shoulderMobility' => pick(
        tr: 'Omuz Elevasyon Değerlendirmesi',
        en: 'Shoulder Elevation Assessment',
      ),
      _ => typeName,
    };
  }

  String get squatAssessmentSubtitle => pick(
    tr: 'Yan görünümde izlenen taraftaki diz fleksiyonu, derinlik ve gövde eğimi.',
    en: 'Knee flexion, depth, and torso inclination measured from the tracked side view.',
  );
  String get balanceAssessmentSubtitle => pick(
    tr: 'Ön görünümde kesintisiz tek ayak duruşu ve görüntü düzlemindeki salınımdan türetilen stabilite.',
    en: 'Continuous single-leg stance and stability derived from sway in the image plane from a front view.',
  );
  String get shoulderAssessmentSubtitle => pick(
    tr: 'Ön görünümde iki yana kol elevasyonu, sağ-sol farkı ve yanal gövde eğimi.',
    en: 'Bilateral arm elevation, left-right difference, and lateral torso inclination from a front view.',
  );
  String get chooseStandingFoot =>
      pick(tr: 'Duruş ayağını seç', en: 'Choose the standing foot');
  String get leftFoot => pick(tr: 'Sol ayak', en: 'Left foot');
  String get rightFoot => pick(tr: 'Sağ ayak', en: 'Right foot');
  String get assessmentCameraPermissionRequired => pick(
    tr: 'Değerlendirme için kamera izni gerekli.',
    en: 'Camera permission is required for the assessment.',
  );
  String get chooseAssessmentFirst => pick(
    tr: 'Önce bir değerlendirme seçmelisin.',
    en: 'Choose an assessment first.',
  );
  String cameraOpenFailed(Object error) => pick(
    tr: 'Kamera açılamadı: $error',
    en: 'Camera could not be opened: $error',
  );
  String get viewResult => pick(tr: 'Sonucu Gör', en: 'View Result');
  String validSamples(int count) =>
      pick(tr: 'Geçerli örnek: $count', en: 'Valid samples: $count');
  String get assessmentResult =>
      pick(tr: 'Değerlendirme sonucu', en: 'Assessment Result');
  String get insufficientMeasurement =>
      pick(tr: 'Yetersiz ölçüm', en: 'Insufficient Measurement');
  String get insufficientMeasurementDescription => pick(
    tr: 'Güvenilir bir sonuç göstermek için yeterli ve kesintisiz ölçüm alınamadı. Pozisyonunu düzenleyip tekrar deneyebilirsin.',
    en: 'There was not enough continuous measurement data to show a reliable result. Adjust your position and try again.',
  );
  String get yes => pick(tr: 'Evet', en: 'Yes');
  String get no => pick(tr: 'Hayır', en: 'No');
  String get kneeFlexion => pick(tr: 'Diz fleksiyonu', en: 'Knee flexion');
  String get hipReachedKneeHeight =>
      pick(tr: 'Kalça diz seviyesine indi', en: 'Hip reached knee height');
  String get torsoInclination =>
      pick(tr: 'Gövde eğimi', en: 'Torso inclination');
  String get stabilityScore =>
      pick(tr: 'Stabilite skoru', en: 'Stability score');
  String get continuousStanceDuration =>
      pick(tr: 'Kesintisiz duruş süresi', en: 'Continuous stance duration');
  String get leftMaximumElevation =>
      pick(tr: 'Sol maksimum elevasyon', en: 'Left maximum elevation');
  String get rightMaximumElevation =>
      pick(tr: 'Sağ maksimum elevasyon', en: 'Right maximum elevation');
  String get leftRightDifference =>
      pick(tr: 'Sağ-sol farkı', en: 'Left-right difference');
  String get leftMaximumLateralTorsoInclination => pick(
    tr: 'Sol maksimumda yanal gövde eğimi',
    en: 'Lateral torso inclination at left maximum',
  );
  String get rightMaximumLateralTorsoInclination => pick(
    tr: 'Sağ maksimumda yanal gövde eğimi',
    en: 'Lateral torso inclination at right maximum',
  );
  String secondsValue(double seconds) => pick(
    tr: '${seconds.toStringAsFixed(1)} sn',
    en: '${seconds.toStringAsFixed(1)} s',
  );

  // Session history / report
  String get historyRequiresAnalysis => pick(
    tr: 'Geçmiş oturumları görmek için önce bir analiz başlat.',
    en: 'Start an analysis first to view session history.',
  );
  String get historyLoadFailed => pick(
    tr: 'Geçmiş oturumlar yüklenemedi. Lütfen tekrar dene.',
    en: 'Session history could not be loaded. Please try again.',
  );
  String get historyLoadMoreFailed => pick(
    tr: 'Daha fazla oturum yüklenemedi. Lütfen tekrar dene.',
    en: 'More sessions could not be loaded. Please try again.',
  );
  String get historyUnavailable =>
      pick(tr: 'Geçmiş yüklenemedi', en: 'History unavailable');
  String get noSessionsYet =>
      pick(tr: 'Henüz oturum yok', en: 'No sessions yet');
  String get savedWorkoutsAppearHere => pick(
    tr: 'Kaydedilmiş antrenmanların burada görünecek.',
    en: 'Your saved workouts will appear here.',
  );
  String get loadMore => pick(tr: 'Daha Fazla Yükle', en: 'Load More');
  String get duration => pick(tr: 'Süre', en: 'Duration');
  String get totalHold => pick(tr: 'Toplam Tutuş', en: 'Total Hold');
  String get bestHold => pick(tr: 'En İyi Tutuş', en: 'Best Hold');
  String get interruptions => pick(tr: 'Kesinti', en: 'Breaks');
  String get reps => pick(tr: 'Tekrar', en: 'Reps');
  String get averageScoreShort => pick(tr: 'Ort. Skor', en: 'Avg. Score');
  String get bestShort => pick(tr: 'En İyi', en: 'Best');
  String get warnings => pick(tr: 'Uyarı', en: 'Warnings');
  String get sessionReport => pick(tr: 'Oturum Raporu', en: 'Session Report');
  String get repDetailsLoadFailed => pick(
    tr: 'Tekrar detayları yüklenemedi. Lütfen tekrar dene.',
    en: 'Rep details could not be loaded. Please try again.',
  );
  String get analysis => pick(tr: 'Analiz', en: 'Analysis');
  String get totalReps => pick(tr: 'Toplam Tekrar', en: 'Total Reps');
  String get averageScore => pick(tr: 'Ortalama Skor', en: 'Average Score');
  String get scoreView => pick(tr: 'Skor Görünümü', en: 'Score View');
  String get holdSummary => pick(tr: 'Tutuş Özeti', en: 'Hold Summary');
  String get reportSummary => pick(tr: 'Rapor Özeti', en: 'Report Summary');
  String get recommendations => pick(tr: 'Öneriler', en: 'Recommendations');
  String get repDetails => pick(tr: 'Tekrar Detayları', en: 'Rep Details');
  String get noRepDetails => pick(
    tr: 'Bu oturumda tekrar detayları kaydedilmemiş. Eski oturumlarda yalnızca özet veriler bulunabilir.',
    en: 'Rep details were not saved for this session. Older sessions may contain summary data only.',
  );
  String get showingCachedRepDetails => pick(
    tr: 'Güncel detaylar alınamadı; eldeki kayıt gösteriliyor.',
    en: 'Fresh details could not be loaded; the available saved data is shown.',
  );
  String get status => pick(tr: 'Durum', en: 'Status');
  String get score => pick(tr: 'Skor', en: 'Score');
  String get side => pick(tr: 'Taraf', en: 'Side');
  String get primaryMetric => pick(tr: 'Birincil Metrik', en: 'Primary Metric');
  String get worstForm => pick(tr: 'En Kötü Form', en: 'Worst Form');
  String get descentAscent => pick(tr: 'İniş / Çıkış', en: 'Descent / Ascent');
  String repNumber(int index) => pick(tr: 'Tekrar $index', en: 'Rep $index');
  String primaryIssue(String issue) =>
      pick(tr: 'Birincil sorun: $issue', en: 'Primary issue: $issue');
  String feedbackLabel(String feedback) =>
      pick(tr: 'Geri bildirim: $feedback', en: 'Feedback: $feedback');
  String get valid => pick(tr: 'Geçerli', en: 'Valid');
  String get lowConfidence => pick(tr: 'Düşük Güven', en: 'Low Confidence');
  String get invalid => pick(tr: 'Geçersiz', en: 'Invalid');
  String get uncertain => pick(tr: 'Belirsiz', en: 'Unknown');
  String get rangeRep => pick(tr: 'Tekrar Analizi', en: 'Range Rep');
  String get left => pick(tr: 'Sol', en: 'Left');
  String get right => pick(tr: 'Sağ', en: 'Right');
  String get insufficientRangeOfMotion =>
      pick(tr: 'Yetersiz hareket açıklığı', en: 'Insufficient range of motion');
  String get excessiveDescentSpeed =>
      pick(tr: 'İniş çok hızlı', en: 'Descent too fast');
  String get excessiveAscentSpeed =>
      pick(tr: 'Çıkış çok hızlı', en: 'Ascent too fast');
  String get persistentFormBreak =>
      pick(tr: 'Kalıcı form bozulması', en: 'Persistent form break');
  String get coverageLoss =>
      pick(tr: 'Görünürlük kaybı', en: 'Visibility loss');
  String get sideSwitchDuringRep =>
      pick(tr: 'Tekrar içinde taraf değişimi', en: 'Side switch during rep');
  String get incompletePhase =>
      pick(tr: 'Eksik faz tamamlanması', en: 'Incomplete phase');
  String get bestScore => pick(tr: 'En İyi Skor', en: 'Best Score');
  String get lowestScore => pick(tr: 'En Düşük Skor', en: 'Lowest Score');
  String get validReps => pick(tr: 'Geçerli', en: 'Valid');
  String get invalidReps => pick(tr: 'Geçersiz', en: 'Invalid');
  String get formWarnings => pick(tr: 'Form Uyarısı', en: 'Form Warnings');
  String get formViolations => pick(tr: 'Form İhlali', en: 'Form Violations');
  String get visibilityLoss =>
      pick(tr: 'Görünürlük Kaybı', en: 'Visibility Loss');
  String get sideChanges => pick(tr: 'Taraf Değişimi', en: 'Side Changes');

  // Score trend
  String formScoreTrend(String exerciseName) => pick(
    tr: '$exerciseName Form Skoru Trendi',
    en: '$exerciseName Form Score Trend',
  );
  String get viewDetails => pick(tr: 'Detayı Gör', en: 'View Details');
  String formScoreChangeSubtitle(String exerciseName) => pick(
    tr: '$exerciseName oturumlarındaki form skoru değişimi',
    en: 'Form score change across $exerciseName sessions',
  );
  String get noFormScoreToChart => pick(
    tr: 'Henüz çizilecek form skoru yok.',
    en: 'There is no form score to chart yet.',
  );
  String get formScoreDataUnavailable => pick(
    tr: 'Form skoru verisi alınamadı.',
    en: 'Form score data could not be loaded.',
  );
  String get tryAgainLater => pick(
    tr: 'Biraz sonra tekrar deneyebilirsin.',
    en: 'Try again in a moment.',
  );
  String formScoreTrendUnavailable(String exerciseName) => pick(
    tr: '$exerciseName form skoru trendi hazırlanamadı.',
    en: 'The form score trend for $exerciseName could not be prepared.',
  );
  String formScoreTrendEmpty(String exerciseName) => pick(
    tr: '$exerciseName için henüz form skoru trendi yok.',
    en: 'There is no form score trend for $exerciseName yet.',
  );
  String get formScoreTrendEmptyDetail => pick(
    tr: 'Bu egzersizde form skoru üreten analizler tamamlandığında değişim burada görünür.',
    en: 'The trend will appear here after analyses that produce a form score are completed for this exercise.',
  );
  String formScoreTrendChronological(String exerciseName) => pick(
    tr: '$exerciseName oturumlarının tarih sırasına göre form skoru değişimi.',
    en: 'Form score change across $exerciseName sessions in chronological order.',
  );
  String get session => pick(tr: 'Oturum', en: 'Sessions');
  String get latestFormScore =>
      pick(tr: 'Son Form Skoru', en: 'Latest Form Score');
  String get bestFormScore =>
      pick(tr: 'En İyi Form Skoru', en: 'Best Form Score');

  // Planned workout
  String get plannedWorkoutIntro => pick(
    tr: 'Hareketleri seç. Her dinamik hareket 10 tekrar, hold hareketi 30 saniye olarak başlar. Set tamamlanınca sonraki adıma sen geçersin.',
    en: 'Choose your exercises. Each dynamic exercise starts at 10 reps and each hold exercise at 30 seconds. You advance to the next step after completing a set.',
  );
  String get roundCount => pick(tr: 'Tur sayısı', en: 'Number of rounds');
  String get selectAtLeastOneExercise =>
      pick(tr: 'En az bir hareket seç', en: 'Select at least one exercise');
  String startWithExerciseCount(int count) => pick(
    tr: '$count hareketle başla',
    en: 'Start with $count ${count == 1 ? 'exercise' : 'exercises'}',
  );
  String get thirtySecondHold =>
      pick(tr: '30 saniye tutuş', en: '30-second hold');
  String get tenReps => pick(tr: '10 tekrar', en: '10 reps');
  String targetSetLabel(String target) =>
      pick(tr: '1 set • $target', en: '1 set • $target');
  String get workoutSummary =>
      pick(tr: 'Antrenman Özeti', en: 'Workout Summary');
  String get noCompletedPlan => pick(
    tr: 'Tamamlanmış bir plan bulunamadı.',
    en: 'No completed workout plan was found.',
  );
  String get planCompleted => pick(tr: 'Plan tamamlandı', en: 'Plan completed');
  String get completedSets => pick(tr: 'Tamamlanan set', en: 'Completed sets');
  String get totalDuration => pick(tr: 'Toplam süre', en: 'Total duration');
  String get returnHome => pick(tr: 'Ana Sayfaya Dön', en: 'Return Home');
  String workoutAggregateSummary({
    required int sets,
    required int reps,
    required String holdDuration,
  }) => pick(
    tr: '$sets set • $reps tekrar • $holdDuration tutuş',
    en: '$sets sets • $reps reps • $holdDuration hold',
  );

  // Workout summary / live analysis chrome
  String get sessionDataMissing =>
      pick(tr: 'Oturum verisi bulunamadı', en: 'Session data not found');
  String get sessionDataMissingDetail =>
      pick(tr: 'Oturum verisi bulunamadı.', en: 'Session data was not found.');
  String exerciseSummary(String exerciseName) =>
      pick(tr: '$exerciseName özeti', en: '$exerciseName summary');
  String get summaryAppearsAfterAnalysis => pick(
    tr: 'Canlı analiz tamamlandığında oturum özeti burada görünür.',
    en: 'The session summary will appear here after live analysis is completed.',
  );
  String get summaryUsesRecordedValues => pick(
    tr: 'Canlı analizden oluşturulan gerçek oturum değerleri.',
    en: 'Recorded session values generated by live analysis.',
  );
  String get preparing => pick(tr: 'Hazırlanıyor...', en: 'Preparing...');
  String get exerciseType => pick(tr: 'Egzersiz tipi', en: 'Exercise type');
  String get formBreaks => pick(tr: 'Form kesintisi', en: 'Form breaks');
  String get validRep => pick(tr: 'Geçerli tekrar', en: 'Valid reps');
  String get invalidRep => pick(tr: 'Geçersiz tekrar', en: 'Invalid reps');
  String get formWarning => pick(tr: 'Form uyarısı', en: 'Form warnings');
  String get workoutSummaryTotalHold =>
      pick(tr: 'Toplam tutuş', en: 'Total hold');
  String get workoutSummaryBestHold =>
      pick(tr: 'En iyi tutuş', en: 'Best hold');
  String get workoutSummaryFormBreaks =>
      pick(tr: 'Form kesintisi', en: 'Form breaks');
  String get workoutSummaryTotalReps =>
      pick(tr: 'Toplam tekrar', en: 'Total reps');
  String get workoutSummaryAverageScore =>
      pick(tr: 'Ortalama skor', en: 'Average score');
  String get workoutSummaryBestScore =>
      pick(tr: 'En iyi skor', en: 'Best score');
  String get workoutSummaryValidReps =>
      pick(tr: 'Geçerli tekrar', en: 'Valid reps');
  String get workoutSummaryInvalidReps =>
      pick(tr: 'Geçersiz tekrar', en: 'Invalid reps');
  String get averageRom => pick(tr: 'Ortalama ROM', en: 'Average ROM');
  String get averageTempo => pick(tr: 'Ortalama tempo', en: 'Average tempo');
  String get fastestRep => pick(tr: 'En hızlı tekrar', en: 'Fastest rep');
  String get slowestRep => pick(tr: 'En yavaş tekrar', en: 'Slowest rep');
  String get tempoConsistency =>
      pick(tr: 'Tempo tutarlılığı', en: 'Tempo consistency');
  String get leftReps => pick(tr: 'Sol tekrar', en: 'Left reps');
  String get rightReps => pick(tr: 'Sağ tekrar', en: 'Right reps');
  String get averageRomDifference =>
      pick(tr: 'Ortalama ROM farkı', en: 'Average ROM difference');
  String get asymmetryScore =>
      pick(tr: 'Asimetri skoru', en: 'Asymmetry score');
  String get finish => pick(tr: 'Bitir', en: 'Finish');
  String get endWorkout => pick(tr: 'Antrenmanı Bitir', en: 'End Workout');
  String get continueLabel => pick(tr: 'Devam', en: 'Continue');
  String get holdMetric => pick(tr: 'TUTUŞ', en: 'HOLD');
  String get repMetric => pick(tr: 'TEKRAR', en: 'REPS');
  String get bestMetric => pick(tr: 'EN İYİ', en: 'BEST');
  String get scoreMetric => pick(tr: 'SKOR', en: 'SCORE');
  String get angleMetric => pick(tr: 'AÇI', en: 'ANGLE');
  String get tempoMetric => 'TEMPO';
  String get stabilityMetric => pick(tr: 'STABİLİTE', en: 'STABILITY');
  String get asymmetryMetric => pick(tr: 'ASİMETRİ', en: 'ASYMMETRY');
  String liveStatusLine(String phase, String fps) => pick(
    tr: 'DURUM: ${workoutPhaseLabel(phase)} | ANALİZ FPS: $fps',
    en: 'STATUS: ${workoutPhaseLabel(phase)} | ANALYSIS FPS: $fps',
  );

  String workoutPhaseLabel(String phase) {
    return switch (phase.toUpperCase()) {
      'AWAITING_NEUTRAL' => pick(
        tr: 'Başlangıç bekleniyor',
        en: 'Awaiting start',
      ),
      'WAITING' => pick(tr: 'Bekleniyor', en: 'Waiting'),
      'NEUTRAL' || 'READY' => pick(tr: 'Hazır', en: 'Ready'),
      'DESCENDING' => pick(tr: 'Hareket', en: 'Movement'),
      'PEAK' => pick(tr: 'Geçiş', en: 'Transition'),
      'ASCENDING' => pick(tr: 'Dönüş', en: 'Return'),
      'HOLDING' => pick(tr: 'Tutuş', en: 'Holding'),
      'BROKEN' => pick(tr: 'Pozisyon bozuldu', en: 'Position broken'),
      _ => phase,
    };
  }

  String plannedWorkoutProgress({
    required int round,
    required int totalRounds,
    required int set,
    required int totalSets,
  }) => pick(
    tr: 'Tur $round/$totalRounds • Set $set/$totalSets',
    en: 'Round $round/$totalRounds • Set $set/$totalSets',
  );
  String repetitionProgress(int current, int target) =>
      pick(tr: '$current / $target tekrar', en: '$current / $target reps');
  String get finalSetCompleted =>
      pick(tr: 'Son set tamamlandı.', en: 'Final set completed.');
  String get setCompletedContinue => pick(
    tr: 'Set tamamlandı. Hazır olduğunda devam et.',
    en: 'Set completed. Continue when you are ready.',
  );
  String get liveAnalysisSelectionTitle => pick(
    tr: 'Canlı analize girmek için hareket seç',
    en: 'Choose an exercise to enter live analysis',
  );
  String get liveAnalysisSelectionMessage => pick(
    tr: 'Canlı analiz ekranı yalnızca geçerli bir hareket seçiminden sonra açılabilir.',
    en: 'The live analysis screen can only be opened after a valid exercise is selected.',
  );
  String get cameraRecovering => pick(
    tr: 'Kamera yeniden hazırlanıyor...',
    en: 'Preparing the camera again...',
  );
  String get cameraPermissionFallbackBody => pick(
    tr: 'Analize devam etmek için kamera iznini kontrol et.',
    en: 'Check camera permission to continue the analysis.',
  );
  String get checkPermission =>
      pick(tr: 'İzni Kontrol Et', en: 'Check Permission');
  String errorWithDetail(Object error) =>
      pick(tr: 'Hata: $error', en: 'Error: $error');

  // Runtime coaching / voice
  String get ttsLanguageTag => isTurkish ? 'tr-TR' : 'en-US';

  // Live assessment runtime
  String get assessmentFrameAnalysisFailed => pick(
    tr: 'Kare analiz edilemedi. Pozisyonunu koru.',
    en: 'The frame could not be analyzed. Hold your position.',
  );
  String get assessmentHoldPositionBriefly => pick(
    tr: 'Pozisyonunu kısa süre sabit tut.',
    en: 'Hold your position steady for a moment.',
  );
  String get assessmentNotReadyFeedback => pick(
    tr: 'Ölçüm henüz hazır değil. Yönergeyi tamamlamaya devam et.',
    en: 'The measurement is not ready yet. Keep following the instruction.',
  );
  String get assessmentCompletedFeedback =>
      pick(tr: 'Değerlendirme tamamlandı.', en: 'Assessment completed.');
  String get assessmentInsufficientFeedback => pick(
    tr: 'Sonuç için yeterli ölçüm toplanamadı.',
    en: 'Not enough measurement data was collected for a result.',
  );
  String get assessmentReadyFeedback => pick(
    tr: 'Ölçüm hazır. Sonucu görmek için aşağıdaki düğmeye dokun.',
    en: 'The measurement is ready. Tap the button below to view the result.',
  );
  String get balanceStanceResetFeedback => pick(
    tr: 'Tek ayak duruşu bozuldu. Süre yeniden başladı.',
    en: 'The single-leg stance was interrupted. The timer restarted.',
  );
  String get assessmentReady =>
      pick(tr: 'Ölçüm hazır', en: 'Measurement ready');
  String assessmentMovementProgress(int percent) => pick(
    tr: 'Hareket ilerlemesi: %$percent',
    en: 'Movement progress: $percent%',
  );
  String assessmentContinuousStanceProgress(String elapsed, String target) =>
      pick(
        tr: 'Kesintisiz duruş: $elapsed / $target sn',
        en: 'Continuous stance: $elapsed / $target s',
      );
  String assessmentElevationProgress(int percent) => pick(
    tr: 'Elevasyon ilerlemesi: %$percent',
    en: 'Elevation progress: $percent%',
  );
  String get squatAssessmentInstruction => pick(
    tr: 'Kameraya sol veya sağ yanını dön. Tüm vücudun kadrajdayken kontrollü bir squat yap ve tekrar ayağa kalk.',
    en: 'Turn your left or right side toward the camera. Keep your whole body in frame, perform one controlled squat, then stand back up.',
  );
  String get balanceAssessmentInstruction => pick(
    tr: 'Kameraya önden dön. Tüm vücudun kadrajdayken seçilen ayağın üzerinde kesintisiz sabit kal.',
    en: 'Face the camera. Keep your whole body in frame and remain steadily on the selected foot without interruption.',
  );
  String get shoulderAssessmentInstruction => pick(
    tr: 'Kameraya önden dön. Dirseklerini mümkün olduğunca düz tutarak kollarını gövdenin yanından iki yana doğru kontrollü biçimde kaldır.',
    en: 'Face the camera. Keep your elbows as straight as possible and raise both arms out to the sides with control.',
  );
  String get poseQualityLowConfidence => pick(
    tr: 'Görüntü yeterince net değil. Işığı artır ve tüm vücudunu görünür tut.',
    en: 'The image is not clear enough. Improve the lighting and keep your whole body visible.',
  );
  String get poseQualityGeometryUnavailable => pick(
    tr: 'Pozisyon ölçülemiyor. Kameradan biraz uzaklaşıp tüm vücudunu kadraja al.',
    en: 'Your position cannot be measured. Move slightly farther from the camera and keep your whole body in frame.',
  );
  String get poseQualityKeepRequiredJointsVisible => pick(
    tr: 'Tüm vücudunu kadraja al ve gerekli eklemleri görünür tut.',
    en: 'Keep your whole body in frame and make sure the required joints are visible.',
  );

  // Runtime errors / retry / persistence
  String get noCompletedSessionToDelete => pick(
    tr: 'Silinecek tamamlanmış oturum bulunamadı.',
    en: 'No completed session was found to delete.',
  );
  String get previousSessionDeleteFailed => pick(
    tr: 'Önceki oturum silinemedi. Tekrar deneme başlatılmadı.',
    en: 'The previous session could not be deleted. A retry was not started.',
  );
  String get analysisSessionPreparationFailed => pick(
    tr: 'Analiz oturumu hazırlanamadı. Lütfen tekrar dene.',
    en: 'The analysis session could not be prepared. Please try again.',
  );
  String get selectValidExerciseBeforeAnalysis => pick(
    tr: 'Analiz için önce geçerli bir hareket seçmelisin.',
    en: 'Choose a valid exercise before starting the analysis.',
  );
  String get sessionSaveFailed => pick(
    tr: 'Oturum kaydedilemedi. Lütfen tekrar dene.',
    en: 'The session could not be saved. Please try again.',
  );
  String get plannedStepMissingUser => pick(
    tr: 'Antrenman adımı kaydedilemedi: kullanıcı bulunamadı.',
    en: 'The workout step could not be saved: user not found.',
  );
  String get plannedStepMissingExercise => pick(
    tr: 'Aktif antrenman hareketi bulunamadı.',
    en: 'The active workout exercise could not be found.',
  );
  String get plannedStepSaveFailed => pick(
    tr: 'Antrenman adımı kaydedilemedi.',
    en: 'The workout step could not be saved.',
  );
  String get cameraPermissionAnalysisRequired => pick(
    tr: 'Kamera izni olmadan analiz başlatılamaz.',
    en: 'Analysis cannot start without camera permission.',
  );

  // Demo coach runtime
  String get coachWelcomeMessage => pick(
    tr: 'Merhaba, ben AI Coach. Form, squat tekniği veya antrenman planı hakkında kısa öneriler verebilirim.',
    en: 'Hi, I am AI Coach. I can give short suggestions about form, squat technique, or workout planning.',
  );
  String get coachPersonalizationHint => pick(
    tr: 'Canlı analiz verilerin geliştikçe burada daha kişisel öneriler görebileceksin.',
    en: 'As your live analysis data grows, you will see more personalized suggestions here.',
  );
  String get coachSquatReply => pick(
    tr: 'Squat için dizlerini ayak parmaklarınla aynı hatta tutmaya ve inişi kontrollü yapmaya odaklan.',
    en: 'For squats, keep your knees tracking in line with your toes and focus on a controlled descent.',
  );
  String get coachFormReply => pick(
    tr: 'Formu düzeltmek için tekrar hızını biraz düşür, gövdeni sabit tut ve hareket aralığını koru.',
    en: 'To improve your form, slow the rep slightly, keep your torso stable, and maintain your range of motion.',
  );
  String get coachPlanReply => pick(
    tr: 'Bugün kısa bir plan iyi olabilir: ısınma, 3 kontrollü set ve set aralarında yeterli dinlenme.',
    en: 'A short plan could work well today: warm up, complete 3 controlled sets, and rest enough between sets.',
  );
  String get coachDefaultReply => pick(
    tr: 'İyi gidiyorsun. Kısa, kontrollü setlerle form kalitesini korumaya devam et.',
    en: 'You are doing well. Keep protecting your form quality with short, controlled sets.',
  );

  // Localized session report copy
  String get sessionReportSummaryOnly => pick(
    tr: 'Bu oturumda tekrar detayları yok; yalnızca özet verileri gösteriliyor.',
    en: 'Rep details are unavailable for this session; only summary data is shown.',
  );
  String get sessionReportNoCompletedReps => pick(
    tr: 'Bu oturumda tamamlanmış tekrar kaydı yok.',
    en: 'No completed reps were recorded in this session.',
  );
  String sessionReportRangeSummary({
    required int totalReps,
    required int validReps,
    required int invalidReps,
    required int unknownReps,
    required double averageScore,
    String? topIssue,
  }) {
    if (isTurkish) {
      final parts = <String>['$totalReps tekrarın $validReps tanesi geçerli'];
      if (invalidReps > 0) {
        parts.add('$invalidReps tanesi geçersiz');
      }
      if (unknownReps > 0) {
        parts.add('$unknownReps tanesi belirsiz');
      }
      final summary = '${parts.join(', ')}.';
      if (topIssue != null && topIssue.isNotEmpty) {
        return '$summary En sık sorun: $topIssue.';
      }
      if (averageScore > 0) {
        return '$summary Ortalama skor ${averageScore.toStringAsFixed(0)}.';
      }
      return summary;
    }

    final parts = <String>['$validReps of $totalReps reps were valid'];
    if (invalidReps > 0) {
      parts.add('$invalidReps were invalid');
    }
    if (unknownReps > 0) {
      parts.add('$unknownReps were uncertain');
    }
    final summary = '${parts.join(', ')}.';
    if (topIssue != null && topIssue.isNotEmpty) {
      return '$summary Most common issue: $topIssue.';
    }
    if (averageScore > 0) {
      return '$summary Average score ${averageScore.toStringAsFixed(0)}.';
    }
    return summary;
  }

  String get holdSessionNoMeaningfulDuration => pick(
    tr: 'Bu tutuş oturumunda anlamlı tutuş süresi kaydedilmedi.',
    en: 'No meaningful hold duration was recorded in this hold session.',
  );
  String holdSessionSummary({
    required double totalSeconds,
    required double bestSeconds,
  }) => pick(
    tr: 'Toplam ${totalSeconds.toStringAsFixed(0)} sn tutuş kaydedildi. En iyi tek deneme ${bestSeconds.toStringAsFixed(0)} sn.',
    en: 'A total of ${totalSeconds.toStringAsFixed(0)} s of holding was recorded. The best single attempt was ${bestSeconds.toStringAsFixed(0)} s.',
  );

  String localizeReportIssue(String issue) {
    return switch (issue.toLowerCase()) {
      'yetersiz hareket açıklığı' ||
      'insufficient range of motion' => insufficientRangeOfMotion,
      'iniş çok hızlı' || 'descent too fast' => excessiveDescentSpeed,
      'çıkış çok hızlı' || 'ascent too fast' => excessiveAscentSpeed,
      'kalıcı form bozulması' || 'persistent form break' => persistentFormBreak,
      'görünürlük kaybı' || 'visibility loss' => coverageLoss,
      'tekrar içinde taraf değişimi' ||
      'side switch during rep' => sideSwitchDuringRep,
      'eksik faz tamamlanması' || 'incomplete phase' => incompletePhase,
      _ => issue,
    };
  }

  String localizeReportRecommendation(String recommendation) {
    return switch (recommendation) {
      'Daha derin tekrarlar için hareket açıklığını kontrollü biçimde artır.' =>
        pick(
          tr: 'Daha derin tekrarlar için hareket açıklığını kontrollü biçimde artır.',
          en: 'Increase your range of motion gradually and with control for deeper reps.',
        ),
      'Tekrarları tam iniş ve tam çıkış döngüsüyle tamamlamaya odaklan.' => pick(
        tr: 'Tekrarları tam iniş ve tam çıkış döngüsüyle tamamlamaya odaklan.',
        en: 'Focus on completing each rep through a full descent and ascent cycle.',
      ),
      'Skor dalgalanmasını azaltmak için tempoyu biraz yavaşlat ve ritmi sabitle.' =>
        pick(
          tr: 'Skor dalgalanmasını azaltmak için tempoyu biraz yavaşlat ve ritmi sabitle.',
          en: 'Slow the tempo slightly and keep a steady rhythm to reduce score variation.',
        ),
      'Form bozulmasını azaltmak için gövde hizasını ve diz kontrolünü daha sıkı koru.' =>
        pick(
          tr: 'Form bozulmasını azaltmak için gövde hizasını ve diz kontrolünü daha sıkı koru.',
          en: 'Maintain tighter torso alignment and knee control to reduce form breakdowns.',
        ),
      'Kamera açısını sabitle; bazı tekrarlarda görünürlük kaybı oluşmuş.' => pick(
        tr: 'Kamera açısını sabitle; bazı tekrarlarda görünürlük kaybı oluşmuş.',
        en: 'Keep the camera angle fixed; visibility was lost during some reps.',
      ),
      'Set boyunca aynı tarafı daha net gösterecek şekilde pozisyonunu koru.' =>
        pick(
          tr: 'Set boyunca aynı tarafı daha net gösterecek şekilde pozisyonunu koru.',
          en: 'Keep your position consistent so the same side remains clearly visible throughout the set.',
        ),
      'Genel kalite dengeli görünüyor; aynı kontrolü koruyarak tekrar sayısını kademeli artır.' =>
        pick(
          tr: 'Genel kalite dengeli görünüyor; aynı kontrolü koruyarak tekrar sayısını kademeli artır.',
          en: 'Overall quality looks balanced; increase your rep count gradually while maintaining the same control.',
        ),
      'Form uyarıları görüldüğü için sonraki sette hareket çizgisini daha kontrollü koru.' =>
        pick(
          tr: 'Form uyarıları görüldüğü için sonraki sette hareket çizgisini daha kontrollü koru.',
          en: 'Because form warnings were detected, keep the movement path more controlled in the next set.',
        ),
      'Düşük ortalama skorda önce tempo ve tam tekrar kalitesini toparlamak faydalı olur.' =>
        pick(
          tr: 'Düşük ortalama skorda önce tempo ve tam tekrar kalitesini toparlamak faydalı olur.',
          en: 'With a low average score, focus first on tempo and complete rep quality.',
        ),
      'Bu rapor özet veriye dayanıyor; benzer bir sonraki sette tekrar detaylarını da incelemek faydalı olur.' =>
        pick(
          tr: 'Bu rapor özet veriye dayanıyor; benzer bir sonraki sette tekrar detaylarını da incelemek faydalı olur.',
          en: 'This report is based on summary data; reviewing rep details in a similar future set may be useful.',
        ),
      'Hold boyunca vücut çizgisini daha sabit tut; form kesintileri görülmüş.' =>
        pick(
          tr: 'Tutuş boyunca vücut çizgisini daha sabit tut; form kesintileri görülmüş.',
          en: 'Keep your body line more stable throughout the hold; form breaks were detected.',
        ),
      'Kısa ama temiz tekrarlarla en iyi hold süresini kademeli artır.' => pick(
        tr: 'Kısa ama temiz denemelerle en iyi tutuş süresini kademeli artır.',
        en: 'Increase your best hold duration gradually with short, clean attempts.',
      ),
      'Süre dengeli görünüyor; aynı hizayı koruyarak toplam tutuş süresini artırabilirsin.' =>
        pick(
          tr: 'Süre dengeli görünüyor; aynı hizayı koruyarak toplam tutuş süresini artırabilirsin.',
          en: 'The duration looks balanced; you can increase total hold time while maintaining the same alignment.',
        ),
      'Önce pozisyonu kilitle, sonra süreyi azar azar uzat.' => pick(
        tr: 'Önce pozisyonu sabitle, sonra süreyi azar azar uzat.',
        en: 'Lock in the position first, then extend the duration gradually.',
      ),
      _ => recommendation,
    };
  }

  String weekdayShort(int weekday) {
    const tr = <String>['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    const en = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final index = weekday.clamp(1, 7) - 1;
    return isTurkish ? tr[index] : en[index];
  }
}
