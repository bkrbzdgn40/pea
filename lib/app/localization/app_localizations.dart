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
  String source(String label) =>
      pick(tr: 'Kaynak: $label', en: 'Source: $label');
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
      'triceps_dip' => pick(tr: 'Triseps Dip', en: 'Triceps Dip'),
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

  String weekdayShort(int weekday) {
    const tr = <String>['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    const en = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final index = weekday.clamp(1, 7) - 1;
    return isTurkish ? tr[index] : en[index];
  }
}
