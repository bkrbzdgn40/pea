import 'dart:math' as math;

/// Configuration for normalized stability scoring.
///
/// Stability is intentionally based on observed signal dispersion rather than
/// an exercise-specific "good form" threshold. Form validity remains owned by
/// the hold posture policy. A score is only produced once a signal has enough
/// samples to measure variation honestly.
class StabilityEngineConfig {
  const StabilityEngineConfig({
    this.minimumSamplesPerSignal = 2,
    this.standardDeviationAtZeroScore = 12.0,
  }) : assert(minimumSamplesPerSignal >= 2),
       assert(standardDeviationAtZeroScore > 0.0);

  final int minimumSamplesPerSignal;
  final double standardDeviationAtZeroScore;
}

class StabilitySignalSummary {
  const StabilitySignalSummary({
    required this.sampleCount,
    required this.mean,
    required this.standardDeviation,
  });

  final int sampleCount;
  final double mean;
  final double standardDeviation;
}

/// Immutable stability summary for either one active window or the full
/// engine session.
///
/// [stabilityScore] uses the conventional direction where 100 means more
/// stable and 0 means highly variable. Missing evidence stays null instead of
/// being presented as a measured zero.
class StabilitySummary<K extends Object> {
  StabilitySummary({
    required this.sampleCount,
    required Map<K, StabilitySignalSummary> signalSummaries,
    required this.averageStandardDeviation,
    required this.stabilityScore,
  }) : signalSummaries = Map<K, StabilitySignalSummary>.unmodifiable(
         signalSummaries,
       );

  final int sampleCount;
  final Map<K, StabilitySignalSummary> signalSummaries;
  final double? averageStandardDeviation;
  final double? stabilityScore;

  bool get hasMeasuredStability => stabilityScore != null;
}

/// Optional metrics surface for engines that expose stability alongside their
/// primary analysis family.
abstract interface class StabilityMetricsSource<K extends Object> {
  StabilitySummary<K>? get currentStability;

  StabilitySummary<K>? get lastCompletedStability;

  StabilitySummary<K> get stabilitySessionSummary;
}

/// Generic multi-signal stability accumulator.
///
/// The engine is deliberately unaware of exercise anatomy. Callers provide a
/// typed signal key and numeric values. It measures per-signal population
/// standard deviation using Welford's online algorithm, then averages the
/// measured deviations into a normalized 0-100 score.
class StabilityEngine<K extends Object> {
  StabilityEngine({this.config = const StabilityEngineConfig()});

  final StabilityEngineConfig config;

  final Map<K, _RunningStatistics> _sessionStatistics =
      <K, _RunningStatistics>{};
  final Map<K, _RunningStatistics> _windowStatistics =
      <K, _RunningStatistics>{};

  int _sessionSampleCount = 0;
  int _windowSampleCount = 0;
  bool _isWindowActive = false;
  StabilitySummary<K>? _lastCompletedWindow;

  bool get isWindowActive => _isWindowActive;

  StabilitySummary<K>? get currentWindowSummary {
    if (!_isWindowActive) {
      return null;
    }
    return _buildSummary(_windowStatistics, _windowSampleCount);
  }

  StabilitySummary<K>? get lastCompletedWindow => _lastCompletedWindow;

  StabilitySummary<K> get sessionSummary =>
      _buildSummary(_sessionStatistics, _sessionSampleCount);

  void beginWindow() {
    _windowStatistics.clear();
    _windowSampleCount = 0;
    _isWindowActive = true;
  }

  /// Records one observation frame.
  ///
  /// Non-finite values are ignored. A frame with no finite values is not
  /// counted as a stability sample.
  void recordSample(Map<K, double> values) {
    if (!_isWindowActive) {
      return;
    }

    final finiteEntries = values.entries
        .where((entry) => entry.value.isFinite)
        .toList(growable: false);
    if (finiteEntries.isEmpty) {
      return;
    }

    _windowSampleCount += 1;
    _sessionSampleCount += 1;

    for (final entry in finiteEntries) {
      (_windowStatistics[entry.key] ??= _RunningStatistics()).add(entry.value);
      (_sessionStatistics[entry.key] ??= _RunningStatistics()).add(entry.value);
    }
  }

  StabilitySummary<K>? endWindow() {
    if (!_isWindowActive) {
      return null;
    }

    final completed = _buildSummary(_windowStatistics, _windowSampleCount);
    _lastCompletedWindow = completed;
    _windowStatistics.clear();
    _windowSampleCount = 0;
    _isWindowActive = false;
    return completed;
  }

  /// Clears only the active window while preserving session history.
  void abandonWindow() {
    _windowStatistics.clear();
    _windowSampleCount = 0;
    _isWindowActive = false;
  }

  void reset() {
    _sessionStatistics.clear();
    _windowStatistics.clear();
    _sessionSampleCount = 0;
    _windowSampleCount = 0;
    _isWindowActive = false;
    _lastCompletedWindow = null;
  }

  StabilitySummary<K> _buildSummary(
    Map<K, _RunningStatistics> statistics,
    int sampleCount,
  ) {
    final signalSummaries = <K, StabilitySignalSummary>{};
    final measuredDeviations = <double>[];

    for (final entry in statistics.entries) {
      final stats = entry.value;
      final deviation = stats.standardDeviation;
      signalSummaries[entry.key] = StabilitySignalSummary(
        sampleCount: stats.count,
        mean: stats.mean,
        standardDeviation: deviation,
      );
      if (stats.count >= config.minimumSamplesPerSignal) {
        measuredDeviations.add(deviation);
      }
    }

    final averageDeviation = measuredDeviations.isEmpty
        ? null
        : measuredDeviations.reduce((left, right) => left + right) /
              measuredDeviations.length;
    final stabilityScore = averageDeviation == null
        ? null
        : ((1.0 - (averageDeviation / config.standardDeviationAtZeroScore)) *
                  100.0)
              .clamp(0.0, 100.0)
              .toDouble();

    return StabilitySummary<K>(
      sampleCount: sampleCount,
      signalSummaries: signalSummaries,
      averageStandardDeviation: averageDeviation,
      stabilityScore: stabilityScore,
    );
  }
}

class _RunningStatistics {
  int count = 0;
  double mean = 0.0;
  double _sumSquaredDeviation = 0.0;

  void add(double value) {
    count += 1;
    final delta = value - mean;
    mean += delta / count;
    final deltaFromUpdatedMean = value - mean;
    _sumSquaredDeviation += delta * deltaFromUpdatedMean;
  }

  double get standardDeviation {
    if (count < 2) {
      return 0.0;
    }
    return math.sqrt(math.max(0.0, _sumSquaredDeviation / count));
  }
}
