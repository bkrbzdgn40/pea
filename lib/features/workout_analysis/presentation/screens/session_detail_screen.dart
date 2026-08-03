import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_ui_primitives.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/session_report.dart';
import '../../domain/models/workout_rep.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/measurement_confidence_presentation_formatter.dart';
import '../formatters/workout_presentation_formatter.dart';
import '../mappers/session_report_ui_mapper.dart';
import '../providers/session_repository_provider.dart';
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
    final reps = _reps ?? const <WorkoutRep>[];
    final report = SessionReport.fromSession(session: _session, reps: reps);

    return AppScaffoldShell(
      title: localizations.sessionReport,
      showDrawer: false,
      padding: EdgeInsets.zero,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppLayout.of(context, constraints: constraints);
          return _buildContent(layout: layout, report: report);
        },
      ),
    );
  }

  Widget _buildContent({
    required AppLayout layout,
    required SessionReport report,
  }) {
    final useWideLayout =
        layout.viewportSize.width >= 760 && !layout.hasLargeText;

    if (!useWideLayout) {
      return SingleChildScrollView(
        key: const ValueKey<String>('session-detail-portrait-layout'),
        padding: layout.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._primaryContent(report),
            SizedBox(height: layout.panelGap),
            _buildRepDetails(),
            SizedBox(height: layout.panelGap),
            _buildDeleteAction(),
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
                  ..._primaryContent(report),
                  SizedBox(height: layout.panelGap),
                  _buildDeleteAction(),
                ],
              ),
            ),
          ),
          SizedBox(width: layout.panelGap),
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              key: const ValueKey<String>('session-detail-reps-scroll'),
              child: _buildRepDetails(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _primaryContent(SessionReport report) {
    return <Widget>[
      _SessionSummaryCard(session: _session, report: report),
      const SizedBox(height: AppSpacing.sm),
      _OverviewCard(session: _session, report: report),
      const SizedBox(height: AppSpacing.sm),
      _ReportSummaryCard(report: report),
      if (report.recommendations.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.sm),
        _RecommendationsCard(report: report),
      ],
    ];
  }

  Widget _buildRepDetails() {
    return _RepDetailsCard(
      reps: _reps,
      exerciseId: _session.exerciseType,
      isLoading: _isLoadingRepDetails,
      hasLoadError: _repLoadFailed,
      onRetry: _loadSessionDetails,
    );
  }

  Widget _buildDeleteAction() {
    final localizations = AppLocalizations.of(context);
    return AppButton(
      key: const ValueKey<String>('session-delete-button'),
      label: _isDeleting ? localizations.deleting : localizations.deleteSession,
      onPressed: _isDeleting ? null : _confirmAndDeleteSession,
      icon: Icons.delete_outline_rounded,
      variant: AppButtonVariant.danger,
      isLoading: _isDeleting,
      expand: true,
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

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({required this.session, required this.report});

  final WorkoutSession session;
  final SessionReport report;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final tone = sessionResultTone(session);
    final accent = tone.resolveColor(colors);
    final chips = <MapEntry<String, String>>[
      MapEntry(
        localizations.analysis,
        _analysisKindLabel(localizations, session.analysisKind),
      ),
      MapEntry(
        localizations.duration,
        WorkoutPresentationFormatter.duration(session.duration),
      ),
      MapEntry(
        report.isHoldSession
            ? localizations.totalHold
            : localizations.totalReps,
        report.isHoldSession
            ? WorkoutPresentationFormatter.holdDuration(report.totalHoldSeconds)
            : report.totalReps.toString(),
      ),
      if (!report.isHoldSession && report.hasScoreData)
        MapEntry(
          localizations.averageFormRangeScore,
          WorkoutPresentationFormatter.compactScore(report.averageScore),
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

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.session, required this.report});

  final WorkoutSession session;
  final SessionReport report;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final metrics = _overviewMetrics(
      localizations: localizations,
      session: session,
      report: report,
    );

    return _SectionCard(
      title: report.isHoldSession
          ? localizations.holdSummary
          : localizations.scoreView,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 10.0;
          final columnCount = constraints.maxWidth < 340 ? 1 : 2;
          final tileWidth =
              (constraints.maxWidth - spacing * (columnCount - 1)) /
              columnCount;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: metrics
                .map(
                  (metric) => SizedBox(
                    width: tileWidth,
                    child: _MetricTile(label: metric.key, value: metric.value),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({required this.report});

  final SessionReport report;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final issues = localizedSessionReportIssues(localizations, report);

    return _SectionCard(
      title: localizations.reportSummary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizedSessionReportSummary(localizations, report),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: issues
                  .map((issue) => _IssueChip(label: issue))
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationsCard extends StatelessWidget {
  const _RecommendationsCard({required this.report});

  final SessionReport report;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final recommendations = localizedSessionReportRecommendations(
      localizations,
      report,
    );

    return _SectionCard(
      title: localizations.recommendations,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: recommendations
            .map((recommendation) => _RecommendationRow(text: recommendation))
            .toList(growable: false),
      ),
    );
  }
}

class _RepDetailsCard extends StatelessWidget {
  const _RepDetailsCard({
    required this.reps,
    required this.exerciseId,
    required this.isLoading,
    required this.hasLoadError,
    required this.onRetry,
  });

  final List<WorkoutRep>? reps;
  final String exerciseId;
  final bool isLoading;
  final bool hasLoadError;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final hasReps = reps != null && reps!.isNotEmpty;

    return _SectionCard(
      title: localizations.repDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            ListView.builder(
              key: const ValueKey<String>('session-rep-timeline'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reps!.length,
              itemBuilder: (context, index) {
                return _RepTimelineItem(
                  rep: reps![index],
                  exerciseId: exerciseId,
                  isLast: index == reps!.length - 1,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RepTimelineItem extends StatelessWidget {
  const _RepTimelineItem({
    required this.rep,
    required this.exerciseId,
    required this.isLast,
  });

  final WorkoutRep rep;
  final String exerciseId;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final tone = repStatusTone(rep);
    final accent = tone.resolveColor(colors);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: AppOpacity.subtle),
                    border: Border.all(
                      color: accent.withValues(alpha: AppOpacity.strongBorder),
                    ),
                  ),
                  child: Text(
                    '${rep.repIndex}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: AppFontWeights.heavy,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: colors.outlineSubtle,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
              child: _RepTile(rep: rep, exerciseId: exerciseId),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepTile extends StatelessWidget {
  const _RepTile({required this.rep, required this.exerciseId});

  final WorkoutRep rep;
  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final detailMetrics = <MapEntry<String, String>>[
      MapEntry(localizations.status, _repStatusLabel(localizations, rep)),
      MapEntry(localizations.formRangeScore, _formatOptionalScore(rep.score)),
      MapEntry(
        localizations.measurementConfidence,
        MeasurementConfidencePresentationFormatter.percentage(
          localizations,
          rep.effectiveMeasurementConfidence?.combined,
        ),
      ),
      MapEntry(
        localizations.side,
        _formatSideLabel(localizations, rep.selectedSideLabel),
      ),
      MapEntry(
        localizations.primaryMetric,
        _formatOptionalMetric(rep.minPrimaryMetric),
      ),
      MapEntry(
        localizations.worstForm,
        _formatOptionalMetric(rep.worstFormMetric),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.attemptNumber(rep.repIndex),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppStatusChip(
                label: _repStatusLabel(localizations, rep),
                tone: repStatusTone(rep),
                showIcon: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: detailMetrics
                .map(
                  (metric) =>
                      _RepMetricPill(label: metric.key, value: metric.value),
                )
                .toList(growable: false),
          ),
          if (rep.primaryValidationReason != null) ...[
            const SizedBox(height: 10),
            Text(
              localizations.primaryIssue(
                _formatIssueLabel(localizations, rep.primaryValidationReason!),
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          if (rep.feedback != null && rep.feedback!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              localizations.feedbackLabel(
                localizeStoredWorkoutFeedback(
                  feedback: rep.feedback!,
                  exerciseId: exerciseId,
                  localizations: localizations,
                ),
              ),
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

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

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppMetricTile(
      label: label,
      value: value,
      tone: AppStatusTone.accent,
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

class _IssueChip extends StatelessWidget {
  const _IssueChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AppStatusChip(
      label: label,
      tone: AppStatusTone.danger,
      icon: Icons.report_problem_outlined,
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
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
      ),
    );
  }
}

class _RepMetricPill extends StatelessWidget {
  const _RepMetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.foregroundSubtle, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

List<MapEntry<String, String>> _overviewMetrics({
  required AppLocalizations localizations,
  required WorkoutSession session,
  required SessionReport report,
}) {
  if (report.isHoldSession) {
    return <MapEntry<String, String>>[
      MapEntry(
        localizations.duration,
        WorkoutPresentationFormatter.duration(session.duration),
      ),
      MapEntry(
        localizations.totalHold,
        WorkoutPresentationFormatter.holdDuration(report.totalHoldSeconds),
      ),
      MapEntry(
        localizations.bestHold,
        WorkoutPresentationFormatter.holdDuration(report.bestHoldSeconds),
      ),
      MapEntry(localizations.formBreaks, report.formBreakCount.toString()),
    ];
  }

  final metrics = <MapEntry<String, String>>[
    MapEntry(localizations.totalReps, report.totalReps.toString()),
    MapEntry(localizations.valid, report.validReps.toString()),
    if (report.lowConfidenceReps > 0)
      MapEntry(
        localizations.lowConfidence,
        report.lowConfidenceReps.toString(),
      ),
    MapEntry(localizations.invalid, report.invalidReps.toString()),
    if (report.unknownReps > 0)
      MapEntry(localizations.uncertain, report.unknownReps.toString()),
    MapEntry(
      localizations.averageMeasurementConfidence,
      MeasurementConfidencePresentationFormatter.percentage(
        localizations,
        MeasurementConfidencePresentationFormatter.averageKnown(
          session.reps ?? const [],
        ),
      ),
    ),
    MapEntry(
      localizations.averageFormRangeScore,
      report.hasScoreData
          ? WorkoutPresentationFormatter.compactScore(report.averageScore)
          : '--',
    ),
    MapEntry(
      localizations.bestFormRangeScore,
      report.hasScoreData
          ? WorkoutPresentationFormatter.compactScore(report.bestScore)
          : '--',
    ),
    MapEntry(
      localizations.lowestFormRangeScore,
      report.hasScoreData
          ? WorkoutPresentationFormatter.compactScore(report.worstScore)
          : '--',
    ),
    MapEntry(localizations.formWarnings, report.formWarningCount.toString()),
  ];

  if (report.formViolationCount > 0) {
    metrics.add(
      MapEntry(
        localizations.formViolations,
        report.formViolationCount.toString(),
      ),
    );
  }
  if (report.coverageDropCount > 0) {
    metrics.add(
      MapEntry(
        localizations.visibilityLoss,
        report.coverageDropCount.toString(),
      ),
    );
  }
  if (report.sideSwitchCount > 0) {
    metrics.add(
      MapEntry(localizations.sideChanges, report.sideSwitchCount.toString()),
    );
  }

  return metrics;
}

String _repStatusLabel(AppLocalizations localizations, WorkoutRep rep) {
  return switch (rep.validationStatus) {
    'valid' => localizations.valid,
    'low confidence' || 'lowConfidence' => localizations.lowConfidence,
    'invalid' => localizations.invalid,
    _ => localizations.uncertain,
  };
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

String _analysisKindLabel(AppLocalizations localizations, String analysisKind) {
  return switch (analysisKind) {
    'hold' => 'Hold',
    'rangeRep' => localizations.rangeRep,
    _ => analysisKind,
  };
}

String _formatOptionalScore(double? score) {
  if (score == null) {
    return '--';
  }

  return WorkoutPresentationFormatter.compactScore(score);
}

String _formatOptionalMetric(double? value) {
  if (value == null) {
    return '--';
  }

  return value.toStringAsFixed(1);
}

String _formatSideLabel(AppLocalizations localizations, String? value) {
  return switch (value) {
    'left' => localizations.left,
    'right' => localizations.right,
    null => '--',
    _ => value,
  };
}

String _formatIssueLabel(AppLocalizations localizations, String value) {
  switch (value) {
    case 'insufficient rom':
      return localizations.insufficientRangeOfMotion;
    case 'excessive descent speed':
    case 'excessive ascent speed':
    case 'excessive rep speed':
      return localizations.tempoMeasurementUnavailable;
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
