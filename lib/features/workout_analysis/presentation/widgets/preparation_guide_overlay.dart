import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';

class PreparationGuideOverlay extends StatelessWidget {
  const PreparationGuideOverlay({
    required this.exerciseName,
    required this.startPoseTitle,
    required this.startPoseHint,
    required this.instructions,
    required this.voiceCoachEnabled,
    required this.onClose,
    super.key,
  });

  final String exerciseName;
  final String startPoseTitle;
  final String startPoseHint;
  final List<String> instructions;
  final bool voiceCoachEnabled;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final maxHeight = mediaQuery.size.height * (isLandscape ? 0.9 : 0.82);

    return SafeArea(
      child: Align(
        alignment: isLandscape ? Alignment.centerRight : Alignment.center,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 28 : 18,
            vertical: 18,
          ),
          child: Material(
            key: const ValueKey<String>('preparation-guide-overlay'),
            color: const Color(0xFF171717),
            elevation: 18,
            shadowColor: Colors.black,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLandscape ? 460 : 520,
                maxHeight: maxHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 10, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations.preparationGuide,
                                style: const TextStyle(
                                  color: Color(0xFFB9F3E7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                localizations.preparationGuideForExercise(
                                  exerciseName,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  height: 1.15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const ValueKey<String>(
                            'preparation-guide-close',
                          ),
                          tooltip: localizations.close,
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  Flexible(
                    child: SingleChildScrollView(
                      key: const ValueKey<String>('preparation-guide-scroll'),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _GuideHighlight(
                            title: startPoseTitle,
                            message: startPoseHint,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            localizations.preparationGuideSteps,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (
                            var index = 0;
                            index < instructions.length;
                            index++
                          )
                            _GuideStep(
                              number: index + 1,
                              message: instructions[index],
                            ),
                          const SizedBox(height: 14),
                          _VoiceCoachStatus(enabled: voiceCoachEnabled),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideHighlight extends StatelessWidget {
  const _GuideHighlight({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFB9F3E7).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFB9F3E7).withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.accessibility_new_rounded,
            color: Color(0xFFB9F3E7),
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.number, required this.message});

  final int number;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFB9F3E7),
              shape: BoxShape.circle,
            ),
            child: Text(
              number.toString(),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceCoachStatus extends StatelessWidget {
  const _VoiceCoachStatus({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('preparation-guide-voice-status'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: enabled ? Colors.greenAccent : Colors.white54,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              localizations.preparationVoiceCoachStatus(enabled: enabled),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
