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

class ExerciseEngine {
  final ExerciseConfig config;
  
  MovementPhase state = MovementPhase.neutral;
  int repCount = 0;
  bool isFormBad = false;
  
  // Metrikler
  double maxROM = 180.0; 
  double lastRepScore = 0.0;
  String feedback = "Hazır!";
  
  DateTime? _descentStartTime;
  DateTime? _peakStartTime;
  DateTime? _ascentStartTime;
  
  Duration lastDescentTime = Duration.zero;
  Duration lastAscentTime = Duration.zero;

  double _currentRepMinAngle = 180.0;

  ExerciseEngine({required this.config});

  // Formu ve tekrar fazını günceller.
  void update(double currentAngle, double backAngle) {
    _checkForm(backAngle);
    _processState(currentAngle);
  }

  // Açıya göre faz geçişlerini yönetir.
  void _processState(double angle) {
    switch (state) {
      case MovementPhase.neutral:
        if (angle < config.thresholdActive) {
          state = MovementPhase.descending;
          _descentStartTime = DateTime.now();
          _currentRepMinAngle = angle;
          feedback = "Aşağı in...";
        }
        break;

      case MovementPhase.descending:
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
          feedback = "Hareketi tamamlamadın.";
        }
        break;

      case MovementPhase.peak:
        if (angle < _currentRepMinAngle) _currentRepMinAngle = angle;
        
        if (angle > config.thresholdPeak + 10) { 
          state = MovementPhase.ascending;
          _ascentStartTime = DateTime.now();
          feedback = "Yukarı...";
        }
        break;

      case MovementPhase.ascending:
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
    
    // 1. ROM Skoru (Derinlik)
    double romScore = (100 - (maxROM - 70)).clamp(0, 100);
    
    // 2. Tempo Skoru (İniş hızı kontrolü)
    double idealDescent = config.idealDescentSeconds;
    double actualDescent = lastDescentTime.inMilliseconds / 1000.0;
    double tempoScore = (100 - (idealDescent - actualDescent).abs() * 20).clamp(0, 100);

    // 3. Form Cezası
    lastRepScore = isFormBad ? (romScore + tempoScore) / 4 : (romScore + tempoScore) / 2;
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
    lastRepScore = 0;
    maxROM = 180;
  }
}
