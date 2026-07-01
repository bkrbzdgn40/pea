import 'package:flutter/material.dart';

import '../features/auth/presentation/screens/auth_bootstrap_gate.dart';

class PoseAnalysisApp extends StatelessWidget {
  const PoseAnalysisApp({super.key});

  @override
  // MaterialApp seviyesindeki temel uygulama ayarlarını kurar ve açılışta
  // kullanıcı oturumunu hazırlayan kapıyı başlangıç ekranı olarak verir.
  Widget build(BuildContext context) {
    // TODO: Move shared app configuration here as the architecture migration progresses.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pose Analysis',
      theme: ThemeData.dark(),
      home: const AuthBootstrapGate(),
    );
  }
}
