import 'range_rep_validation_result.dart';
import 'workout_rep.dart';
import 'workout_session.dart';

/// Read-only report view derived from a stored session summary and rep details.
class SessionReport {
  const SessionReport({
    required this.isHoldSession,
    required this.hasRepDetails,
    required this.hasScoreData,
    required this.totalReps,
    required this.validReps,
    required this.lowConfidenceReps,
    required this.invalidReps,
    required this.unknownReps,
    required this.averageScore,
    required this.bestScore,
    required this.worstScore,
    required this.formWarningCount,
    required this.formViolationCount,
    required this.coverageDropCount,
    required this.sideSwitchCount,
    required this.totalHoldSeconds,
    required this.bestHoldSeconds,
    required this.formBreakCount,
    required this.topIssues,
    required this.bestReps,
    required this.weakestReps,
    required this.summaryMessage,
    required this.recommendations,
  });

  factory SessionReport.fromSession({
    required WorkoutSession session,
    List<WorkoutRep> reps = const <WorkoutRep>[],
  }) {
    final normalizedReps = List<WorkoutRep>.unmodifiable(
      reps.toList()
        ..sort((left, right) => left.repIndex.compareTo(right.repIndex)),
    );

    if (session.isHoldSession) {
      return _buildHoldReport(session);
    }

    if (normalizedReps.isEmpty) {
      return _buildSummaryOnlyRangeRepReport(session);
    }

    final acceptedReps = normalizedReps
        .where((rep) => !rep.isValidatedAsInvalid)
        .toList(growable: false);
    final totalReps = session.totalReps > 0
        ? session.totalReps
        : acceptedReps.length;
    final validReps = acceptedReps
        .where((rep) => rep.isValidatedAsValid)
        .length;
    final lowConfidenceReps = acceptedReps
        .where((rep) => rep.isValidatedAsLowConfidence)
        .length;
    final invalidReps = normalizedReps
        .where((rep) => rep.isValidatedAsInvalid)
        .length;
    final unknownReps = totalReps - validReps - lowConfidenceReps;
    final scoredReps = acceptedReps
        .where((rep) => rep.score != null)
        .toList(growable: false);
    final scores = scoredReps.map((rep) => rep.score!).toList(growable: false);
    final issueCounts = _issueCounts(normalizedReps);
    final topIssues = issueCounts.keys.take(3).toList(growable: false);
    final formViolationCount = normalizedReps
        .where((rep) => rep.hadFormViolation)
        .length;
    final coverageDropCount = normalizedReps
        .where((rep) => rep.hadCoverageDrop)
        .length;
    final sideSwitchCount = normalizedReps
        .where((rep) => rep.switchedSideDuringRep)
        .length;

    final averageScore = scores.isEmpty
        ? session.averageScore
        : _average(scores);
    final bestScore = scores.isEmpty ? session.bestScore : scores.reduce(_max);
    final worstScore = scores.isEmpty
        ? session.worstScore
        : scores.reduce(_min);
    final bestReps = _rankedReps(scoredReps, descending: true);
    final weakestReps = _rankedReps(scoredReps, descending: false);

    return SessionReport(
      isHoldSession: false,
      hasRepDetails: true,
      hasScoreData: scores.isNotEmpty || _sessionHasScoreData(session),
      totalReps: totalReps,
      validReps: validReps,
      lowConfidenceReps: lowConfidenceReps,
      invalidReps: invalidReps,
      unknownReps: unknownReps < 0 ? 0 : unknownReps,
      averageScore: averageScore,
      bestScore: bestScore,
      worstScore: worstScore,
      formWarningCount: session.formWarningCount,
      formViolationCount: formViolationCount,
      coverageDropCount: coverageDropCount,
      sideSwitchCount: sideSwitchCount,
      totalHoldSeconds: session.totalHoldSeconds,
      bestHoldSeconds: session.bestHoldSeconds,
      formBreakCount: session.formBreakCount,
      topIssues: topIssues,
      bestReps: bestReps,
      weakestReps: weakestReps,
      summaryMessage: _buildRangeRepSummary(
        totalReps: totalReps,
        validReps: validReps,
        lowConfidenceReps: lowConfidenceReps,
        invalidReps: invalidReps,
        unknownReps: unknownReps,
        averageScore: averageScore,
        topIssues: topIssues,
      ),
      recommendations: _buildRangeRepRecommendations(
        averageScore: averageScore,
        formWarningCount: session.formWarningCount,
        formViolationCount: formViolationCount,
        coverageDropCount: coverageDropCount,
        sideSwitchCount: sideSwitchCount,
        issueLabels: issueCounts.keys,
      ),
    );
  }

