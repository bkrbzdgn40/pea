import 'package:flutter/services.dart';

import '../../application/feedback_delivery_controller.dart';

/// Flutter platform haptic adapter for live workout feedback.
class HapticFeedbackService implements HapticFeedbackOutput {
  const HapticFeedbackService();

  @override
  Future<void> trigger(FeedbackHapticPattern pattern) async {
    try {
      switch (pattern) {
        case FeedbackHapticPattern.none:
          return;
        case FeedbackHapticPattern.light:
          await HapticFeedback.lightImpact();
          return;
        case FeedbackHapticPattern.medium:
          await HapticFeedback.mediumImpact();
          return;
        case FeedbackHapticPattern.heavy:
          await HapticFeedback.heavyImpact();
          return;
      }
    } on MissingPluginException {
      // Unit/widget tests do not register the native haptic platform channel.
    } on PlatformException {
      // Haptic delivery is best-effort and must not interrupt analysis.
    }
  }
}
