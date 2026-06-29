import 'package:flutter/material.dart';

import 'camera_permission_screen.dart';

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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemCount: _exercises.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _ScreenHeader(
              title: 'Demo hareketini seç',
              subtitle:
                  'Şimdilik squat aktif. Diğer hareketler müşteri demosu için pasif bırakıldı.',
            );
          }

          final exercise = _exercises[index - 1];
          final isAvailable = exercise == 'Squat';

          return Card(
            color: const Color(0xFF151515),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.white12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
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
              trailing: Icon(
                isAvailable ? Icons.chevron_right : Icons.lock_outline,
                color: Colors.white54,
              ),
              onTap: () {
                if (isAvailable) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CameraPermissionScreen(),
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

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
