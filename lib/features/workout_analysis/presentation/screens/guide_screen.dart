import 'package:flutter/material.dart';

import 'calibration_screen.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  static const List<String> _tips = [
    'Ayaklarını omuz genişliğinde aç.',
    'Sırtını dik tut.',
    'Kalçanı geriye doğru indir.',
    'Dizlerin ayak ucunu fazla geçmesin.',
    'Kontrollü şekilde yukarı kalk.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Hareket Rehberi'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Squat için kısa rehber',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              ..._tips.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.circle,
                        color: Colors.greenAccent,
                        size: 10,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          tip,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CalibrationScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Analize Başla'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
