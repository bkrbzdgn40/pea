import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import '../features/auth/presentation/screens/auth_bootstrap_gate.dart';

class PoseAnalysisApp extends StatelessWidget {
  const PoseAnalysisApp({super.key});

  @override
  // MaterialApp seviyesindeki temel uygulama ayarlarını kurar ve açılışta
  // kullanıcı oturumunu hazırlayan kapıyı başlangıç ekranı olarak verir.
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PEA',
      theme: AppTheme.dark,
      home: const AuthBootstrapGate(),
    );
  }
}
