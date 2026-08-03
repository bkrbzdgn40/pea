import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_status_chip.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_motion.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../mappers/setup_readiness_ui_mapper.dart';
import '../models/setup_readiness_view_data.dart';
import '../providers/preparation_readiness_controller.dart';
import 'preparation_visual_style.dart';

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
    final colors = context.semanticColors;
    final readiness = mapSetupReadinessToViewData(
      localizations: AppLocalizations.of(context),
      readinessSnapshot: ref.watch(preparationReadinessStateProvider(request)),
    );
    final color = PreparationVisualStyle.readinessColor(
      context,
      readiness.visualState,
    );
    final completedChecks = readiness.checks
        .where((check) => check.state == SetupReadinessCheckState.complete)
        .length;
    final progressChip = AppStatusChip(
      key: const ValueKey<String>('preparation-readiness-progress'),
      label: '$completedChecks/${readiness.checks.length}',
      tone: PreparationVisualStyle.readinessTone(readiness.visualState),
      icon: Icons.tune_rounded,
    );

    Widget buildStatusSummary() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: compact ? 38 : 44,
            height: compact ? 38 : 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.34)),
            ),
            child: Icon(
              PreparationVisualStyle.readinessIcon(readiness.visualState),
              color: color,
              size: compact ? 22 : 25,
            ),
          ),
          SizedBox(width: compact ? AppSpacing.xs : AppSpacing.sm),
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
                    fontWeight: AppFontWeights.heavy,
                    letterSpacing: 0.15,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  readiness.message,
                  key: const ValueKey<String>('preparation-readiness-message'),
                  maxLines: compact ? 4 : 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: compact ? 16 : 18,
                    height: 1.25,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${readiness.statusLabel}: ${readiness.message}',
      child: AnimatedContainer(
        key: const ValueKey<String>('preparation-readiness-panel'),
        duration: AppMotion.resolveDuration(context, AppMotionDurations.fast),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          vertical: compact ? 11 : AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              color.withValues(alpha: 0.13),
              colors.surfaceStrong,
              colors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(
            compact ? AppRadii.compact : AppRadii.surface,
          ),
          border: Border.all(color: color.withValues(alpha: 0.66), width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.10),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final stackProgress =
                compact && (constraints.maxWidth < 340 || textScale > 1.3);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stackProgress) ...[
                  buildStatusSummary(),
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: progressChip,
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(child: buildStatusSummary()),
                      const SizedBox(width: AppSpacing.xs),
                      progressChip,
                    ],
                  ),
                SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                Divider(height: 1, color: color.withValues(alpha: 0.24)),
                SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: readiness.checks
                      .map(
                        (check) => _PreparationReadinessCheckChip(
                          check: check,
                          compact: compact,
                          maxWidth: constraints.maxWidth,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PreparationReadinessCheckChip extends StatelessWidget {
  const _PreparationReadinessCheckChip({
    required this.check,
    required this.compact,
    required this.maxWidth,
  });

  final SetupReadinessCheckItem check;
  final bool compact;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final color = PreparationVisualStyle.checkColor(context, check.state);

    return Semantics(
      label: check.label,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          key: ValueKey<String>(
            'preparation-readiness-check-${check.type.name}',
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 11,
            vertical: compact ? 7 : 8,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PreparationVisualStyle.checkIcon(check.state),
                  color: color,
                  size: 13,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  check.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: AppFontWeights.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
