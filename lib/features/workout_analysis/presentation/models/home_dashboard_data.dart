enum HomeDashboardSource { loading, real, noUser, empty, error }

/// Aggregated values used by Home without exposing session query details.
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

  factory HomeDashboardData.empty({
    HomeDashboardSource source = HomeDashboardSource.empty,
  }) {
    return HomeDashboardData(
      totalAnalyses: 0,
      averageScore: 0,
      thisWeekCount: 0,
      bestScore: 0,
      scoreTrend: const <ScoreTrendPoint>[],
      exerciseDistribution: const <ExerciseDistributionItem>[],
      source: source,
    );
  }

  factory HomeDashboardData.fallback({
    HomeDashboardSource source = HomeDashboardSource.loading,
  }) {
    return HomeDashboardData.empty(source: source);
  }

  bool get hasRealData => source == HomeDashboardSource.real;

  String get sourceMessage {
    return switch (source) {
      HomeDashboardSource.loading => 'Oturum verisi yükleniyor',
      HomeDashboardSource.real => 'Gerçek oturum verisi',
      HomeDashboardSource.noUser => 'Kullanıcı oturumu bulunamadı',
      HomeDashboardSource.empty => 'Henüz oturum yok',
      HomeDashboardSource.error => 'Oturum verisi alınamadı',
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
