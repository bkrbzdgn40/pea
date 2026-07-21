import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/feedback_delivery_controller.dart';

void main() {
  group('FeedbackDeliveryController', () {
    late _FakeClock clock;
    late _RecordingVoiceOutput voice;
    late _RecordingHapticOutput haptic;
    late FeedbackDeliveryController controller;

    setUp(() {
      clock = _FakeClock(DateTime.utc(2030, 1, 1));
      voice = _RecordingVoiceOutput();
      haptic = _RecordingHapticOutput();
      controller = FeedbackDeliveryController(
        voiceOutput: voice,
        hapticOutput: haptic,
        now: clock.now,
      );
    });

    test(
      'delivers corrective feedback through voice and medium haptic',
      () async {
        final result = await controller.deliver(
          const FeedbackDeliveryCue(
            id: 'range:maintain_form',
            message: 'Formunu koru',
            kind: FeedbackDeliveryKind.corrective,
          ),
        );

        expect(result.wasDelivered, isTrue);
        expect(result.hapticPattern, FeedbackHapticPattern.medium);
        expect(voice.messages, <String>['Formunu koru']);
        expect(haptic.patterns, <FeedbackHapticPattern>[
          FeedbackHapticPattern.medium,
        ]);
      },
    );

    test('suppresses the exact same cue inside its repeat cooldown', () async {
      const cue = FeedbackDeliveryCue(
        id: 'range:maintain_form',
        message: 'Formunu koru',
        kind: FeedbackDeliveryKind.corrective,
      );

      await controller.deliver(cue);
      clock.advance(const Duration(seconds: 2));
      final repeated = await controller.deliver(cue);

      expect(repeated.disposition, FeedbackDeliveryDisposition.repeatedTooSoon);
      expect(voice.messages, hasLength(1));
      expect(haptic.patterns, hasLength(1));
    });

    test('allows the same cue again after its repeat cooldown', () async {
      const cue = FeedbackDeliveryCue(
        id: 'range:maintain_form',
        message: 'Formunu koru',
        kind: FeedbackDeliveryKind.corrective,
      );

      await controller.deliver(cue);
      clock.advance(const Duration(seconds: 3));
      final repeated = await controller.deliver(cue);

      expect(repeated.wasDelivered, isTrue);
      expect(voice.messages, hasLength(2));
      expect(haptic.patterns, hasLength(2));
    });

    test(
      'delivers a different cue immediately during the previous cooldown',
      () async {
        await controller.deliver(
          const FeedbackDeliveryCue(
            id: 'range:descend',
            message: 'Asagi in',
            kind: FeedbackDeliveryKind.movement,
          ),
        );
        clock.advance(const Duration(milliseconds: 100));

        final corrective = await controller.deliver(
          const FeedbackDeliveryCue(
            id: 'range:maintain_form',
            message: 'Formunu koru',
            kind: FeedbackDeliveryKind.corrective,
          ),
        );

        expect(corrective.wasDelivered, isTrue);
        expect(voice.messages, <String>['Asagi in', 'Formunu koru']);
        expect(haptic.patterns, <FeedbackHapticPattern>[
          FeedbackHapticPattern.light,
          FeedbackHapticPattern.medium,
        ]);
      },
    );

    test('status feedback is spoken without haptic output', () async {
      final result = await controller.deliver(
        const FeedbackDeliveryCue(
          id: 'range:ready',
          message: 'Hazir',
          kind: FeedbackDeliveryKind.status,
        ),
      );

      expect(result.wasDelivered, isTrue);
      expect(result.hapticPattern, FeedbackHapticPattern.none);
      expect(voice.messages, <String>['Hazir']);
      expect(haptic.patterns, isEmpty);
    });

    test('blocking feedback uses heavy haptic output', () async {
      final result = await controller.deliver(
        const FeedbackDeliveryCue(
          id: 'range:body_not_visible',
          message: 'Vucut net gorunmuyor',
          kind: FeedbackDeliveryKind.blocking,
        ),
      );

      expect(result.hapticPattern, FeedbackHapticPattern.heavy);
      expect(haptic.patterns, <FeedbackHapticPattern>[
        FeedbackHapticPattern.heavy,
      ]);
    });

    test('empty messages do not reach either output', () async {
      final result = await controller.deliver(
        const FeedbackDeliveryCue(
          id: 'empty',
          message: '   ',
          kind: FeedbackDeliveryKind.corrective,
        ),
      );

      expect(result.disposition, FeedbackDeliveryDisposition.emptyMessage);
      expect(voice.messages, isEmpty);
      expect(haptic.patterns, isEmpty);
    });

    test('reset clears repeat suppression state', () async {
      const cue = FeedbackDeliveryCue(
        id: 'range:ready',
        message: 'Hazir',
        kind: FeedbackDeliveryKind.status,
      );

      await controller.deliver(cue);
      controller.reset();
      final afterReset = await controller.deliver(cue);

      expect(afterReset.wasDelivered, isTrue);
      expect(voice.messages, hasLength(2));
    });

    test('stop delegates to the voice output', () async {
      await controller.stop();

      expect(voice.stopCallCount, 1);
    });
  });
}

class _FakeClock {
  _FakeClock(this.current);

  DateTime current;

  DateTime now() => current;

  void advance(Duration duration) {
    current = current.add(duration);
  }
}

class _RecordingVoiceOutput implements VoiceFeedbackOutput {
  final List<String> messages = <String>[];
  int stopCallCount = 0;

  @override
  Future<void> speak(String message) async {
    messages.add(message);
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
  }
}

class _RecordingHapticOutput implements HapticFeedbackOutput {
  final List<FeedbackHapticPattern> patterns = <FeedbackHapticPattern>[];

  @override
  Future<void> trigger(FeedbackHapticPattern pattern) async {
    patterns.add(pattern);
  }
}