  final bool isHoldSession;
  final bool hasRepDetails;
  final bool hasScoreData;
  final int totalReps;
  final int validReps;
  final int lowConfidenceReps;
  final int invalidReps;
  final int unknownReps;
  final double averageScore;
  final double bestScore;
  final double worstScore;
  final int formWarningCount;
  final int formViolationCount;
  final int coverageDropCount;
  final int sideSwitchCount;
  final double totalHoldSeconds;
  final double bestHoldSeconds;
  final int formBreakCount;
  final List<String> topIssues;
  final List<WorkoutRep> bestReps;
  final List<WorkoutRep> weakestReps;
  final String summaryMessage;
  final List<String> recommendations;

  static SessionReport _buildSummaryOnlyRangeRepReport(WorkoutSession session) {
    final totalReps = session.totalReps;
    final unknownReps =
        totalReps - session.validReps - session.lowConfidenceReps;

    return SessionReport(
      isHoldSession: false,
      hasRepDetails: false,
      hasScoreData: _sessionHasScoreData(session),
      totalReps: totalReps,
      validReps: session.validReps,
      lowConfidenceReps: session.lowConfidenceReps,
      invalidReps: session.invalidReps,
      unknownReps: unknownReps < 0 ? 0 : unknownReps,
      averageScore: session.averageScore,
      bestScore: session.bestScore,
      worstScore: session.worstScore,
      formWarningCount: session.formWarningCount,
      formViolationCount: 0,
      coverageDropCount: 0,
      sideSwitchCount: 0,
      totalHoldSeconds: session.totalHoldSeconds,
      bestHoldSeconds: session.bestHoldSeconds,
      formBreakCount: session.formBreakCount,
      topIssues: const <String>[],
      bestReps: const <WorkoutRep>[],
      weakestReps: const <WorkoutRep>[],
      summaryMessage:
          'Bu oturumda tekrar detayları yok; yalnızca özet verileri gösteriliyor.',
      recommendations: _buildSummaryOnlyRecommendations(session),
    );
  }

  static SessionReport _buildHoldReport(WorkoutSession session) {
    return SessionReport(
      isHoldSession: true,
      hasRepDetails: false,
      hasScoreData: false,
      totalReps: session.totalReps,
      validReps: 0,
      lowConfidenceReps: 0,
      invalidReps: 0,
      unknownReps: 0,
      averageScore: 0,
      bestScore: 0,
      worstScore: 0,
      formWarningCount: 0,
      formViolationCount: 0,
      coverageDropCount: 0,
      sideSwitchCount: 0,
      totalHoldSeconds: session.totalHoldSeconds,
      bestHoldSeconds: session.bestHoldSeconds,
      formBreakCount: session.formBreakCount,
      topIssues: const <String>[],
      bestReps: const <WorkoutRep>[],
      weakestReps: const <WorkoutRep>[],
      summaryMessage: _buildHoldSummary(session),
      recommendations: _buildHoldRecommendations(session),
    );
  }

  static bool _sessionHasScoreData(WorkoutSession session) {
    return session.averageScore > 0 ||
        session.bestScore > 0 ||
        session.worstScore > 0;
  }

