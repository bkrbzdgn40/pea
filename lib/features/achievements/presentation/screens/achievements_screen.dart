import 'package:flutter/material.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../data/demo_achievements.dart';
import '../models/achievement.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Başarılar',
      showDrawer: false,
      padding: EdgeInsets.zero,
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemCount: demoAchievements.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _AchievementsHeaderCard();
          }

          return _AchievementCard(achievement: demoAchievements[index - 1]);
        },
      ),
    );
  }
}

class _AchievementsHeaderCard extends StatelessWidget {
  const _AchievementsHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.emoji_events_rounded, color: Colors.greenAccent, size: 34),
          SizedBox(height: 14),
          Text(
            'İlerlemeni ve açılan rozetleri burada göreceksin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Bu rozetler demo veridir. Sonraki adımlarda gerçek oturum verilerine bağlanabilir.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = achievement.isUnlocked
        ? Colors.greenAccent
        : Colors.white54;
    final textColor = achievement.isUnlocked ? Colors.white : Colors.white60;
    final progressPercent = (achievement.normalizedProgress * 100).round();

    return Opacity(
      opacity: achievement.isUnlocked ? 1 : 0.78,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: achievement.isUnlocked ? Colors.greenAccent : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: foregroundColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    achievement.isUnlocked
                        ? Icons.emoji_events_rounded
                        : Icons.lock_outline_rounded,
                    color: foregroundColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement.requirementText,
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  achievement.isUnlocked ? 'Açık' : 'Kilitli',
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              achievement.description,
              style: TextStyle(color: textColor, fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: achievement.normalizedProgress,
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    color: foregroundColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '%$progressPercent',
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
