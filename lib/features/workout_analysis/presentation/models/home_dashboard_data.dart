enum HomeDashboardSource { loading, real, empty, error }

/// Aggregated values used by Home without exposing session query details.
class HomeDashboardData {
  const HomeDashboardData({
    required this.totalAnalyses,
    required this.averageScore,
    required this.thisWeek