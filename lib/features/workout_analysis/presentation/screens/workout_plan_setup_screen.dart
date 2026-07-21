import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_definition_metadata.dart';
import '../../application/workout_engine.dart';
import '../../domain/models/exercise_type.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/workout_plan_session_provider.dart';
import 'camera_permission_screen.dart';

class WorkoutPlanSetupScreen extends ConsumerStatefulWidget {
  const WorkoutPlanSetupScreen({super.key});

  @override
  ConsumerState<WorkoutPlanSetupScreen> createState() =>
      _WorkoutPlanSetupScreenState();
}

class _WorkoutPlanSetupScreenState
    extends ConsumerState<WorkoutPlanSetupScreen> {
  final Set<ExerciseType> _selected = <ExerciseType>{};
  int _rounds = 1;

  static const ExerciseCatalog _catalog = ExerciseCatalog();

  @override
  Widget build(BuildContext context) {
    final definitions = _catalog.definitions
        .where((definition) => definition.isAnalysisSupported)
        .toList(growable: false);

    return AppScaffoldShell(
      title: 'Planlı Antrenman',
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Hareketleri seç. Her dinamik hareket 10 tekrar, hold hareketi 30 saniye olarak başlar. Set tamamlanınca sonraki adıma sen geçersin.',
            style: TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 16),
          AppSurfaceCard(
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Round sayısı',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1')),
                    ButtonSegment(value: 2, label: Text('2')),
                    ButtonSegment(value: 3, label: Text('3')),
                  ],
                  selected: <int>{_rounds},
                  onSelectionChanged: (selection) {
                    setState(() => _rounds = selection.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: definitions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final definition = definitions[index];
                return _ExercisePlanTile(
                  exercise: definition.type,
                  trackingType: definition.trackingType,
                  selected: _selected.contains(definition.type),
                  onChanged: (selected) {
                    setState(() {
                      if (selected) {
                        _selected.add(definition.type);
                      } else {
                        _selected.remove(definition.type);
                      }
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _selected.isEmpty ? null : _startWorkout,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              _selected.isEmpty
                  ? 'En az bir hareket seç'
                  : '${_selected.length} hareketle başla',
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _startWorkout() {
    final blocks = <WorkoutExerciseBlock>[
      for (final definition in _catalog.definitions)
        if (_selected.contains(definition.type))
          WorkoutExerciseBlock(
            exercise: definition.type,
            target: definition.trackingType == ExerciseTrackingType.hold
                ? const WorkoutTarget.hold(Duration(seconds: 30))
                : const WorkoutTarget.repetitions(10),
          ),
    ];
    final plan = WorkoutPlan(exercises: blocks, rounds: _rounds);
    final snapshot = ref.read(workoutPlanSessionProvider.notifier).start(plan);
    final firstExercise = snapshot.currentExercise;
    if (firstExercise == null) {
      return;
    }
    ref.read(selectedExerciseProvider.notifier).state = firstExercise;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraPermissionScreen()),
    );
  }
}

class _ExercisePlanTile extends StatelessWidget {
  const _ExercisePlanTile({
    required this.exercise,
    required this.trackingType,
    required this.selected,
    required this.onChanged,
  });

  final ExerciseType exercise;
  final ExerciseTrackingType trackingType;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final targetLabel = trackingType == ExerciseTrackingType.hold
        ? '30 saniye hold'
        : '10 tekrar';
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      borderColor: selected
          ? Colors.greenAccent.withValues(alpha: 0.45)
          : AppColors.surfaceBorder,
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        activeColor: Colors.greenAccent,
        checkColor: Colors.black,
        title: Text(
          exercise.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '1 set • $targetLabel',
          style: const TextStyle(color: Colors.white60),
        ),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}
