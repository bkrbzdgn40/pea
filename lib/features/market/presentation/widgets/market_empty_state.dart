import 'package:flutter/material.dart';

import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';

class MarketEmptyState extends StatelessWidget {
  const MarketEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.actionKey,
    this.actionIcon = Icons.arrow_back_rounded,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final Key? actionKey;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Center(
      child: SingleChildScrollView(
        child: AppSurfaceCard(
          variant: AppSurfaceVariant.muted,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: colors.analysisAccent),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.foreground,
                  fontWeight: AppFontWeights.heavy,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.foregroundMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                key: actionKey,
                onPressed: onAction,
                icon: Icon(actionIcon),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
