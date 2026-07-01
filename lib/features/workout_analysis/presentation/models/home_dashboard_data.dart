enum HomeDashboardSource {
  real,
  demoNoUser,
  demoEmpty,
  demoError,
}

class HomeDashboardData {
  const HomeDashboardData({
    required this.totalAnalyses,
    required this.averageScore,
    required this.thisWeekCount,
    required this.bestScore,
    required this.scoreTrend,
    required this.exerciseDistribution,
    required this.source,
  });

  final int totalAnalyses;
  final int averageScore;
  final int thisWeekCount;
  final int bestScore;
  final List<ScoreTrendPoint> scoreTrend;
  final List<ExerciseDistributionItem> exerciseDistribution;
  final HomeDashboardSource source;

  factory HomeDashboardData.fallback({
    HomeDashboardSource source = HomeDashboardSource.demoEmpty,
  }) {
    return HomeDashboardData(
      totalAnalyses: 24,
      averageScore: 82,
      thisWeekCount: 6,
      bestScore: 90,
      scoreTrend: [
        ScoreTrendPoint(label: 'Pzt', score: 72),
        ScoreTrendPoint(label: 'Sal', score: 75),
        ScoreTrendPoint(label: 'Çar', score: 78),
        ScoreTrendPoint(label: 'Per', score: 74),
        ScoreTrendPoint(label: 'Cum', score: 82),
        ScoreTrendPoint(label: 'Cmt', score: 80),
        ScoreTrendPoint(label: 'Paz', score: 84),
      ],
      exerciseDistribution: [
        ExerciseDistributionItem(label: 'Squat', value: 40),
        ExerciseDistributionItem(label: 'Plank', value: 25),
        ExerciseDistributionItem(label: 'Lunge', value: 20),
        ExerciseDistributionItem(label: 'Burpee', value: 15),
      ],
      source: source,
    );
  }

  String get sourceMessage {
    return switch (source) {
      HomeDashboardSource.real => 'Gerçek oturum verisi',
      HomeDashboardSource.demoNoUser =>
        'Kullanıcı verisi yok, örnek gösterim',
      HomeDashboardSource.demoEmpty => 'Henüz oturum yok, örnek gösterim',
      HomeDashboardSource.demoError => 'Veri alınamadı, örnek gösterim',
    };
  }
}

class ScoreTrendPoint {
  const ScoreTrendPoint({required this.label, required this.score});

  final String label;
  final double score;
}

class ExerciseDistributionItem {
  const ExerciseDistributionItem({required this.label, required this.value});

  final String label;
  final double value;
}
