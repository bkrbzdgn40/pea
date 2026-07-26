import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../models/preparation_start_gate_state.dart';

class PreparationStartGateControls extends StatelessWidget {
  const PreparationStartGateControls({
    super.key,
    required this.phase,
    required this.countdownValue,
    required this.isConfigReady,
    required this.isCameraReady,
    required this.isPreparing,
    required this.onArm,
    required this.onCancel,
    required this.onOverride,
  });

  final PreparationStartGatePhase? phase;
  final int? countdownValue;
  final bool isConfigReady;
  final bool isCameraReady;
  final bool isPreparing;
  final VoidCallback? onArm;
  final VoidCallback? onCancel;
  final VoidCallback? onOverride;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final currentPhase = phase ?? PreparationStartGatePhase.idle;

    if (currentPhase == PreparationStartGatePhase.monitoring ||
        currentPhase == PreparationStartGatePhase.overrideAvailable) {
      return Container(
        key: const ValueKey<String>('preparation-start-gate-active'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.preparationGateMonitoringTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        localizations.preparationGateMonitoringMessage,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (currentPhase ==
                PreparationStartGatePhase.overrideAvailable) ...[
              const SizedBox(height: 14),
              Text(
                localizations.preparationGateOverrideWarning,
                key: const ValueKey<String>('preparation-override-warning'),
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const ValueKey<String>('preparation-override-analysis'),
                onPressed: onOverride,
                icon: const Icon(Icons.warning_amber_rounded),
                label: Text(localizations.preparationGateOverrideAction),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey<String>('preparation-cancel-gate'),
              onPressed: onCancel,
              child: Text(localizations.preparationGateCancel),
            ),
          ],
        ),
      );
    }

    if (currentPhase == PreparationStartGatePhase.countingDown) {
      return Container(
        key: const ValueKey<String>('preparation-countdown-controls'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: Colors.greenAccent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.preparationCountdownTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        localizations.preparationCountdownMessage,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (countdownValue != null)
                  Text(
                    countdownValue!.toString(),
                    key: const ValueKey<String>(
                      'preparation-countdown-control-value',
                    ),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey<String>('preparation-cancel-countdown'),
              onPressed: onCancel,
              child: Text(localizations.preparationGateCancel),
            ),
          ],
        ),
      );
    }

    if (currentPhase == PreparationStartGatePhase.approved ||
        currentPhase == PreparationStartGatePhase.launching) {
      return ElevatedButton.icon(
        key: const ValueKey<String>('preparation-launching-analysis'),
        onPressed: null,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(localizations.preparationGateLaunching),
        style: _startButtonStyle(),
      );
    }

    return ElevatedButton.icon(
      key: const ValueKey<String>('preparation-start-gate'),
      onPressed: onArm,
      icon: isPreparing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.center_focus_strong_rounded),
      label: Text(
        !isConfigReady
            ? localizations.analysisConfigLoading
            : !isCameraReady
            ? localizations.preparationCameraUnavailable
            : localizations.startPreparationCheck,
      ),
      style: _startButtonStyle(),
    );
  }

  ButtonStyle _startButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.greenAccent,
      foregroundColor: Colors.black,
      disabledBackgroundColor: Colors.white24,
      disabledForegroundColor: Colors.white70,
      minimumSize: const Size.fromHeight(56),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
