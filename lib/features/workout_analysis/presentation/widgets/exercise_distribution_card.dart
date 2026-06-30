import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ExerciseDistributionCard extends StatelessWidget {
  const ExerciseDistributionCard({super.key});

  static const List<_ExerciseSlice> _slices = [
    _ExerciseSlice('Squat', 40, Colors.greenAccent),
    _ExerciseSlice('Plank', 25, Color(0xFF64D2FF)),
    _ExerciseSlice('Lunge', 20, Color(0xFFFFD166)),
    _ExerciseSlice('Burpee', 15, Color(0xFFFF6B6B)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Egzersiz Dağılımı',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Örnek oturum dağılım görünümü',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 150,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 36,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                      sections: [
                        for (final slice in _slices)
                          PieChartSectionData(
                            value: slice.value.toDouble(),
                            color: slice.color,
                            radius: 46,
                            title: '${slice.value}%',
                            titleStyle: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final slice in _slices) ...[
                      _LegendItem(slice: slice),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.slice});

  final _ExerciseSlice slice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            slice.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '${slice.value}%',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}

class _ExerciseSlice {
  const _ExerciseSlice(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}
