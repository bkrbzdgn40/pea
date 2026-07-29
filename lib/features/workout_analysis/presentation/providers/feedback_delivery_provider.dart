import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/feedback_delivery_controller.dart';
import '../../infrastructure/services/audio_feedback_service.dart';
import 'settings_provider.dart';

final feedbackDeliveryProvider = AutoDisposeProvider<FeedbackDeliveryPort>((
  ref,
) {
  final controller = FeedbackDeliveryController(
    voiceOutput: AudioFeedbackService(
      languageTagResolver: () =>
          ref.read(appLocalizationsProvider).ttsLanguageTag,
    ),
    preferencesResolver: () {
      final settings = ref.read(runtimeWorkoutSettingsProvider);
      return FeedbackDeliveryPreferences(
        voiceEnabled: settings.voiceCoachEnabled,
        frequency: settings.feedbackFrequency,
      );
    },
  );
  ref.onDispose(() {
    unawaited(controller.stop());
  });
  return controller;
});