  static Map<String, int> _issueCounts(List<WorkoutRep> reps) {
    final counts = <String, int>{};
    final firstSeenOrder = <String, int>{};
    var nextOrder = 0;

    for (final rep in reps) {
      for (final reason in rep.validationReasons) {
        final label = _issueLabel(reason);
        firstSeenOrder[label] ??= nextOrder++;
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }

    final sortedEntries = counts.entries.toList(growable: false)
      ..sort((left, right) {
        final countComparison = right.value.compareTo(left.value);
        if (countComparison != 0) {
          return countComparison;
        }

        return (firstSeenOrder[left.key] ?? 0).compareTo(
          firstSeenOrder[right.key] ?? 0,
        );
      });

    return Map<String, int>.fromEntries(sortedEntries);
  }

  static List<WorkoutRep> _rankedReps(
    List<WorkoutRep> reps, {
    required bool descending,
  }) {
    final ranked = reps.toList(growable: false)
      ..sort((left, right) {
        final scoreComparison = left.score!.compareTo(right.score!);
        final orderedScore = descending ? -scoreComparison : scoreComparison;
        if (orderedScore != 0) {
          return orderedScore;
        }

        return left.repIndex.compareTo(right.repIndex);
      });

    return List<WorkoutRep>.unmodifiable(ranked.take(3));
  }

  static String _buildRangeRepSummary({
    required int totalReps,
    required int validReps,
    required int lowConfidenceReps,
    required int invalidReps,
    required int unknownReps,
    required double averageScore,
    required List<String> topIssues,
  }) {
    if (totalReps <= 0) {
      return 'Bu oturumda tamamlanmış tekrar kaydı yok.';
    }

    final parts = <String>[
      '$totalReps tekrar sayıldı: $validReps tanesi geçerli',
    ];

    if (lowConfidenceReps > 0) {
      parts.add('$lowConfidenceReps tanesi düşük güvenli');
    }
    if (unknownReps > 0) {
      parts.add('$unknownReps tanesi belirsiz');
    }
    if (invalidReps > 0) {
      parts.add('$invalidReps geçersiz deneme sayaca eklenmedi');
    }

    final summary = '${parts.join(', ')}.';
    if (topIssues.isNotEmpty) {
      return '$summary En sık sorun: ${topIssues.first}.';
    }
    if (averageScore > 0) {
      return '$summary Ortalama skor ${averageScore.toStringAsFixed(0)}.';
    }

    return summary;
  }

  static List<String> _buildRangeRepRecommendations({
    required double averageScore,
    required int formWarningCount,
    required int formViolationCount,
    required int coverageDropCount,
    required int sideSwitchCount,
    required Iterable<String> issueLabels,
  }) {
    final recommendations = <String>[];
    final issueSet = issueLabels.toSet();

    if (issueSet.contains(
      _issueLabel(RangeRepValidationReason.insufficientRom.debugLabel),
    )) {
      recommendations.add(
        'Daha derin tekrarlar için hareket açıklığını kontrollü biçimde artır.',
      );
    }
    if (issueSet.contains(
      _issueLabel(RangeRepValidationReason.incompletePhase.debugLabel),
    )) {
      recommendations.add(
        'Tekrarları tam iniş ve tam çıkış döngüsüyle tamamlamaya odaklan.',
      );
    }
    if (averageScore > 0 && averageScore < 75) {
      recommendations.add(
        'Skor dalgalanmasını azaltmak için tempoyu biraz yavaşlat ve ritmi sabitle.',
      );
    }
    if (issueSet.contains(
      _issueLabel(RangeRepValidationReason.excessiveRepSpeed.debugLabel),
    )) {
      recommendations.add(
        'Toplam tekrar süresini biraz uzat ve yükselme-dönüş ritmini kontrollü tut.',
      );
    }
    if (formWarningCount > 0 ||
        formViolationCount > 0 ||
        issueSet.contains(
          _issueLabel(RangeRepValidationReason.persistentFormBreak.debugLabel),
        )) {
      recommendations.add(
        'Form bozulmasını azaltmak için gövde hizasını ve diz kontrolünü daha sıkı koru.',
      );
    }
    if (coverageDropCount > 0 ||
        issueSet.contains(
          _issueLabel(RangeRepValidationReason.coverageLoss.debugLabel),
        )) {
      recommendations.add(
        'Kamera açısını sabitle; bazı tekrarlarda görünürlük kaybı oluşmuş.',
      );
    }
    if (sideSwitchCount > 0 ||
        issueSet.contains(
          _issueLabel(RangeRepValidationReason.sideSwitchDuringRep.debugLabel),
        )) {
      recommendations.add(
        'Set boyunca aynı tarafı daha net gösterecek şekilde pozisyonunu koru.',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'Genel kalite dengeli görünüyor; aynı kontrolü koruyarak tekrar sayısını kademeli artır.',
      );
    }

    return List<String>.unmodifiable(recommendations.take(4));
  }

  static List<String> _buildSummaryOnlyRecommendations(WorkoutSession session) {
    final recommendations = <String>[];

    if (session.formWarningCount > 0) {
      recommendations.add(
        'Form uyarıları görüldüğü için sonraki sette hareket çizgisini daha kontrollü koru.',
      );
    }
    if (session.averageScore > 0 && session.averageScore < 75) {
      recommendations.add(
        'Düşük ortalama skorda önce tempo ve tam tekrar kalitesini toparlamak faydalı olur.',
      );
    }
    if (recommendations.isEmpty) {
      recommendations.add(
        'Bu rapor özet veriye dayanıyor; benzer bir sonraki sette tekrar detaylarını da incelemek faydalı olur.',
      );
    }

    return List<String>.unmodifiable(recommendations.take(3));
  }

  static String _buildHoldSummary(WorkoutSession session) {
    if (session.totalHoldSeconds <= 0) {
      return 'Bu hold oturumunda anlamlı tutuş süresi kaydedilmedi.';
    }

    return 'Toplam ${session.totalHoldSeconds.toStringAsFixed(0)} sn hold '
        'kaydedildi. En iyi tek deneme '
        '${session.bestHoldSeconds.toStringAsFixed(0)} sn.';
  }

  static List<String> _buildHoldRecommendations(WorkoutSession session) {
    final recommendations = <String>[];

    if (session.formBreakCount > 0) {
      recommendations.add(
        'Hold boyunca vücut çizgisini daha sabit tut; form kesintileri görülmüş.',
      );
    }
    if (session.bestHoldSeconds > 0 && session.bestHoldSeconds < 20) {
      recommendations.add(
        'Kısa ama temiz tekrarlarla en iyi hold süresini kademeli artır.',
      );
    }
    if (session.totalHoldSeconds >= 20 && session.formBreakCount == 0) {
      recommendations.add(
        'Süre dengeli görünüyor; aynı hizayı koruyarak toplam tutuş süresini artırabilirsin.',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'Önce pozisyonu kilitle, sonra süreyi azar azar uzat.',
      );
    }

    return List<String>.unmodifiable(recommendations.take(3));
  }

  static String _issueLabel(String value) {
    switch (value) {
      case 'insufficient rom':
        return 'yetersiz hareket açıklığı';
      case 'excessive descent speed':
        return 'iniş çok hızlı';
      case 'excessive ascent speed':
        return 'çıkış çok hızlı';
      case 'excessive rep speed':
        return 'toplam tekrar süresi çok kısa';
      case 'persistent form break':
        return 'kalıcı form bozulması';
      case 'coverage loss':
        return 'görünürlük kaybı';
      case 'side switch during rep':
        return 'tekrar içinde taraf değişimi';
      case 'incomplete phase':
        return 'eksik faz tamamlanması';
      default:
        return value;
    }
  }
}

double _average(List<double> values) {
  final total = values.fold<double>(0, (sum, value) => sum + value);
  return total / values.length;
}

double _max(double left, double right) {
  return left > right ? left : right;
}

double _min(double left, double right) {
  return left < right ? left : right;
}
