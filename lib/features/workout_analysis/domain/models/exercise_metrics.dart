// (Kullanılmıyor) Tekrar ve analiz veri modellerini tutar.

/// Her bir tekrarın (rep) detaylı analizi
// (Kullanılmıyor) Tekrar sonucunu taşır.
class RepResult {
  final int index;
  final double rom; // Range of Motion (Max eğilme derecesi)
  final Duration descentTime;
  final Duration ascentTime;
  final double score; // 0-100 arası kalite puanı
  final bool isSuccessful;

  RepResult({
    required this.index,
    required this.rom,
    required this.descentTime,
    required this.ascentTime,
    required this.score,
    required this.isSuccessful,
  });
}

/// Uygulamanın o anki analiz durumu
// (Kullanılmıyor) Anlık analiz özetini taşır.
class AnalysisMetrics {
  final double stabilityScore; // Vücudun ne kadar az titrediği
  final double currentROM;
  final String coachMessage;
  final List<RepResult> history;
  final double sessionAverageScore;

  AnalysisMetrics({
    this.stabilityScore = 0.0,
    this.currentROM = 0.0,
    this.coachMessage = "Hazır mısın?",
    this.history = const [],
    this.sessionAverageScore = 0.0,
  });
}
