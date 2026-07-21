/// Delivery category for the single primary feedback selected by arbitration.
///
/// This layer does not re-rank feedback. It only controls how an already
/// selected cue is delivered to the user.
enum FeedbackDeliveryKind { status, movement, corrective, blocking }

enum FeedbackHapticPattern { none, light, medium, heavy }

class FeedbackDeliveryCue {
  const FeedbackDeliveryCue({
    required this.id,
    required this.message,
    required this.kind,
  });

  final String id;
  final String message;
  final FeedbackDeliveryKind kind;
}

abstract interface class VoiceFeedbackOutput {
  Future<void> speak(String message);

  Future<void> stop();
}

abstract interface class HapticFeedbackOutput {
  Future<void> trigger(FeedbackHapticPattern pattern);
}

abstract interface class FeedbackDeliveryPort {
  Future<FeedbackDeliveryResult> deliver(FeedbackDeliveryCue cue);

  Future<void> stop();

  void reset();
}

enum FeedbackDeliveryDisposition { delivered, emptyMessage, repeatedTooSoon }

class FeedbackDeliveryResult {
  const FeedbackDeliveryResult({
    required this.disposition,
    required this.cue,
    required this.hapticPattern,
  });

  final FeedbackDeliveryDisposition disposition;
  final FeedbackDeliveryCue cue;
  final FeedbackHapticPattern hapticPattern;

  bool get wasDelivered => disposition == FeedbackDeliveryDisposition.delivered;
}

/// Delivers already-arbitrated feedback through voice and haptic outputs.
///
/// Exact repeated cues are suppressed for a small, category-specific cooldown
/// so camera-frame frequency cannot become speech frequency. A different cue is
/// delivered immediately, allowing urgent corrective or blocking feedback to
/// replace stale guidance without waiting for the previous cue's cooldown.
class FeedbackDeliveryController implements FeedbackDeliveryPort {
  FeedbackDeliveryController({
    required VoiceFeedbackOutput voiceOutput,
    required HapticFeedbackOutput hapticOutput,
    DateTime Function()? now,
    this.voiceEnabled = true,
    this.hapticEnabled = true,
    Map<FeedbackDeliveryKind, Duration>? repeatCooldowns,
  }) : _voiceOutput = voiceOutput,
       _hapticOutput = hapticOutput,
       _now = now ?? DateTime.now,
       _repeatCooldowns = Map<FeedbackDeliveryKind, Duration>.unmodifiable(
         repeatCooldowns ?? _defaultRepeatCooldowns,
       );

  static const Map<FeedbackDeliveryKind, Duration> _defaultRepeatCooldowns =
      <FeedbackDeliveryKind, Duration>{
        FeedbackDeliveryKind.status: Duration(seconds: 4),
        FeedbackDeliveryKind.movement: Duration(seconds: 2),
        FeedbackDeliveryKind.corrective: Duration(seconds: 3),
        FeedbackDeliveryKind.blocking: Duration(seconds: 3),
      };

  final VoiceFeedbackOutput _voiceOutput;
  final HapticFeedbackOutput _hapticOutput;
  final DateTime Function() _now;
  final bool voiceEnabled;
  final bool hapticEnabled;
  final Map<FeedbackDeliveryKind, Duration> _repeatCooldowns;

  String? _lastDeliveredCueId;
  DateTime? _lastDeliveredAt;

  @override
  Future<FeedbackDeliveryResult> deliver(FeedbackDeliveryCue cue) async {
    final normalizedMessage = cue.message.trim();
    if (normalizedMessage.isEmpty) {
      return FeedbackDeliveryResult(
        disposition: FeedbackDeliveryDisposition.emptyMessage,
        cue: cue,
        hapticPattern: FeedbackHapticPattern.none,
      );
    }

    final now = _now();
    final lastDeliveredAt = _lastDeliveredAt;
    final isExactRepeat = _lastDeliveredCueId == cue.id;
    final cooldown = _repeatCooldowns[cue.kind] ?? Duration.zero;
    if (isExactRepeat &&
        lastDeliveredAt != null &&
        now.difference(lastDeliveredAt) < cooldown) {
      return FeedbackDeliveryResult(
        disposition: FeedbackDeliveryDisposition.repeatedTooSoon,
        cue: cue,
        hapticPattern: FeedbackHapticPattern.none,
      );
    }

    _lastDeliveredCueId = cue.id;
    _lastDeliveredAt = now;

    if (voiceEnabled) {
      await _voiceOutput.speak(normalizedMessage);
    }

    final hapticPattern = hapticEnabled
        ? _hapticPatternFor(cue.kind)
        : FeedbackHapticPattern.none;
    if (hapticPattern != FeedbackHapticPattern.none) {
      await _hapticOutput.trigger(hapticPattern);
    }

    return FeedbackDeliveryResult(
      disposition: FeedbackDeliveryDisposition.delivered,
      cue: cue,
      hapticPattern: hapticPattern,
    );
  }

  FeedbackHapticPattern _hapticPatternFor(FeedbackDeliveryKind kind) {
    return switch (kind) {
      FeedbackDeliveryKind.status => FeedbackHapticPattern.none,
      FeedbackDeliveryKind.movement => FeedbackHapticPattern.light,
      FeedbackDeliveryKind.corrective => FeedbackHapticPattern.medium,
      FeedbackDeliveryKind.blocking => FeedbackHapticPattern.heavy,
    };
  }

  @override
  Future<void> stop() => _voiceOutput.stop();

  @override
  void reset() {
    _lastDeliveredCueId = null;
    _lastDeliveredAt = null;
  }
}
