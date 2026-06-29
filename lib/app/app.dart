import 'package:flutter/material.dart';

import '../features/workout_analysis/presentation/screens/home_screen.dart';

class PoseAnalysisApp extends StatelessWidget {
  const PoseAnalysisApp({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Move shared app configuration here as the architecture migration progresses.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pose Analysis',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}
