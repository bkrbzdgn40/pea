import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/home_dashboard_data.dart';

class ExerciseDistributionCard extends StatelessWidget {
  const ExerciseDistributionCard({super.key, required this.items});

  final List<ExerciseDistributionItem> items;

  static const List<Color> _colors = [
    Colors.greenAccent,
    Color(0xFF64D2FF),
    Color(0xFFFFD166),
    Color(0xFFFF6B6B),
  ];

  @override
  Widget build(BuildContext context) {
    final chartItems = items.isEmpty
        ? HomeDashboardData.fallback().exerciseDistribution
        : items;

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
                        for (var i = 0; i < chartItems.length; i++)
                          PieChartSectionData(
                            value: chartItems[i].value,
                            color: _colorForIndex(i),
                            radius: 46,
                            title: '${chartItems[i].value.round()}%',
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
                    for (var i = 0; i < chartItems.length; i++) ...[
                      _LegendItem(
                        item: chartItems[i],
                        color: _colorForIndex(i),
                      ),
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

  Color _colorForIndex(int index) {
    return _colors[index % _colors.length];
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.item, required this.color});

  final ExerciseDistributionItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            item.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '${item.value.round()}%',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}
