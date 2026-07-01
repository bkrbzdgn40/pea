import 'package:flutter/material.dart';

import '../data/demo_workout_goals.dart';
import '../models/workout_goal.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Hedefler'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: demoWorkoutGoals.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const _GoalsHeaderCard();
            }

            return _GoalCard(goal: demoWorkoutGoals[index - 1]);
          },
        ),
      ),
    );
  }
}

class _GoalsHeaderCard extends StatelessWidget {
  const _GoalsHeaderCard();

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
            'Bu hedefler demo veridir. Sonraki adımlarda gerçek oturum verilerine bağlanabilir.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final WorkoutGoal goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: goal.isCompleted ? Colors.greenAccent : Colors.white12,
        ),
      ),
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
                    borderRadius: BorderRadius.circular(999),
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
          borderRadius: BorderRadius.circular(999),
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
