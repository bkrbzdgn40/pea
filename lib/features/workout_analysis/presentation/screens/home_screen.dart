import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/widgets/app_drawer.dart';
import '../../../achievements/presentation/models/achievement.dart';
import '../../../achievements/presentation/providers/achievements_provider.dart';
import '../../../achievements/presentation/screens/achievements_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../goals/presentation/models/workout_goal.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../models/home_dashboard_data.dart';
import '../providers/home_dashboard_provider.dart';
import '../providers/selected_exercise_provider.dart';
import 'camera_permission_screen.dart';
import 'exercise_selection_screen.dart';
import 'guide_screen.dart';
import 'score_trend_detail_screen.dart';
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
    // Fallback data powers placeholders, but metric cards only show real sessions.
    final hasDashboardData = dashboardData.source == HomeDashboardSource.real;
    final goalsState = ref.watch(goalsProvider).valueOrNull;
    final goalPreview = _trustedGoalPreview(goalsState);
    final achievementsState = ref.watch(achievementsProvider).valueOrNull;
    final achievementPreview = _trustedAchievementPreview(achievementsState);
    final selectedExercise = ref.watch(selectedExerciseProvider);

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
              const _HomeGreetingCard(),
              const SizedBox(height: 14),
              _HomeActionGrid(
                onStartAnalysis: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => selectedExercise != null
                          ? const CameraPermissionScreen()
                          : ExerciseSelectionScreen(),
                    ),
                  );
                },
                onSelectExercise: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExerciseSelectionScreen(),
                    ),
                  );
                },
                onOpenGuide: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GuideScreen()),
                  );
                },
                onOpenHistory: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SessionHistoryScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              if (hasDashboardData)
                _DashboardStats(data: dashboardData)
              else
                const _HomeProgressEmptyCard(),
              const SizedBox(height: 14),
              if (goalPreview == null)
                HomeFeaturePreviewCard(
                  title: 'Haftalık Hedef',
                  subtitle:
                      'İlk analizinden sonra hedeflerin burada şekillenir.',
                  icon: Icons.flag_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GoalsScreen()),
                    );
                  },
                )
              else
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
              if (achievementPreview == null)
                HomeFeaturePreviewCard(
                  title: 'Başarılar',
                  subtitle: 'Rozetlerin analizlerin tamamlandıkça açılır.',
                  icon: Icons.emoji_events_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AchievementsScreen(),
                      ),
                    );
                  },
                )
              else
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
              if (hasDashboardData)
                ScoreTrendCard(
                  points: dashboardData.scoreTrend,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScoreTrendDetailScreen(),
                      ),
                    );
                  },
                )
              else
                _HomeInsightPlaceholderCard(
                  title: 'Skor Trendi',
                  subtitle:
                      'Birkaç analiz tamamlandığında skor değişimin burada görünür.',
                  icon: Icons.show_chart_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScoreTrendDetailScreen(),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 14),
              if (hasDashboardData)
                ExerciseDistributionCard(
                  items: dashboardData.exerciseDistribution,
                )
              else
                const _HomeInsightPlaceholderCard(
                  title: 'Egzersiz Dağılımı',
                  subtitle:
                      'Kaydedilen oturumların hareket dağılımı burada toplanır.',
                  icon: Icons.pie_chart_rounded,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeGreetingCard extends StatelessWidget {
  const _HomeGreetingCard();

  @override
  Widget build(BuildContext context) {
    final greeting = _HomeGreetingData.current();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: greeting.accentColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: greeting.accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: greeting.accentColor.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(greeting.icon, color: greeting.accentColor, size: 30),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Bugünkü formunu takip etmeye hazır mısın?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.3,
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

class _HomeGreetingData {
  const _HomeGreetingData({
    required this.title,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final IconData icon;
  final Color accentColor;

  static _HomeGreetingData current() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return const _HomeGreetingData(
        title: 'Günaydın',
        icon: Icons.wb_sunny_rounded,
        accentColor: Color(0xFFFFD54F),
      );
    }

    if (hour >= 12 && hour < 17) {
      return const _HomeGreetingData(
        title: 'İyi öğlenler',
        icon: Icons.sunny,
        accentColor: Color(0xFFFFA726),
      );
    }

    if (hour >= 17 && hour < 22) {
      return const _HomeGreetingData(
        title: 'İyi akşamlar',
        icon: Icons.wb_twilight_rounded,
        accentColor: Color(0xFFAB47BC),
      );
    }

    return const _HomeGreetingData(
      title: 'İyi geceler',
      icon: Icons.nightlight_round,
      accentColor: Color(0xFF5C6BC0),
    );
  }
}

class _HomeActionGrid extends StatelessWidget {
  const _HomeActionGrid({
    required this.onStartAnalysis,
    required this.onSelectExercise,
    required this.onOpenGuide,
    required this.onOpenHistory,
  });

  final VoidCallback onStartAnalysis;
  final VoidCallback onSelectExercise;
  final VoidCallback onOpenGuide;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final cardWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _HomeActionCard(
              icon: Icons.play_arrow_rounded,
              title: 'Analize Başla',
              subtitle: 'Canlı kamera analizi',
              isPrimary: true,
              onTap: onStartAnalysis,
            ),
            _HomeActionCard(
              icon: Icons.directions_run_rounded,
              title: 'Hareket Seç',
              subtitle: 'Desteklenen hareketler',
              onTap: onSelectExercise,
            ),
            _HomeActionCard(
              icon: Icons.menu_book_rounded,
              title: 'Hareket Rehberi',
              subtitle: 'Teknik ipuçları ve hatalar',
              onTap: onOpenGuide,
            ),
            _HomeActionCard(
              icon: Icons.history_rounded,
              title: 'Geçmiş Oturumlar',
              subtitle: 'Kaydedilmiş analizler',
              onTap: onOpenHistory,
            ),
          ].map((card) => SizedBox(width: cardWidth, child: card)).toList(),
        );
      },
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final accentColor = isPrimary ? Colors.greenAccent : Colors.white70;
    final backgroundColor = isPrimary
        ? Colors.greenAccent.withValues(alpha: 0.13)
        : const Color(0xFF151515);
    final borderColor = isPrimary
        ? Colors.greenAccent.withValues(alpha: 0.5)
        : Colors.white12;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 104),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(height: 16),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        height: 1.18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeProgressEmptyCard extends StatelessWidget {
  const _HomeProgressEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.insights_rounded, color: Colors.greenAccent, size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İlerlemen burada birikecek',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'İlk analizini tamamladığında skorların, tekrarların ve haftalık özetin burada görünür.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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

class _HomeInsightPlaceholderCard extends StatelessWidget {
  const _HomeInsightPlaceholderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.greenAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded, color: Colors.greenAccent),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: content,
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

WorkoutGoal? _trustedGoalPreview(GoalsState? state) {
  if (state == null || state.isFallback) {
    return null;
  }

  for (final goal in state.goals) {
    if (goal.id != 'three_day_streak') {
      return goal;
    }
  }

  return null;
}

Achievement? _trustedAchievementPreview(AchievementsState? state) {
  if (state == null || state.isFallback) {
    return null;
  }

  for (final achievement in state.achievements) {
    if (achievement.id != 'seven_day_streak') {
      return achievement;
    }
  }

  return null;
}

String _formatGoalValue(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(1);
}
