/// Delivery category for the single primary feedback selected by arbitration.
///
/// This layer does not re-rank feedback. It only controls how an already
/// selected cue is delivered to the user.
enum FeedbackDeliveryKind { status, movement, corrective, blocking }

enum FeedbackFrequency { reduced, normal, frequent }

class FeedbackDeliveryPreferences {
  const FeedbackDeliveryPreferences({
    this.voiceEnabled = true,
    this.frequency = FeedbackFrequency.normal,
  });

  final bool voiceEnabled;
  final FeedbackFrequency frequency;
}

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

abstract interface class FeedbackDeliveryPort {
  Future<FeedbackDeliveryResult> deliver(FeedbackDeliveryCue cue);

  Future<void> stop();

  void reset();
}

enum FeedbackDeliveryDisposition {
  delivered,
  disabled,
  emptyMessage,
  repeatedTooSoon,
}

class FeedbackDeliveryResult {
  const FeedbackDeliveryResult({required this.disposition, required this.cue});

  final FeedbackDeliveryDisposition disposition;
  final FeedbackDeliveryCue cue;

  bool get wasDelivered => disposition == FeedbackDeliveryDisposition.delivered;
}

/// Delivers already-arbitrated feedback through the voice coach.
///
/// Preferences are resolved for every cue so Settings changes apply without
/// rebuilding the workout analysis controller. Visual feedback remains outside
/// this delivery layer and is never suppressed here.
class FeedbackDeliveryController implements FeedbackDeliveryPort {
  FeedbackDeliveryController({
    required VoiceFeedbackOutput voiceOutput,
    DateTime Function()? now,
    FeedbackDeliveryPreferences Function()? preferencesResolver,
    Map<FeedbackDeliveryKind, Duration>? normalRepeatCooldowns,
  }) : _voiceOutput = voiceOutput,
       _now = now ?? DateTime.now,
       _preferencesResolver =
           preferencesResolver ?? _defaultPreferencesResolver,
       _normalRepeatCooldowns =
           Map<FeedbackDeliveryKind, Duration>.unmodifiable(
             normalRepeatCooldowns ?? _defaultNormalRepeatCooldowns,
           );

  static const Map<FeedbackDeliveryKind, Duration>
  _defaultNormalRepeatCooldowns = <FeedbackDeliveryKind, Duration>{
    FeedbackDeliveryKind.status: Duration(seconds: 4),
    FeedbackDeliveryKind.movement: Duration(seconds: 2),
    FeedbackDeliveryKind.corrective: Duration(seconds: 3),
    FeedbackDeliveryKind.blocking: Duration(seconds: 3),
  };

  static FeedbackDeliveryPreferences _defaultPreferencesResolver() {
    return const FeedbackDeliveryPreferences();
  }

  final VoiceFeedbackOutput _voiceOutput;
  final DateTime Function() _now;
  final FeedbackDeliveryPreferences Function() _preferencesResolver;
  final Map<FeedbackDeliveryKind, Duration> _normalRepeatCooldowns;

  String? _lastSpokenMessage;
  DateTime? _lastSpokenAt;

  @override
  Future<FeedbackDeliveryResult> deliver(FeedbackDeliveryCue cue) async {
    final normalizedMessage = cue.message.trim();
    if (normalizedMessage.isEmpty) {
      return FeedbackDeliveryResult(
        disposition: FeedbackDeliveryDisposition.emptyMessage,
        cue: cue,
      );
    }

    final preferences = _preferencesResolver();
    if (!preferences.voiceEnabled) {
      return FeedbackDeliveryResult(
        disposition: FeedbackDeliveryDisposition.disabled,
        cue: cue,
      );
    }

    final now = _now();
    final repeatCooldown = _repeatCooldownFor(cue.kind, preferences.frequency);
    final lastSpokenAt = _lastSpokenAt;
    final isSameSpokenMessage = _lastSpokenMessage == normalizedMessage;
    final shouldSpeak =
        !isSameSpokenMessage ||
        lastSpokenAt == null ||
        now.difference(lastSpokenAt) >= repeatCooldown;

    if (!shouldSpeak) {
      return FeedbackDeliveryResult(
        disposition: FeedbackDeliveryDisposition.repeatedTooSoon,
        cue: cue,
      );
    }

    _lastSpokenMessage = normalizedMessage;
    _lastSpokenAt = now;
    await _voiceOutput.speak(normalizedMessage);

    return FeedbackDeliveryResult(
      disposition: FeedbackDeliveryDisposition.delivered,
      cue: cue,
    );
  }

  Duration _repeatCooldownFor(
    FeedbackDeliveryKind kind,
    FeedbackFrequency frequency,
  ) {
    final normal = _normalRepeatCooldowns[kind] ?? Duration.zero;
    final multiplier = switch (frequency) {
      FeedbackFrequency.reduced => 2.0,
      FeedbackFrequency.normal => 1.0,
      FeedbackFrequency.frequent => 0.5,
    };
    return Duration(microseconds: (normal.inMicroseconds * multiplier).round());
  }

  @override
  Future<void> stop() => _voiceOutput.stop();

  @override
  void reset() {
    _lastSpokenMessage = null;
    _lastSpokenAt = null;
  }
}
