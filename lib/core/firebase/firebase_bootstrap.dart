import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import 'firebase_failures.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<void>? _initialization;

  // Firebase başlatmasını tek seferlik hale getirir ve aynı anda gelen
  // çağrılarda var olan Future'ı döndürerek tekrar başlatmayı engeller.
  static Future<void> ensureInitialized() {
    final currentInitialization = _initialization;
    if (currentInitialization != null) {
      return currentInitialization;
    }

    final initialization = _initialize();
    _initialization = initialization;
    return initialization;
  }

  // Platforma uygun Firebase seçenekleriyle uygulamanın Firebase bağlantısını
  // kurar. Başlatma başarısız olursa cache'i temizleyip anlamlı hata fırlatır.
  static Future<void> _initialize() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on Object catch (error, stackTrace) {
      _initialization = null;
      throw FirebaseBootstrapFailure(
        message: 'Firebase could not be initialized.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
