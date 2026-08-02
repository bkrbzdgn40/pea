import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../domain/models/session_report.dart';
import '../../domain/models/workout_rep.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/measurement_confidence_presentation_formatter.dart';
import '../formatters/workout_presentation_formatter.dart';
import '../mappers/session_report_ui_mapper.dart';
import '../providers/session_repository_provider.dart';

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SessionSummaryCard(session: _session, report: report),
            const SizedBox(height: 14),
            _OverviewCard(session: _session, report: report),
            const SizedBox(height: 14),
            _ReportSummaryCard(report: report),
            if (report.recommendations.isNotEmpty) ...[
              const SizedBox(height: 14),
              _RecommendationsCard(report: report),
            ],
            const SizedBox(height: 14),
            _RepDetailsCard(
              reps: _reps,
              exerciseId: _session.exerciseType,
              isLoading: _isLoadingRepDetails,
              hasLoadError: _repLoadFailed,
              onRetry: _loadSessionDetails,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              key: const ValueKey<String>('session-delete-button'),
              onPressed: _isDeleting ? null : _confirmAndDeleteSession,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              label: Text(
                _isDeleting
                    ? localizations.deleting
                    : localizations.deleteSession,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.greenAccent,
                ),
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
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
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
                padding: EdgeInsets.symmetric(vertical: 18),
                child: CircularProgressIndicator(color: Colors.greenAccent),
              ),
            )
          else if (!hasReps && hasLoadError)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.repDetailsLoadFailed,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => unawaited(onRetry()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: Text(localizations.retry),
                ),
              ],
            )
          else if (!hasReps)
            Text(
              localizations.noRepDetails,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.35,
              ),
            )
          else ...[
            if (hasLoadError) ...[
              Text(
                localizations.showingCachedRepDetails,
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
            ],
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reps!.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _RepTile(rep: reps![index], exerciseId: exerciseId);
              },
            ),
          ],
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _repStatusColor(rep).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _repStatusColor(rep).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  _repStatusLabel(localizations, rep),
                  style: TextStyle(
                    color: _repStatusColor(rep),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IssueChip extends StatelessWidget {
  const _IssueChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
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
              color: Colors.greenAccent,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
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

Color _repStatusColor(WorkoutRep rep) {
  return switch (rep.validationStatus) {
    'valid' => Colors.greenAccent,
    'low confidence' || 'lowConfidence' => Colors.amberAccent,
    'invalid' => Colors.redAccent,
    _ => Colors.white70,
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
