import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../mappers/setup_readiness_ui_mapper.dart';
import '../models/setup_readiness_view_data.dart';
import '../providers/preparation_readiness_controller.dart';

/// Keeps preparation guidance outside the camera preview so the user's body,
/// pose overlay, and reference skeleton remain unobstructed.
class PreparationReadinessPanel extends ConsumerWidget {
  const PreparationReadinessPanel({
    required this.request,
    this.compact = false,
    super.key,
  });

  final SetupReadinessRequest request;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = mapSetupReadinessToViewData(
      localizations: AppLocalizations.of(context),
      readinessSnapshot: ref.watch(preparationReadinessStateProvider(request)),
    );
    final color = _readinessColor(readiness.visualState);

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${readiness.statusLabel}: ${readiness.message}',
      child: AnimatedContainer(
        key: const ValueKey<String>('preparation-readiness-panel'),
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 11 : 14,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
          border: Border.all(color: color.withValues(alpha: 0.72), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: compact ? 36 : 42,
              height: compact ? 36 : 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _readinessIcon(readiness.visualState),
                color: color,
                size: compact ? 22 : 25,
              ),
            ),
            SizedBox(width: compact ? 10 : 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    readiness.statusLabel,
                    key: const ValueKey<String>('preparation-readiness-status'),
                    style: TextStyle(
                      color: color,
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    readiness.message,
                    key: const ValueKey<String>(
                      'preparation-readiness-message',
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 16 : 18,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _readinessColor(SetupReadinessVisualState state) {
  return switch (state) {
    SetupReadinessVisualState.checking => Colors.amberAccent,
    SetupReadinessVisualState.needsAdjustment => Colors.orangeAccent,
    SetupReadinessVisualState.ready => Colors.greenAccent,
  };
}

IconData _readinessIcon(SetupReadinessVisualState state) {
  return switch (state) {
    SetupReadinessVisualState.checking => Icons.center_focus_weak_rounded,
    SetupReadinessVisualState.needsAdjustment => Icons.navigation_rounded,
    SetupReadinessVisualState.ready => Icons.check_circle_rounded,
  };
}
