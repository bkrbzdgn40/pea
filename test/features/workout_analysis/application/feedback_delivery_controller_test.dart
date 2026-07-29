import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/feedback_delivery_controller.dart';

void main() {
  group('FeedbackDeliveryController', () {
    late _FakeClock clock;
    late _RecordingVoiceOutput voice;
    late FeedbackDeliveryPreferences preferences;
    late FeedbackDeliveryController controller;

    setUp(() {
      clock = _FakeClock(DateTime.utc(2030, 1, 1));
      voice = _RecordingVoiceOutput();
      preferences = const FeedbackDeliveryPreferences();
      controller = FeedbackDeliveryController(
        voiceOutput: voice,
        now: clock.now,
        preferencesResolver: () => preferences,
      );
    });

    test('delivers corrective feedback through voice', () async {
      final result = await controller.deliver(
        const FeedbackDeliveryCue(
          id: 'range:maintain_form',
          message: 'Formunu koru',
          kind: FeedbackDeliveryKind.corrective,
        ),
      );

      expect(result.wasDelivered, isTrue);
      expect(voice.messages, <String>['Formunu koru']);
    });

    test('suppresses the same message inside its repeat cooldown', () async {
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
    });

    test('repeats voice after the cooldown expires', () async {
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
    });

    test('delivers a different message immediately', () async {
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
    });

    test('does not repeat identical speech from a different cue id', () async {
      await controller.deliver(
        const FeedbackDeliveryCue(
          id: 'range:ascend',
          message: 'Ritmi koru',
          kind: FeedbackDeliveryKind.movement,
        ),
      );

      final sameSpeech = await controller.deliver(
        const FeedbackDeliveryCue(
          id: 'range:stabilize_transition',
          message: 'Ritmi koru',
          kind: FeedbackDeliveryKind.corrective,
        ),
      );

      expect(
        sameSpeech.disposition,
        FeedbackDeliveryDisposition.repeatedTooSoon,
      );
      expect(voice.messages, <String>['Ritmi koru']);
    });

    test('speaks an earlier message again after the text changes', () async {
      const descend = FeedbackDeliveryCue(
        id: 'range:descend',
        message: 'Asagi in',
        kind: FeedbackDeliveryKind.movement,
      );
      const ascend = FeedbackDeliveryCue(
        id: 'range:ascend',
        message: 'Yukari cik',
        kind: FeedbackDeliveryKind.movement,
      );

      await controller.deliver(descend);
      await controller.deliver(ascend);
      await controller.deliver(descend);

      expect(voice.messages, <String>['Asagi in', 'Yukari cik', 'Asagi in']);
    });

    test('voice disabled returns disabled without speech', () async {
      preferences = const FeedbackDeliveryPreferences(voiceEnabled: false);

      final result = await controller.deliver(
        const FeedbackDeliveryCue(
          id: 'range:maintain_form',
          message: 'Formunu koru',
          kind: FeedbackDeliveryKind.corrective,
        ),
      );

      expect(result.disposition, FeedbackDeliveryDisposition.disabled);
      expect(voice.messages, isEmpty);
    });

    test(
      'runtime preference changes apply without recreating controller',
      () async {
        const cue = FeedbackDeliveryCue(
          id: 'range:maintain_form',
          message: 'Formunu koru',
          kind: FeedbackDeliveryKind.corrective,
        );

        preferences = const FeedbackDeliveryPreferences(voiceEnabled: false);
        await controller.deliver(cue);

        preferences = const FeedbackDeliveryPreferences();
        final enabled = await controller.deliver(cue);

        expect(enabled.wasDelivered, isTrue);
        expect(voice.messages, <String>['Formunu koru']);
      },
    );

    test('reduced frequency extends voice repeat cooldown', () async {
      preferences = const FeedbackDeliveryPreferences(
        frequency: FeedbackFrequency.reduced,
      );
      const cue = FeedbackDeliveryCue(
        id: 'range:maintain_form',
        message: 'Formunu koru',
        kind: FeedbackDeliveryKind.corrective,
      );

      await controller.deliver(cue);
      clock.advance(const Duration(seconds: 5));
      final suppressed = await controller.deliver(cue);
      clock.advance(const Duration(seconds: 1));
      final repeated = await controller.deliver(cue);

      expect(
        suppressed.disposition,
        FeedbackDeliveryDisposition.repeatedTooSoon,
      );
      expect(repeated.wasDelivered, isTrue);
      expect(voice.messages, hasLength(2));
    });

    test('frequent frequency shortens voice repeat cooldown', () async {
      preferences = const FeedbackDeliveryPreferences(
        frequency: FeedbackFrequency.frequent,
      );
      const cue = FeedbackDeliveryCue(
        id: 'range:maintain_form',
        message: 'Formunu koru',
        kind: FeedbackDeliveryKind.corrective,
      );

      await controller.deliver(cue);
      clock.advance(const Duration(milliseconds: 1499));
      final suppressed = await controller.deliver(cue);
      clock.advance(const Duration(milliseconds: 1));
      final repeated = await controller.deliver(cue);

      expect(
        suppressed.disposition,
        FeedbackDeliveryDisposition.repeatedTooSoon,
      );
      expect(repeated.wasDelivered, isTrue);
      expect(voice.messages, hasLength(2));
    });

    test('empty messages do not reach voice output', () async {
      final result = await controller.deliver(
        const FeedbackDeliveryCue(
          id: 'empty',
          message: '   ',
          kind: FeedbackDeliveryKind.corrective,
        ),
      );

      expect(result.disposition, FeedbackDeliveryDisposition.emptyMessage);
      expect(voice.messages, isEmpty);
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
