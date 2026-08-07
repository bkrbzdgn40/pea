import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_ui_primitives.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../../achievements/presentation/providers/achievements_provider.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../rewards/presentation/providers/reward_runtime_providers.dart';
import '../../domain/models/session_report.dart';
import '../../domain/models/workout_rep.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/session_measurement_evidence_presenter.dart';
import '../formatters/workout_presentation_formatter.dart';
import '../mappers/session_report_ui_mapper.dart';
import '../providers/session_repository_provider.dart';
import '../providers/user_sessions_snapshot_provider.dart';
import '../widgets/session_measurement_evidence_notice.dart';
import '../widgets/session_result_visual.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({super.key, required this.session});

  final WorkoutSession session;

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  late WorkoutSession _session;
  List<WorkoutRep>? _reps;
  bool _isLoadingRepDetails = true;
  bool _repLoadFailed = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _reps = _sortedReps(widget.session.reps);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadSessionDetails());
    });
  }

  Future<void> _loadSessionDetails() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingRepDetails = true;
      _repLoadFailed = false;
    });

    try {
      final repository = ref.read(sessionRepositoryProvider);
      final refreshedSession = await repository.getSessionById(
        ownerId: _session.ownerId,
        sessionId: _session.id,
      );
      final reps = await repository.listSessionReps(
        ownerId: _session.ownerId,
        sessionId: _session.id,
      );
      if (!mounted) {
        return;
      }

      final nextSession = refreshedSession ?? _session;
      final nextReps = reps.isEmpty
          ? _sortedReps(nextSession.reps)
          : _sortedReps(reps);

      setState(() {
        _session = nextSession.copyWith(reps: nextReps);
        _reps = nextReps;
        _isLoadingRepDetails = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingRepDetails = false;
        _repLoadFailed = true;
      });
    }
  }

  Future<void> _confirmAndDeleteSession() async {
    if (_isDeleting) {
      return;
    }

    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.deleteSessionTitle),
        content: Text(localizations.deleteSessionMessage),
        actions: [
          TextButton(
            key: const ValueKey<String>('session-delete-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            key: const ValueKey<String>('session-delete-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .deleteSession(ownerId: _session.ownerId, sessionId: _session.id);
      try {
        await ref
            .read(rewardRuntimeServiceProvider)
            .removeSessionProgress(
              ownerId: _session.ownerId,
              sessionId: _session.id,
            );
      } catch (error, stackTrace) {
        developer.log(
          'Session deleted but reward progress cleanup was deferred.',
          name: 'rewards.runtime.delete',
          error: error,
          stackTrace: stackTrace,
        );
      }
      ref.invalidate(userSessionsSnapshotProvider);
      ref.invalidate(challengeGoalsProvider);
      ref.invalidate(achievementsProvider);
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.sessionDeleteFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final reps = _reps ?? const <WorkoutRep>[];
    final report = SessionReport.fromSession(session: _session, reps: reps);
    final viewData = _SessionDetailViewData.fromReport(
      report: report,
      reps: reps,
    );

    return AppScaffoldShell(
      title: localizations.sessionReport,
      showDrawer: false,
      actions: <Widget>[
        if (_isDeleting)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          PopupMenuButton<String>(
            key: const ValueKey<String>('session-actions-menu'),
            tooltip: localizations.sessionActions,
            onSelected: (value) {
              if (value == 'delete') {
                unawaited(_confirmAndDeleteSession());
              }
            },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                key: const ValueKey<String>('session-delete-menu-item'),
                value: 'delete',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.delete_outline_rounded, color: colors.danger),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      localizations.deleteSession,
                      style: TextStyle(color: colors.danger),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
      padding: EdgeInsets.zero,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppLayout.of(context, constraints: constraints);
          return _buildContent(
            layout: layout,
            report: report,
            viewData: viewData,
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required AppLayout layout,
    required SessionReport report,
    required _SessionDetailViewData viewData,
  }) {
    final useWideLayout =
        layout.viewportSize.width >= 760 &&
        !layout.hasLargeText &&
        !report.isHoldSession;
    final measurementWarning = _buildMeasurementWarning();

    if (!useWideLayout) {
      return SingleChildScrollView(
        key: const ValueKey<String>('session-detail-portrait-layout'),
        padding: layout.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._primaryContent(report, viewData),
            if (measurementWarning != null) ...[
              SizedBox(height: layout.panelGap),
              measurementWarning,
            ],
            if (!report.isHoldSession) ...[
              SizedBox(height: layout.panelGap),
              _buildRepReview(),
            ],
          ],
        ),
      );
    }

    return Padding(
      key: const ValueKey<String>('session-detail-wide-layout'),
      padding: layout.pagePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              key: const ValueKey<String>('session-detail-primary-scroll'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._primaryContent(report, viewData),
                  if (measurementWarning != null) ...[
                    SizedBox(height: layout.panelGap),
                    measurementWarning,
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: layout.panelGap),
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              key: const ValueKey<String>('session-detail-reps-scroll'),
              child: _buildRepReview(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _primaryContent(
    SessionReport report,
    _SessionDetailViewData viewData,
  ) {
    return <Widget>[
      _SessionSummaryCard(
        session: _session,
        report: report,
        viewData: viewData,
      ),
      const SizedBox(height: AppSpacing.sm),
      _PrimaryResultCard(report: report, viewData: viewData),
      const SizedBox(height: AppSpacing.sm),
      _PrimaryRecommendationCard(report: report),
    ];
  }

  Widget? _buildMeasurementWarning() {
    if (!SessionMeasurementEvidencePresenter.shouldShowWarning(_session)) {
      return null;
    }

    return AppSurfaceCard(
      key: const ValueKey<String>('session-detail-measurement-warning-card'),
      variant: AppSurfaceVariant.strong,
      child: SessionMeasurementEvidenceNotice(
        key: const ValueKey<String>('session-detail-measurement-warning'),
        session: _session,
      ),
    );
  }

  Widget _buildRepReview() {
    return _SessionRepReviewCard(
      exerciseId: _session.exerciseType,
      reps: _reps,
      isLoading: _isLoadingRepDetails,
      hasLoadError: _repLoadFailed,
      onRetry: _loadSessionDetails,
    );
  }

  List<WorkoutRep>? _sortedReps(List<WorkoutRep>? reps) {
    if (reps == null || reps.isEmpty) {
      return reps;
    }

    return List<WorkoutRep>.unmodifiable(
      reps.toList()
        ..sort((left, right) => left.repIndex.compareTo(right.repIndex)),
    );
  }
}

class _SessionDetailViewData {
  const _SessionDetailViewData({
    required this.cleanCount,
    required this.reviewCount,
  });

  factory _SessionDetailViewData.fromReport({
    required SessionReport report,
    required List<WorkoutRep> reps,
  }) {
    if (report.isHoldSession) {
      return const _SessionDetailViewData(cleanCount: 0, reviewCount: 0);
    }

    if (reps.isEmpty) {
      final reviewCount = report.lowConfidenceReps + report.unknownReps;
      return _SessionDetailViewData(
        cleanCount: _nonNegative(report.totalReps - reviewCount),
        reviewCount: reviewCount,
      );
    }

    final countedReps = reps
        .where((rep) => !rep.isValidatedAsInvalid)
        .toList(growable: false);
    final countedReviewCount = countedReps.where(_repNeedsReview).length;
    final summaryReviewCount = report.lowConfidenceReps + report.unknownReps;
    final reviewCount = countedReviewCount > summaryReviewCount
        ? countedReviewCount
        : summaryReviewCount;

    return _SessionDetailViewData(
      cleanCount: _nonNegative(report.totalReps - reviewCount),
      reviewCount: reviewCount,
    );
  }

  final int cleanCount;
  final int reviewCount;
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({
    required this.session,
    required this.report,
    required this.viewData,
  });

  final WorkoutSession session;
  final SessionReport report;
  final _SessionDetailViewData viewData;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final tone = sessionResultTone(session);
    final accent = tone.resolveColor(colors);
    final chips = report.isHoldSession
        ? <MapEntry<String, String>>[
            MapEntry(
              localizations.duration,
              WorkoutPresentationFormatter.duration(session.duration),
            ),
            MapEntry(
              localizations.totalHold,
              WorkoutPresentationFormatter.holdDuration(
                report.totalHoldSeconds,
              ),
            ),
            if (report.formBreakCount > 0)
              MapEntry(
                localizations.formBreaks,
                report.formBreakCount.toString(),
              ),
          ]
        : <MapEntry<String, String>>[
            MapEntry(localizations.countedReps, report.totalReps.toString()),
            MapEntry(localizations.cleanReps, viewData.cleanCount.toString()),
            if (viewData.reviewCount > 0)
              MapEntry(
                localizations.repsToReview,
                viewData.reviewCount.toString(),
              ),
            MapEntry(
              localizations.duration,
              WorkoutPresentationFormatter.duration(session.duration),
            ),
          ];

    return AppSurfaceCard(
      key: const ValueKey<String>('session-detail-hero'),
      padding: const EdgeInsets.all(18),
      variant: AppSurfaceVariant.strong,
      color: Color.alphaBlend(
        accent.withValues(alpha: 0.055),
        colors.surfaceStrong,
      ),
      borderColor: accent.withValues(alpha: AppOpacity.strongBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: AppOpacity.subtle),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accent.withValues(alpha: AppOpacity.border),
                  ),
                ),
                child: Icon(tone.icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.exerciseTitle(session.exerciseType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      WorkoutPresentationFormatter.dateTime(session.startedAt),
                      style: TextStyle(
                        color: colors.foregroundMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppStatusChip(
                      label: _sessionResultLabel(localizations, tone),
                      tone: tone.statusTone,
                      icon: tone.icon,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map((chip) => _SummaryChip(label: chip.key, value: chip.value))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _PrimaryResultCard extends StatelessWidget {
  const _PrimaryResultCard({required this.report, required this.viewData});

  final SessionReport report;
  final _SessionDetailViewData viewData;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final isHold = report.isHoldSession;
    final hasScore = !isHold && report.hasScoreData;
    final value = isHold
        ? WorkoutPresentationFormatter.holdDuration(report.bestHoldSeconds)
        : hasScore
        ? WorkoutPresentationFormatter.compactScore(report.averageScore)
        : report.totalReps.toString();
    final label = isHold
        ? localizations.bestHold
        : hasScore
        ? localizations.movementQuality
        : localizations.countedReps;

    return _SectionCard(
      key: const ValueKey<String>('session-detail-primary-result'),
      title: localizations.summaryHighlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: colors.analysisAccent,
              fontSize: 34,
              fontWeight: AppFontWeights.heavy,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.foregroundMuted,
              fontWeight: AppFontWeights.heavy,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _localizedPrimarySummary(localizations, report, viewData),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.foregroundMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryRecommendationCard extends StatelessWidget {
  const _PrimaryRecommendationCard({required this.report});

  final SessionReport report;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final recommendations = localizedSessionReportRecommendations(
      localizations,
      report,
    );
    final recommendation = recommendations.isEmpty
        ? localizations.summaryMaintainControl
        : recommendations.first;

    return _SectionCard(
      key: const ValueKey<String>('session-detail-primary-recommendation'),
      title: localizations.summaryNextFocus,
      child: _RecommendationRow(text: recommendation),
    );
  }
}

class _SessionRepReviewCard extends StatelessWidget {
  const _SessionRepReviewCard({
    required this.exerciseId,
    required this.reps,
    required this.isLoading,
    required this.hasLoadError,
    required this.onRetry,
  });

  final String exerciseId;
  final List<WorkoutRep>? reps;
  final bool isLoading;
  final bool hasLoadError;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final hasReps = reps != null && reps!.isNotEmpty;

    return _SectionCard(
      key: const ValueKey<String>('session-detail-rep-review'),
      title: localizations.repDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            )
          else if (!hasReps && hasLoadError)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFeedbackBanner(
                  message: localizations.repDetailsLoadFailed,
                  tone: AppStatusTone.caution,
                  icon: Icons.cloud_off_rounded,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: localizations.retry,
                  onPressed: () => unawaited(onRetry()),
                  icon: Icons.refresh_rounded,
                  variant: AppButtonVariant.outline,
                  expand: true,
                ),
              ],
            )
          else if (!hasReps)
            AppFeedbackBanner(
              message: localizations.noRepDetails,
              tone: AppStatusTone.neutral,
              icon: Icons.format_list_numbered_rounded,
            )
          else ...[
            if (hasLoadError) ...[
              AppFeedbackBanner(
                message: localizations.showingCachedRepDetails,
                tone: AppStatusTone.caution,
                icon: Icons.offline_bolt_outlined,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            ListView.separated(
              key: const ValueKey<String>('session-rep-details'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reps!.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: 40, color: colors.outlineSubtle),
              itemBuilder: (context, index) =>
                  _RepDetailCard(rep: reps![index], exerciseId: exerciseId),
            ),
          ],
        ],
      ),
    );
  }
}

class _RepDetailCard extends StatelessWidget {
  const _RepDetailCard({required this.rep, required this.exerciseId});

  final WorkoutRep rep;
  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final tone = _repDisplayTone(rep);
    final accent = tone.resolveColor(colors);
    final needsReview = _repNeedsReview(rep);
    final issue = needsReview
        ? _primaryUserFacingIssue(localizations, rep)
        : null;
    final feedback =
        !needsReview || rep.feedback == null || rep.feedback!.trim().isEmpty
        ? null
        : localizeStoredWorkoutFeedback(
            feedback: rep.feedback!,
            exerciseId: exerciseId,
            localizations: localizations,
          );
    final title = rep.isValidatedAsInvalid
        ? localizations.attemptNumber(rep.repIndex)
        : localizations.repNumber(rep.repIndex);

    return Padding(
      key: ValueKey<String>('session-rep-detail-${rep.repIndex}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: needsReview
                  ? accent.withValues(alpha: AppOpacity.subtle)
                  : colors.surfaceMuted,
            ),
            child: Text(
              '${rep.repIndex}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: needsReview ? accent : colors.foregroundMuted,
                fontWeight: AppFontWeights.heavy,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.foreground,
                          fontWeight: AppFontWeights.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: _RepStatusIndicator(
                        label: _repDisplayStatusLabel(localizations, rep),
                        tone: tone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _RepMetricStrip(rep: rep),
                if (issue != null || feedback != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: accent, width: 2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (issue != null)
                          Text(
                            localizations.repIssue(issue),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colors.foregroundMuted,
                                  height: 1.35,
                                  fontWeight: AppFontWeights.medium,
                                ),
                          ),
                        if (feedback != null) ...[
                          if (issue != null)
                            const SizedBox(height: AppSpacing.xxs),
                          Text(
                            localizations.feedbackLabel(feedback),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colors.foregroundSubtle,
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RepStatusIndicator extends StatelessWidget {
  const _RepStatusIndicator({required this.label, required this.tone});

  final String label;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final accent = tone.resolveColor(colors);
    final icon = switch (tone) {
      AppStatusTone.danger => Icons.close_rounded,
      AppStatusTone.caution => Icons.priority_high_rounded,
      _ => Icons.check_rounded,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(icon, size: 17, color: accent),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: AppFontWeights.semibold,
            ),
          ),
        ),
      ],
    );
  }
}

class _RepMetricStrip extends StatelessWidget {
  const _RepMetricStrip({required this.rep});

  final WorkoutRep rep;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return Row(
      key: ValueKey<String>('session-rep-metrics-${rep.repIndex}'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _RepMetricCell(
            label: localizations.repQuality,
            value: _formatRepScore(rep),
          ),
        ),
        Container(
          width: 1,
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          color: colors.outlineSubtle,
        ),
        Expanded(
          child: _RepMetricCell(
            label: localizations.repTempo,
            value: _formatRepTempo(localizations, rep),
          ),
        ),
      ],
    );
  }
}

class _RepMetricCell extends StatelessWidget {
  const _RepMetricCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Semantics(
      label: '$label: $value',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
              height: 1.05,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.foregroundSubtle,
              fontWeight: AppFontWeights.semibold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      variant: AppSurfaceVariant.strong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppStatusChip(
      label: '$label: $value',
      tone: AppStatusTone.neutral,
      showIcon: false,
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.subdirectory_arrow_right_rounded,
            color: AppColors.analysisAccent,
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

bool _repNeedsReview(WorkoutRep rep) {
  return !rep.isValidatedAsValid ||
      _userFacingValidationReasons(rep).isNotEmpty ||
      rep.hadFormViolation ||
      rep.hadCoverageDrop ||
      rep.switchedSideDuringRep;
}

List<String> _userFacingValidationReasons(WorkoutRep rep) {
  return rep.validationReasons
      .where((reason) => !_isQuarantinedTempoReason(reason))
      .toList(growable: false);
}

bool _isQuarantinedTempoReason(String reason) {
  return reason == 'excessive descent speed' ||
      reason == 'excessiveDescentSpeed' ||
      reason == 'excessive ascent speed' ||
      reason == 'excessiveAscentSpeed' ||
      reason == 'excessive rep speed' ||
      reason == 'excessiveRepSpeed';
}

String? _primaryUserFacingIssue(
  AppLocalizations localizations,
  WorkoutRep rep,
) {
  final reasons = _userFacingValidationReasons(rep);
  if (reasons.isNotEmpty) {
    return _formatIssueLabel(localizations, reasons.first);
  }
  if (rep.hadCoverageDrop) {
    return localizations.coverageLoss;
  }
  if (rep.switchedSideDuringRep) {
    return localizations.sideSwitchDuringRep;
  }
  if (rep.hadFormViolation) {
    return localizations.persistentFormBreak;
  }
  return null;
}

AppStatusTone _repDisplayTone(WorkoutRep rep) {
  if (rep.isValidatedAsInvalid) {
    return AppStatusTone.danger;
  }
  if (_repNeedsReview(rep)) {
    return AppStatusTone.caution;
  }
  return AppStatusTone.success;
}

String _repDisplayStatusLabel(AppLocalizations localizations, WorkoutRep rep) {
  if (rep.isValidatedAsInvalid) {
    return localizations.notCounted;
  }
  if (_repNeedsReview(rep)) {
    return localizations.repsToReview;
  }
  return localizations.cleanReps;
}

String _formatRepScore(WorkoutRep rep) {
  final score = rep.score;
  return score == null ? '—' : WorkoutPresentationFormatter.compactScore(score);
}

String _formatRepTempo(AppLocalizations localizations, WorkoutRep rep) {
  final duration = rep.observedDuration;
  if (duration == null || duration.inMilliseconds <= 0) {
    return '—';
  }

  final seconds = duration.inMilliseconds / 1000;
  var value = seconds.toStringAsFixed(
    seconds == seconds.roundToDouble() ? 0 : 1,
  );
  if (localizations.isTurkish) {
    value = value.replaceAll('.', ',');
  }
  return localizations.repTempoValue(value);
}

String _localizedPrimarySummary(
  AppLocalizations localizations,
  SessionReport report,
  _SessionDetailViewData viewData,
) {
  if (report.isHoldSession || !report.hasRepDetails || report.totalReps <= 0) {
    return localizedSessionReportSummary(localizations, report);
  }

  final issues = localizedSessionReportIssues(localizations, report);
  return localizations.sessionReportRangeSummary(
    totalReps: report.totalReps,
    cleanReps: viewData.cleanCount,
    reviewReps: viewData.reviewCount,
    invalidReps: report.invalidReps,
    topIssue: issues.isEmpty ? null : issues.first,
  );
}

String _sessionResultLabel(
  AppLocalizations localizations,
  SessionResultTone tone,
) {
  return switch (tone) {
    SessionResultTone.excellent => localizations.summaryResultExcellent,
    SessionResultTone.strong => localizations.summaryResultStrong,
    SessionResultTone.steady => localizations.summaryResultSteady,
    SessionResultTone.focus => localizations.summaryResultNeedsFocus,
    SessionResultTone.completed => localizations.summaryResultCompleted,
  };
}

String _formatIssueLabel(AppLocalizations localizations, String value) {
  switch (value) {
    case 'insufficient rom':
      return localizations.insufficientRangeOfMotion;
    case 'persistent form break':
      return localizations.persistentFormBreak;
    case 'coverage loss':
      return localizations.coverageLoss;
    case 'side switch during rep':
      return localizations.sideSwitchDuringRep;
    case 'incomplete phase':
      return localizations.incompletePhase;
    default:
      return value;
  }
}

int _nonNegative(int value) => value < 0 ? 0 : value;
