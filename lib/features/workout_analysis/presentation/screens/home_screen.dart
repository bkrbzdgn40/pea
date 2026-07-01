import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/widgets/app_drawer.dart';
import '../../../achievements/presentation/data/demo_achievements.dart';
import '../../../achievements/presentation/providers/achievements_provider.dart';
import '../../../achievements/presentation/screens/achievements_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../goals/presentation/data/demo_workout_goals.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../models/home_dashboard_data.dart';
import '../providers/home_dashboard_provider.dart';
import 'camera_permission_screen.dart';
import 'exercise_selection_screen.dart';
import 'guide_screen.dart';
import 'session_history_screen.dart';
import 'settings_screen.dart';
import '../widgets/exercise_distribution_card.dart';
import '../widgets/home_feature_preview_card.dart';
import '../widgets/score_trend_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardData =
        ref.watch(homeDashboardProvider).valueOrNull ??
        HomeDashboardData.fallback();
    final goalsState = ref.watch(goalsProvider).valueOrNull;
    final goalPreview = goalsState == null || goalsState.goals.isEmpty
        ? demoWorkoutGoals.first
        : goalsState.goals.first;
    final achievementsState = ref.watch(achievementsProvider).valueOrNull;
    final achievementPreview =
        achievementsState == null || achievementsState.achievements.isEmpty
        ? demoAchievements.first
        : achievementsState.achievements.first;

    return Scaffold(
      drawer: const AppDrawer(currentPage: AppDrawerPage.home),
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Workout Analysis'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HomeHeroCard(),
              const SizedBox(height: 16),
              _DashboardSourceBadge(data: dashboardData),
              const SizedBox(height: 10),
              _DashboardStats(data: dashboardData),
              const SizedBox(height: 14),
              HomeFeaturePreviewCard(
                title: 'Haftalık Hedef',
                subtitle: goalPreview.title,
                icon: Icons.flag_rounded,
                progress: goalPreview.progress,
                trailingText:
                    '${_formatGoalValue(goalPreview.currentValue)} / ${_formatGoalValue(goalPreview.targetValue)} ${goalPreview.unit}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GoalsScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),
              HomeFeaturePreviewCard(
                title: 'Başarılar',
                subtitle: achievementPreview.title,
                icon: Icons.emoji_events_rounded,
                badgeText: achievementPreview.isUnlocked ? 'Açık' : null,
                progress: achievementPreview.normalizedProgress,
                trailingText: achievementPreview.requirementText,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AchievementsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              ScoreTrendCard(points: dashboardData.scoreTrend),
              const SizedBox(height: 14),
              ExerciseDistributionCard(
                items: dashboardData.exerciseDistribution,
              ),
              const SizedBox(height: 14),
              HomeFeaturePreviewCard(
                title: 'AI Coach',
                subtitle:
                    'Form analizi, günlük öneriler ve antrenman ipuçları yakında burada olacak.',
                icon: Icons.auto_awesome_rounded,
                badgeText: 'Yakında',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _HomeActionButton(
                icon: Icons.play_arrow_rounded,
                label: 'Analize Başla',
                isPrimary: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CameraPermissionScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _HomeActionButton(
                icon: Icons.directions_run_rounded,
                label: 'Hareket Seç',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExerciseSelectionScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _HomeActionButton(
                icon: Icons.menu_book_rounded,
                label: 'Hareket Rehberi',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GuideScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _HomeActionButton(
                icon: Icons.history_rounded,
                label: 'Geçmiş Oturumlar',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SessionHistoryScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeroCard extends StatelessWidget {
  const _HomeHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.greenAccent.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: Colors.greenAccent,
              size: 30,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Form Analiz Asistanı',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Canlı kamera analiziyle formunu takip et, tekrarlarını ölç ve antrenman geçmişini izle.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStats extends StatelessWidget {
  const _DashboardStats({required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;
        final cardWidth = isNarrow
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 20) / 3;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _DashboardStatCard(
              label: 'Toplam Analiz',
              value: data.totalAnalyses.toString(),
            ),
            _DashboardStatCard(
              label: 'Ortalama Skor',
              value: data.averageScore.toString(),
            ),
            _DashboardStatCard(
              label: 'Bu Hafta',
              value: data.thisWeekCount.toString(),
            ),
            _DashboardStatCard(
              label: 'En İyi Skor',
              value: data.bestScore.toString(),
            ),
          ].map((card) => SizedBox(width: cardWidth, child: card)).toList(),
        );
      },
    );
  }
}

class _DashboardSourceBadge extends StatelessWidget {
  const _DashboardSourceBadge({required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final isReal = data.source == HomeDashboardSource.real;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isReal
            ? Colors.greenAccent.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isReal ? Colors.greenAccent : Colors.white12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isReal ? Icons.verified_rounded : Icons.info_outline_rounded,
            color: isReal ? Colors.greenAccent : Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              data.sourceMessage,
              style: TextStyle(
                color: isReal ? Colors.greenAccent : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? Colors.greenAccent
              : const Color(0xFF151515),
          foregroundColor: isPrimary ? Colors.black : Colors.white,
          side: BorderSide(
            color: isPrimary ? Colors.greenAccent : Colors.white12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

String _formatGoalValue(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(1);
}
