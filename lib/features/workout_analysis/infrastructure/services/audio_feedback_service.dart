import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../application/feedback_delivery_controller.dart';

/// Platform text-to-speech adapter for live workout feedback.
class AudioFeedbackService implements VoiceFeedbackOutput {
  AudioFeedbackService({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;
  bool _isConfigured = false;

  Future<void> _ensureConfigured() async {
    if (_isConfigured) {
      return;
    }

    try {
      await _flutterTts.setLanguage('tr-TR');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isConfigured = true;
    } on MissingPluginException {
      // Unit/widget tests do not register the native TTS plugin.
    } on PlatformException {
      // Delivery failure must never break the pose-analysis pipeline.
    }
  }

  @override
  Future<void> speak(String message) async {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      return;
    }

    try {
      await _ensureConfigured();
      await _flutterTts.stop();
      await _flutterTts.speak(normalizedMessage);
    } on MissingPluginException {
      // Keep analysis operational when the platform implementation is absent.
    } on PlatformException {
      // Voice feedback is best-effort and must not interrupt analysis.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } on MissingPluginException {
      // Expected in unit/widget tests without a registered platform plugin.
    } on PlatformException {
      // Nothing else to clean up if the platform call itself is unavailable.
    }
  }
}
