import 'package:flutter/material.dart';

import '../../../../app/presentation/widgets/app_drawer.dart';
import 'camera_permission_screen.dart';
import 'exercise_selection_screen.dart';
import 'guide_screen.dart';
import 'session_history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              const _DashboardStats(),
              const SizedBox(height: 14),
              const _AiCoachPreviewCard(),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.fitness_center_rounded,
            color: Colors.greenAccent,
            size: 34,
          ),
          SizedBox(height: 16),
          Text(
            'Yapay Zeka Antrenör',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Canlı kamera analiziyle formunu takip et, tekrarlarını ölç ve antrenman geçmişini izle.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _DashboardStats extends StatelessWidget {
  const _DashboardStats();

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
          children: const [
            _DashboardStatCard(label: 'Toplam Analiz', value: '24'),
            _DashboardStatCard(label: 'Ortalama Skor', value: '82'),
            _DashboardStatCard(label: 'Bu Hafta', value: '6'),
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

class _AiCoachPreviewCard extends StatelessWidget {
  const _AiCoachPreviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.greenAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'AI Coach',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 8),
                    _SoonBadge(),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Form analizi, günlük öneriler ve antrenman ipuçları yakında burada olacak.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.greenAccent,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          'Yakında',
          style: TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
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
