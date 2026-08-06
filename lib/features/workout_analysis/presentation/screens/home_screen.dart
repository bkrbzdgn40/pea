import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/workout_plan_session_provider.dart';
import '../widgets/home_task_surface.dart';
import 'assessment_selection_screen.dart';
import 'camera_permission_screen.dart';
import 'exercise_selection_screen.dart';
import 'how_to_use_screen.dart';
import 'workout_plan_setup_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final selectedExercise = ref.watch(selectedExerciseProvider);

    void openExerciseSelection() {
      ref.read(workoutPlanSessionProvider.notifier).reset();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExerciseSelectionScreen()),
      );
    }

    void startAnalysis() {
      ref.read(workoutPlanSessionProvider.notifier).reset();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => selectedExercise != null
              ? const CameraPermissionScreen()
              : const ExerciseSelectionScreen(),
        ),
      );
    }

    return AppScaffoldShell(
      title: localizations.workoutAnalysis,
      currentPage: AppDestination.home,
      actions: [
        HomeHowToUseAction(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HowToUseScreen()),
            );
          },
        ),
      ],
      padding: EdgeInsets.zero,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppLayout.of(context, constraints: constraints);
          final useWideComposition =
              layout.viewportSize.width >= 760 &&
              (layout.isLandscape || layout.isExpanded);

          return SingleChildScrollView(
            padding: layout.pagePadding,
            child: Column(
              key: ValueKey(
                useWideComposition
                    ? 'home-wide-layout'
                    : 'home-portrait-layout',
              ),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HomeGreetingHeader(),
                SizedBox(height: layout.sectionGap),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: useWideComposition ? 920 : double.infinity,
                    ),
                    child: HomeTaskPanel(
                      layout: layout,
                      selectedExercise: selectedExercise,
                      onStartAnalysis: startAnalysis,
                      onSelectExercise: openExerciseSelection,
                      onOpenWorkoutPlan: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WorkoutPlanSetupScreen(),
                          ),
                        );
                      },
                      onOpenAssessment: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AssessmentSelectionScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
