import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/app.dart';

// İzni isteyip uygulamayı başlatır.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kamera iznini uygulama başlamadan isteyelim
  await Permission.camera.request();

  runApp(const ProviderScope(child: PoseAnalysisApp()));
}
