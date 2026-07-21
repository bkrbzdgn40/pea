import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/feedback_delivery_controller.dart';
import '../../infrastructure/services/audio_feedback_service.dart';
import '../../infrastructure/services/haptic_feedback_service.dart';

final feedbackDeliveryProvider = AutoDisposeProvider<FeedbackDeliveryPort>((
  ref,
) {
  final controller = FeedbackDeliveryController(
    voiceOutput: AudioFeedbackService(),
    hapticOutput: const HapticFeedbackService(),
  );
  ref.onDispose(() {
    unawaited(controller.stop());
  });
  return controller;
});
