import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class PreparationCountdownFeedback {
  Future<void> tick();

  Future<void> complete();
}

class SystemPreparationCountdownFeedback
    implements PreparationCountdownFeedback {
  const SystemPreparationCountdownFeedback();

  @override
  Future<void> tick() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Countdown visuals remain usable when haptics are unavailable.
    }
  }

  @override
  Future<void> complete() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Countdown visuals remain usable when haptics are unavailable.
    }
  }
}

final preparationCountdownFeedbackProvider =
    Provider<PreparationCountdownFeedback>(
      (ref) => const SystemPreparationCountdownFeedback(),
    );
