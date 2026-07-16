import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/workout_presentation_formatter.dart';
import '../providers/completed_session_provider.dart';
import 'home_screen.dart';

class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(completedSessionProvider);
    final summaryValues = session == null
        ? const <MapEntry<String, String>>[]
        : _summaryValues(session);

    return AppScaffoldShell(
      title: 'Antrenman Özeti',
      showDrawer: false,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSurfaceCard(
            padding: const EdgeInsets.all(22),
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session == null
                      ? 'Oturum verisi bulunamadı'
                      : '${WorkoutPresentationFormatter.exerciseTitle(session.exerciseType)} özeti',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  session == null
                      ? 'Canlı analiz tamamlandığında oturum özeti burada görünür.'
                      : 'Canlı analizden oluşturulan gerçek oturum değerleri.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: session == null
                ? const _MissingSessionView()
                : ListView.separated(
                    itemCount: summaryValues.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = summaryValues[index];
                      return _SummaryValueCard(
                        label: entry.key,
                        value: entry.value,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.home_outlined),
            label: const Text('Ana Sayfa'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingSessionView extends StatelessWidget {
  const _MissingSessionView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Oturum verisi bulunamadı.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SummaryValueCard extends StatelessWidget {
  const _SummaryValueCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      radius: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

List<MapEntry<String, String>> _summaryValues(WorkoutSession session) {
  if (session.isHoldSession) {
    return <MapEntry<String, String>>[
      MapEntry(
        'Egzersiz tipi',
        WorkoutPresentationFormatter.exerciseTitle(session.exerciseType),
      ),
      MapEntry(
        'Toplam hold',
        WorkoutPresentationFormatter.holdDuration(session.totalHoldSeconds),
      ),
      MapEntry(
        'En iyi hold',
        WorkoutPresentationFormatter.holdDuration(session.bestHoldSeconds),
      ),
      MapEntry('Form kesintisi', session.formBreakCount.toString()),
      MapEntry('Sure', WorkoutPresentationFormatter.duration(session.duration)),
    ];
  }

  return <MapEntry<String, String>>[
    MapEntry(
      'Egzersiz tipi',
      WorkoutPresentationFormatter.exerciseTitle(session.exerciseType),
    ),
    MapEntry('Toplam tekrar', session.totalReps.toString()),
    MapEntry(
      'Ortalama skor',
      WorkoutPresentationFormatter.roundedScore(session.averageScore),
    ),
    MapEntry(
      'En iyi skor',
      WorkoutPresentationFormatter.roundedScore(session.bestScore),
    ),
    MapEntry('Form uyarısı', session.formWarningCount.toString()),
    MapEntry('Süre', WorkoutPresentationFormatter.duration(session.duration)),
  ];
}
