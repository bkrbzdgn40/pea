import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/localization/app_localizations.dart';
import '../../../application/workout_analysis_failure_policy.dart';
import '../../providers/workout_analysis_health_controller.dart';
import '../../providers/workout_controller.dart';

class WorkoutAnalysisFailureOverlay extends ConsumerWidget {
  const WorkoutAnalysisFailureOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(workoutAnalysisHealthControllerProvider);
    if (health.isHealthy) {
      return const SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context);
    final isBlocked = health.isBlocked;
    final isTimeout =
        health.failureKind == WorkoutAnalysisFailureKind.poseDetectionTimeout;
    final title = isBlocked
        ? localizations.analysisInterruptedTitle
        : localizations.analysisRecoveringTitle;
    final message = isBlocked
        ? isTimeout
              ? localizations.analysisTimeoutMessage
              : localizations.analysisRepeatedFailureMessage
        : localizations.analysisRecoveringMessage;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.68),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              key: const ValueKey<String>('workout-analysis-failure-overlay'),
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isBlocked ? Colors.orangeAccent : Colors.amberAccent,
                  width: 1.4,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    isBlocked
                        ? Icons.warning_amber_rounded
                        : Icons.sync_rounded,
                    color: isBlocked ? Colors.orangeAccent : Colors.amberAccent,
                    size: 42,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    key: const ValueKey<String>(
                      'workout-analysis-failure-title',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    key: const ValueKey<String>(
                      'workout-analysis-failure-message',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isBlocked) ...<Widget>[
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      key: const ValueKey<String>(
                        'workout-analysis-retry-button',
                      ),
                      onPressed: () => ref
                          .read(workoutControllerProvider.notifier)
                          .retryAnalysis(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(localizations.retry),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
