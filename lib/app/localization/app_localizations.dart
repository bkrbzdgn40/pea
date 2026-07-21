import 'package:flutter/widgets.dart';

/// Lightweight application copy for the locales currently exposed in Settings.
///
/// Feature-specific screens can migrate to this surface incrementally without
/// coupling locale selection to generated code or a remote translation layer.
class AppLocalizations {
  const AppLocalizations(this.locale);

  static const supportedLocales = <Locale>[Locale('tr'), Locale('en')];

  static AppLocalizations of(BuildContext context) {
    return AppLocalizations(Localizations.localeOf(context));
  }

  final Locale locale;

  bool get _isTurkish => locale.languageCode.toLowerCase() == 'tr';

  String get settings => _isTurkish ? 'Ayarlar' : 'Settings';
  String get language => _isTurkish ? 'Dil' : 'Language';
  String get appLanguage => _isTurkish ? 'Uygulama dili' : 'App language';
  String get turkish => _isTurkish ? 'Türkçe' : 'Turkish';
  String get english => _isTurkish ? 'İngilizce' : 'English';

  String get camera => _isTurkish ? 'Kamera' : 'Camera';
  String get cameraPreference =>
      _isTurkish ? 'Kamera tercihi' : 'Camera preference';
  String get frontCamera => _isTurkish ? 'Ön kamera' : 'Front camera';
  String get backCamera => _isTurkish ? 'Arka kamera' : 'Back camera';
  String get imageQuality => _isTurkish ? 'Görüntü kalitesi' : 'Image quality';
  String get low => _isTurkish ? 'Düşük' : 'Low';
  String get medium => _isTurkish ? 'Orta' : 'Medium';
  String get high => _isTurkish ? 'Yüksek' : 'High';
  String get settingsLoadFailed =>
      _isTurkish ? 'Ayarlar yüklenemedi' : 'Settings could not be loaded';
  String get retry => _isTurkish ? 'Tekrar dene' : 'Retry';

  String get home => _isTurkish ? 'Ana Sayfa' : 'Home';
  String get howToUse => _isTurkish ? 'Nasıl Kullanılır' : 'How to Use';
  String get selectExercise => _isTurkish ? 'Hareket Seç' : 'Select Exercise';
  String get sessionHistory =>
      _isTurkish ? 'Geçmiş Oturumlar' : 'Session History';
  String get exerciseGuide => _isTurkish ? 'Hareket Rehberi' : 'Exercise Guide';
  String get workoutMenu => _isTurkish ? 'Antrenman menüsü' : 'Workout menu';
}
