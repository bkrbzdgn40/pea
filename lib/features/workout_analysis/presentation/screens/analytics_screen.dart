import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_feedback_banner.dart';
import '../../../../app/presentation/widgets/app_metric_tile.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_status_tone.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../models/home_dashboard_data.dart';
import '../providers/home_dashboard_provider.dart';
import '../providers/user_sessions_snapshot_provider.dart';
import '../widgets/exercise_distribution_card.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final dashboardAsync = ref.watch(homeDashboardProvider);
    final dashboardData =
        dashboardAsync.valueOrNull ??
        HomeDashboardData.fallback(
          source: dashboardAsync.hasError
              ? HomeDashboardSource.error
              : HomeDashboardSource.loading,
        );

    void refresh() {
      ref.invalidate(userSessionsSnapshotProvider);
      ref.invalidate(homeDashboardProvider);
    }

    return AppScaffoldShell(
      title: localizations.analytics,
      currentPage: AppDestination.analytics,
      padding: EdgeInsets.zero,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppLayout.of(context, constraints: constraints);

          return SingleChildScrollView(
            key: const PageStorageKey<String>('analytics-scroll-view'),
            padding: layout.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AnalyticsHeader(),
                SizedBox(height: layout.panelGap),
                _AnalyticsBody(data: dashboardData, onRetry: refresh),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      variant: AppSurfaceVariant.strong,
      padding: AppSpacing.headerSurfacePadding,
      borderColor: colors.analysisAccent.withValues(alpha: AppOpacity.border),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.analysisAccent.withValues(alpha: AppOpacity.subtle),
              borderRadius: BorderRadius.circular(AppRadii.compact),
              border: Border.all(
                color: colors.analysisAccent.withValues(
                  alpha: AppOpacity.strongBorder,
                ),
              ),
            ),
            child: Icon(
              Icons.query_stats_rounded,
              color: colors.analysisAccent,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.analyticsHeaderTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  localizations.analyticsHeaderSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.4,
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

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.data, required this.onRetry});

  final HomeDashboardData data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return switch (data.source) {
      HomeDashboardSource.loading => AppFeedbackBanner(
        title: localizations.analytics,
        message: localizations.loading,
        tone: AppStatusTone.accent,
        icon: Icons.hourglass_top_rounded,
        liveRegion: false,
      ),
      HomeDashboardSource.error => AppFeedbackBanner(
        title: localizations.dataLoadFailed,
        message: localizations.analyticsLoadFailed,
        tone: AppStatusTone.danger,
        actionLabel: localizations.retry,
        onAction: onRetry,
      ),
      HomeDashboardSource.noUser ||
      HomeDashboardSource.empty => const _AnalyticsEmptyState(),
      HomeDashboardSource.real => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AnalyticsMetrics(data: data),
          const SizedBox(height: AppSpacing.md),
          ExerciseDistributionCard(items: data.exerciseDistribution),
        ],
      ),
    };
  }
}

class _AnalyticsMetrics extends StatelessWidget {
  const _AnalyticsMetrics({required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final cards = <Widget>[
      AppMetricTile(
        key: const ValueKey('analytics-total-analyses'),
        label: localizations.totalAnalyses,
        value: data.totalAnalyses.toString(),
        icon: Icons.analytics_outlined,
        tone: AppStatusTone.accent,
      ),
      AppMetricTile(
        key: const ValueKey('analytics-this-week'),
        label: localizations.thisWeek,
        value: data.thisWeekCount.toString(),
        icon: Icons.calendar_today_rounded,
        tone: AppStatusTone.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            MediaQuery.textScalerOf(context).scale(1) >= 1.6 ||
            constraints.maxWidth < 360;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cards.first,
              const SizedBox(height: AppSpacing.xs),
              cards.last,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards.first),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: cards.last),
            ],
          ),
        );
      },
    );
  }
}

class _AnalyticsEmptyState extends StatelessWidget {
  const _AnalyticsEmptyState();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      variant: AppSurfaceVariant.accent,
      padding: AppSpacing.headerSurfacePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.query_stats_rounded,
            color: colors.analysisAccent,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.analyticsEmptyTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  localizations.analyticsEmptyMessage,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.4,
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
