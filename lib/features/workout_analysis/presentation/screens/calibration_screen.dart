import 'package:flutter/material.dart';

import 'live_analysis_screen.dart';

class CalibrationScreen extends StatelessWidget {
  const CalibrationScreen({super.key});

  static const List<String> _guidanceItems = [
    'Telefonu sabit bir yere koy.',
    'Tüm vücudun kamerada görünsün.',
    'Ortam ışığı yeterli olsun.',
    'Hareketi kontrollü yap.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Hazırlık'),
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
                'Analize başlamadan önce',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Daha doğru sonuçlar için kısa bir hazırlık kontrolü yap.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              ..._guidanceItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.greenAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
                      builder: (_) => const LiveAnalysisScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Analize Başla'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(54),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
