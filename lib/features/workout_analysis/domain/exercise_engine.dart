import 'models/exercise_config.dart';

enum MovementPhase { neutral, descending, peak, ascending }

class RepResult {
  final int index;
  final double rom;
  final Duration descentTime;
  final Duration ascentTime;
  final double score;

  RepResult({
    required this.index,
    required this.rom,
    required this.descentTime,
    required this.ascentTime,
    required this.score,
  });
}

class RepScoreBreakdown {
  const RepScoreBreakdown({
    required this.minAngle,
    required this.romScore,
    required this.descentSeconds,
    required this.descentScore,
    required this.ascentSeconds,
    required this.ascentScoreCandidate,
    required this.worstBackAngle,
    required this.hadFormViolation,
    required this.finalScore,
  });

  final double minAngle;
  final double romScore;
  final double descentSeconds;
  final double descentScore;
  final double ascentSeconds;
  final double ascentScoreCandidate;
  final double worstBackAngle;
  final bool hadFormViolation;
  final double finalScore;
}

class ExerciseEngine {
  final ExerciseConfig config;

  MovementPhase state = MovementPhase.neutral;
  int repCount = 0;
  bool isFormBad = false;

  // Kept for WorkoutController compatibility; this is the last rep's min angle.
  double maxROM = 180.0;
  double lastRepScore = 0.0;
  RepScoreBreakdown? lastRepScoreBreakdown;
  String feedback = "Hazır!";

  DateTime? _descentStartTime;
  DateTime? _peakStartTime;
  DateTime? _ascentStartTime;

  Duration lastDescentTime = Duration.zero;
  Duration lastAscentTime = Duration.zero;

  double _currentRepMinAngle = 180.0;
  double _currentRepWorstBackAngle = 180.0;
  bool _currentRepHadFormViolation = false;

  ExerciseEngine({required this.config});

  // Formu ve tekrar fazını günceller.
  void update(double currentAngle, double backAngle) {
    _checkForm(backAngle);
    _processState(currentAngle, backAngle);
  }

  // Açıya göre faz geçişlerini yönetir.
  void _processState(double angle, double backAngle) {
    switch (state) {
      case MovementPhase.neutral:
        if (angle < config.thresholdActive) {
          state = MovementPhase.descending;
          _descentStartTime = DateTime.now();
          _startRepMetrics(angle, backAngle);
          feedback = "Aşağı in...";
        }
        break;

      case MovementPhase.descending:
        _trackRepForm(backAngle);
        if (angle < _currentRepMinAngle) _currentRepMinAngle = angle;

        if (angle < config.thresholdPeak) {
          state = MovementPhase.peak;
          _peakStartTime = DateTime.now();
          if (_descentStartTime != null) {
            lastDescentTime = _peakStartTime!.difference(_descentStartTime!);
          }
          feedback = "Harika, şimdi yukarı!";
        } else if (angle > config.thresholdNeutral) {
          state = MovementPhase.neutral;
          _resetCurrentRepMetrics();
          feedback = "Hareketi tamamlamadın.";
        }
        break;

      case MovementPhase.peak:
        _trackRepForm(backAngle);
        if (angle < _currentRepMinAngle) _currentRepMinAngle = angle;

        if (angle > config.thresholdPeak + 10) {
          state = MovementPhase.ascending;
          _ascentStartTime = DateTime.now();
          feedback = "Yukarı...";
        }
        break;

      case MovementPhase.ascending:
        _trackRepForm(backAngle);
        if (angle > config.thresholdNeutral) {
          if (_ascentStartTime != null) {
            lastAscentTime = DateTime.now().difference(_ascentStartTime!);
          }
          _finishRep();
          state = MovementPhase.neutral;
          feedback = "Başarılı!";
        }
        break;
    }
  }

  // Tekrarı sayar ve skoru hesaplar.
  void _finishRep() {
    repCount++;
    maxROM = _currentRepMinAngle;

    final romScore = _calculateRomScore(maxROM);
    final descentSeconds = lastDescentTime.inMilliseconds / 1000.0;
    final descentScore = _calculateTempoScore(
      actualSeconds: descentSeconds,
      idealSeconds: config.idealDescentSeconds,
    );
    final ascentSeconds = lastAscentTime.inMilliseconds / 1000.0;
    final ascentScoreCandidate = _calculateTempoScore(
      actualSeconds: ascentSeconds,
      idealSeconds: config.idealAscentSeconds,
    );

    // Current final score behavior is preserved: ascent and rep-level form
    // history are visible in the breakdown, but not applied to final scoring yet.
    final finalScore = isFormBad
        ? (romScore + descentScore) / 4
        : (romScore + descentScore) / 2;

    lastRepScore = finalScore;
    lastRepScoreBreakdown = RepScoreBreakdown(
      minAngle: maxROM,
      romScore: romScore,
      descentSeconds: descentSeconds,
      descentScore: descentScore,
      ascentSeconds: ascentSeconds,
      ascentScoreCandidate: ascentScoreCandidate,
      worstBackAngle: _currentRepWorstBackAngle,
      hadFormViolation: _currentRepHadFormViolation,
      finalScore: finalScore,
    );
  }

  double _calculateRomScore(double minAngle) {
    return (100 - (minAngle - config.targetMinAngle)).clamp(0, 100).toDouble();
  }

  double _calculateTempoScore({
    required double actualSeconds,
    required double idealSeconds,
  }) {
    return (100 -
            (idealSeconds - actualSeconds).abs() *
                config.tempoPenaltyPerSecond)
        .clamp(0, 100)
        .toDouble();
  }

  void _startRepMetrics(double angle, double backAngle) {
    _currentRepMinAngle = angle;
    _currentRepWorstBackAngle = backAngle;
    _currentRepHadFormViolation = backAngle < config.formThreshold;
  }

  void _trackRepForm(double backAngle) {
    if (backAngle < _currentRepWorstBackAngle) {
      _currentRepWorstBackAngle = backAngle;
    }
    if (backAngle < config.formThreshold) {
      _currentRepHadFormViolation = true;
    }
  }

  void _resetCurrentRepMetrics() {
    _currentRepMinAngle = 180.0;
    _currentRepWorstBackAngle = 180.0;
    _currentRepHadFormViolation = false;
  }

  // Sırt açısına göre formu kontrol eder.
  void _checkForm(double backAngle) {
    if (backAngle < config.formThreshold) {
      isFormBad = true;
      feedback = "Sırtını Dik Tut!";
    } else {
      isFormBad = false;
    }
  }

  // Sayaç ve metrikleri sıfırlar.
  void reset() {
    repCount = 0;
    state = MovementPhase.neutral;
    feedback = "Sıfırlandı";
    isFormBad = false;
    lastRepScore = 0;
    lastRepScoreBreakdown = null;
    maxROM = 180;
    lastDescentTime = Duration.zero;
    lastAscentTime = Duration.zero;
    _descentStartTime = null;
    _peakStartTime = null;
    _ascentStartTime = null;
    _resetCurrentRepMetrics();
  }
}
