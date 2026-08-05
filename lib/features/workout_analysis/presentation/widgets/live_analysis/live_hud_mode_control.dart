import 'package:flutter/material.dart';

import '../../../../../app/localization/app_localizations.dart';
import 'live_analysis_theme.dart';

class LiveHudModeControl extends StatelessWidget {
  const LiveHudModeControl({
    super.key,
    required this.compact,
    required this.showDetails,
    required this.onPressed,
  });

  final bool compact;
  final bool showDetails;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final label = showDetails
        ? localizations.liveHudUseMinimalView
        : localizations.liveHudShowDetails;

    return Semantics(
      button: true,
      toggled: showDetails,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey<String>('live-hud-mode-toggle'),
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Ink(
              width: compact ? 40 : 48,
              height: compact ? 40 : 48,
              decoration: BoxDecoration(
                color: liveHudSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: (showDetails ? liveHudAccent : Colors.white70)
                      .withValues(alpha: 0.52),
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                showDetails
                    ? Icons.filter_center_focus_rounded
                    : Icons.tune_rounded,
                color: showDetails ? liveHudAccent : Colors.white,
                size: compact ? 20 : 23,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
