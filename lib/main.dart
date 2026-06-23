import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'features/workout_analysis/presentation/screens/live_analysis_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Kamera iznini uygulama başlamadan isteyelim
  await Permission.camera.request();

  runApp(
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pose Analysis',
      theme: ThemeData.dark(),
      home: const LiveAnalysisScreen(),
    );
  }
}
