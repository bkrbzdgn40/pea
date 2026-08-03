import 'package:flutter/material.dart';

import '../../theme/app_design_tokens.dart';
import '../../theme/app_semantic_colors.dart';
import 'app_button.dart';
import 'app_status_tone.dart';
import 'app_surface_card.dart';

class AppFeedbackBanner extends StatelessWidget {
  const AppFeedbackBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = AppStatusTone.accent,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.liveRegion = true,
  }) : assert(
         (actionLabel == null && onAction == null) ||
             (actionLabel != null && onAction != null),
         'actionLabel and onAction must be provided together.',
       );

  final String message;
  final String? title;
  final AppStatusTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final toneColor = tone.resolveColor(colors);

    return Semantics(
      container: true,
      liveRegion: liveRegion,
      child: AppSurfaceCard(
        color: toneColor.withValues(alpha: AppOpacity.subtle),
        borderColor: toneColor.withValues(alpha: AppOpacity.strongBorder),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: toneColor.withValues(alpha: AppOpacity.subtle),
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: Icon(icon ?? tone.defaultIcon, color: toneColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.foreground,
                        fontWeight: AppFontWeights.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                  ],
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.foregroundMuted,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: AppButton(
                        label: actionLabel!,
                        onPressed: onAction,
                        variant: AppButtonVariant.ghost,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
