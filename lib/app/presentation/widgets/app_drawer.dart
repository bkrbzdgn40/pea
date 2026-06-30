import 'package:flutter/material.dart';

import '../../../features/workout_analysis/presentation/screens/exercise_selection_screen.dart';
import '../../../features/workout_analysis/presentation/screens/guide_screen.dart';
import '../../../features/workout_analysis/presentation/screens/home_screen.dart';
import '../../../features/workout_analysis/presentation/screens/session_history_screen.dart';
import '../../../features/workout_analysis/presentation/screens/settings_screen.dart';

enum AppDrawerPage { home, exerciseSelection, sessionHistory, guide, settings }

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.currentPage});

  final AppDrawerPage? currentPage;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.fitness_center_rounded,
                      color: Colors.greenAccent,
                      size: 30,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Pose Analysis',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Antrenman menüsü',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _DrawerItem(
                        icon: Icons.home_rounded,
                        label: 'Ana Sayfa',
                        isSelected: currentPage == AppDrawerPage.home,
                        onTap: () => _open(
                          context,
                          (_) => HomeScreen(),
                          isCurrent: currentPage == AppDrawerPage.home,
                        ),
                      ),
                      _DrawerItem(
                        icon: Icons.directions_run_rounded,
                        label: 'Hareket Seç',
                        isSelected:
                            currentPage == AppDrawerPage.exerciseSelection,
                        onTap: () =>
                            _open(context, (_) => ExerciseSelectionScreen()),
                      ),
                      _DrawerItem(
                        icon: Icons.history_rounded,
                        label: 'Geçmiş Oturumlar',
                        isSelected: currentPage == AppDrawerPage.sessionHistory,
                        onTap: () =>
                            _open(context, (_) => SessionHistoryScreen()),
                      ),
                      _DrawerItem(
                        icon: Icons.menu_book_rounded,
                        label: 'Hareket Rehberi',
                        isSelected: currentPage == AppDrawerPage.guide,
                        onTap: () => _open(context, (_) => GuideScreen()),
                      ),
                      _DrawerItem(
                        icon: Icons.settings_rounded,
                        label: 'Ayarlar',
                        isSelected: currentPage == AppDrawerPage.settings,
                        onTap: () => _open(context, (_) => SettingsScreen()),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(
    BuildContext context,
    WidgetBuilder builder, {
    bool isCurrent = false,
  }) {
    final navigator = Navigator.of(context);
    navigator.pop();
    if (isCurrent) return;

    navigator.push(MaterialPageRoute(builder: builder));
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: isSelected,
      selectedTileColor: Colors.greenAccent.withValues(alpha: 0.12),
      leading: Icon(
        icon,
        color: isSelected ? Colors.greenAccent : Colors.white70,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.greenAccent : Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconColor: Colors.greenAccent,
      textColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
