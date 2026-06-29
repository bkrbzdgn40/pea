import 'package:flutter/material.dart';

import 'calibration_screen.dart';

class ExerciseSelectionScreen extends StatelessWidget {
  const ExerciseSelectionScreen({super.key});

  static const List<String> _exercises = [
    'Squat',
    'Şınav',
    'Lunge',
    'Plank',
    'Mekik',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Hareket Seç'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _exercises.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final exercise = _exercises[index];
          final isAvailable = exercise == 'Squat';

          return Card(
            color: const Color(0xFF151515),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              leading: Icon(
                Icons.fitness_center_rounded,
                color: isAvailable ? Colors.greenAccent : Colors.white38,
              ),
              title: Text(
                exercise,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                isAvailable ? 'Demo için hazır' : 'Yakında aktif olacak',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.58)),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () {
                if (isAvailable) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CalibrationScreen(),
                    ),
                  );
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bu hareket yakında aktif olacak'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
