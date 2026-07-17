import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/widgets/app_header_list_view.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_state_views.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/presentation/widgets/async_state_view.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../models/workout_goal.dart';
import '../providers/goals_provider.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsState = ref.watch(goalsProvider);

    return AppScaffoldShell(
      title: 'Hedefler',
      showDrawer: false,
      padding: EdgeInsets.zero,
      body: AsyncStateView<GoalsState>(
        value: goalsState,
        errorBuilder: (context, error, stackTrace) => const AppErrorView(
          message: 'Hedefler yüklenemedi. Lütfen daha sonra tekrar dene.',
        ),
        dataBuilder: (context, state) => _GoalsList(state: state),
      ),
    );
  }
}

class _GoalsList extends StatelessWidget {
  const _GoalsList({required this.state});

  final GoalsState state;

  @override
  Widget build(BuildContext context) {
    final visibleGoals = state.isFallback
        ? <WorkoutGoal>[]
        : state.goals.where((goal) => goal.id != 'three_day_streak').toList();

    return AppHeaderListView<WorkoutGoal>(
      header: const _GoalsHeaderCard(),
      items: visibleGoals,
      emptyState: _GoalsEmptyState(source: state.source),
      itemBuilder: (context, goal) => _GoalCard(goal: goal),
    );
  }
}

class _GoalsHeaderCard extends StatelessWidget {
  const _GoalsHeaderCard();

  @override
  Widget build(BuildContext context) {
    return const AppSurfaceCard(
      padding: AppSpacing.headerSurfacePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_rounded, color: Colors.greenAccent, size: 32),
          SizedBox(height: 14),
          Text(
            'Haftalık ilerlemeni burada takip edeceksin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Analizlerin tamamlandıkça haftalık hedeflerin burada netleşir.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _GoalsEmptyState extends StatelessWidget {
  const _GoalsEmptyState({required this.source});

  final GoalsDataSource source;

  @override
  Widget build(BuildContext context) {
    final message = switch (source) {
      GoalsDataSource.error =>
        'Hedefler şu an hazırlanamadı. Daha sonra tekrar bakabilirsin.',
      _ => 'İlk analizini tamamladığında hedef ilerlemen burada görünür.',
    };

    return AppEmptyView(message: message, icon: Icons.flag_outlined);
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final WorkoutGoal goal;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      borderColor: goal.isCompleted
          ? AppColors.accent
          : AppColors.surfaceBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (goal.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const Text(
                    'Tamamlandı',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            goal.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          _GoalProgressRow(goal: goal),
        ],
      ),
    );
  }
}

class _GoalProgressRow extends StatelessWidget {
  const _GoalProgressRow({required this.goal});

  final WorkoutGoal goal;

  @override
  Widget build(BuildContext context) {
    final progressPercent = (goal.progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_formatValue(goal.currentValue)} / ${_formatValue(goal.targetValue)} ${goal.unit}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '%$progressPercent',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: goal.progress,
          minHeight: 7,
          backgroundColor: Colors.white12,
          color: Colors.greenAccent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ],
    );
  }
}

String _formatValue(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(1);
}
