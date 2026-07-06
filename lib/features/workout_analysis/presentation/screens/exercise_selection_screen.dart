import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/exercise_type.dart';
import '../data/exercise_guide_contents.dart';
import '../models/exercise_guide_content.dart';
import '../providers/selected_exercise_provider.dart';
import 'camera_permission_screen.dart';

class ExerciseSelectionScreen extends ConsumerWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Hareket Seç'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: exerciseGuideContents.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final content = exerciseGuideContents[index];
            return _ExerciseSelectionCard(
              content: content,
              onTap: () => _handleExerciseTap(context, ref, content),
            );
          },
        ),
      ),
    );
  }

  void _handleExerciseTap(
    BuildContext context,
    WidgetRef ref,
    ExerciseGuideContent content,
  ) {
    if (!content.isAnalysisAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bu hareket şu an analiz için aktif değil. Rehberden inceleyebilirsin.',
          ),
        ),
      );
      return;
    }

    ref.read(selectedExerciseProvider.notifier).state = ExerciseType.fromId(
      content.id,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraPermissionScreen()),
    );
  }
}

class _ExerciseSelectionCard extends StatelessWidget {
  const _ExerciseSelectionCard({required this.content, required this.onTap});

  final ExerciseGuideContent content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = content.isAnalysisAvailable;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? Colors.greenAccent : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.greenAccent.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isActive
                    ? Icons.play_arrow_rounded
                    : Icons.lock_outline_rounded,
                color: isActive ? Colors.greenAccent : Colors.white54,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    content.subtitle,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isActive ? 'Analiz aktif' : 'Şimdilik rehber içeriği',
                    style: TextStyle(
                      color: isActive ? Colors.greenAccent : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              color: isActive ? Colors.greenAccent : Colors.white30,
            ),
          ],
        ),
      ),
    );
  }
}
