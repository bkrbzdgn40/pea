import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/firebase/firebase_bootstrap.dart';

// Uygulama açılışında Flutter binding'ini hazırlar, Firebase'i başlatır
// ve Riverpod kapsayıcısı içindeki ana uygulamayı çalıştırır.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.ensureInitialized();

  runApp(const ProviderScope(child: PoseAnalysisApp()));
}
