import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/presentation/widgets/app_surface_card.dart';
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
    return AppSurfaceCard(
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
            'Oturumlarının hareketlere göre dağılımı',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const _DistributionPlaceholder()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                final chart = SizedBox(
                  height: 150,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 36,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                      sections: [
                        for (var i = 0; i < items.length; i++)
                          PieChartSectionData(
                            value: items[i].value,
                            color: _colorForIndex(i),
                            radius: 46,
                            title: '${items[i].value.round()}%',
                            titleStyle: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
                final legend = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      _LegendItem(item: items[i], color: _colorForIndex(i)),
                      if (i != items.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );

                if (isNarrow) {
                  return Column(
                    children: [chart, const SizedBox(height: 14), legend],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: chart),
                    const SizedBox(width: 14),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Color _colorForIndex(int index) {
    return _colors[index % _colors.length];
  }
}

class _DistributionPlaceholder extends StatelessWidget {
  const _DistributionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: const Row(
        children: [
          Icon(Icons.pie_chart_outline_rounded, color: Colors.greenAccent),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Kaydedilen analizler arttıkça dağılım burada oluşur.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ),
        ],
      ),
    );
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
