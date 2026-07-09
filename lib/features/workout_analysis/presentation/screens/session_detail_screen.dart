import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../domain/models/session_report.dart';
import '../../domain/models/workout_rep.dart';
import '../../domain/models/workout_session.dart';
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
  String? _repLoadError;

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
      _repLoadError = null;
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
        _repLoadError = 'Tekrar detayları yüklenemedi. Lütfen tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reps = _reps ?? const <WorkoutRep>[];
    final report = SessionReport.fromSession(session: _session, reps: reps);

    return AppScaffoldShell(
      title: 'Oturum Raporu',
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
              isLoading: _isLoadingRepDetails,
              errorMessage: _repLoadError,
              onRetry: _loadSessionDetails,
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
    final chips = <MapEntry<String, String>>[
      MapEntry('Analiz', _analysisKindLabel(session.analysisKind)),
      MapEntry('Süre', _formatDuration(session.duration)),
      MapEntry(
        report.isHoldSession ? 'Toplam Hold' : 'Toplam Tekrar',
        report.isHoldSession
            ? _formatHoldSeconds(report.totalHoldSeconds)
            : report.totalReps.toString(),
      ),
      if (!report.isHoldSession && report.hasScoreData)
        MapEntry('Ortalama Skor', _formatScore(report.averageScore)),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
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
                      _exerciseTitle(session.exerciseType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatDateTime(session.startedAt),
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
    final metrics = _overviewMetrics(session: session, report: report);

    return _SectionCard(
      title: report.isHoldSession ? 'Hold Özeti' : 'Skor Görünümü',
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
    return _SectionCard(
      title: 'Rapor Özeti',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.summaryMessage,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (report.topIssues.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: report.topIssues
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
    return _SectionCard(
      title: 'Öneriler',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: report.recommendations
            .map((recommendation) => _RecommendationRow(text: recommendation))
            .toList(growable: false),
      ),
    );
  }
}

class _RepDetailsCard extends StatelessWidget {
  const _RepDetailsCard({
    required this.reps,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final List<WorkoutRep>? reps;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final hasReps = reps != null && reps!.isNotEmpty;

    return _SectionCard(
      title: 'Tekrar Detayları',
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
          else if (!hasReps && errorMessage != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => unawaited(onRetry()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            )
          else if (!hasReps)
            const Text(
              'Bu oturumda tekrar detayları kaydedilmemiş. Eski oturumlarda yalnızca özet veriler bulunabilir.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.35,
              ),
            )
          else ...[
            if (errorMessage != null) ...[
              const Text(
                'Güncel detaylar alınamadı; eldeki kayıt gösteriliyor.',
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
                return _RepTile(rep: reps![index]);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RepTile extends StatelessWidget {
  const _RepTile({required this.rep});

  final WorkoutRep rep;

  @override
  Widget build(BuildContext context) {
    final detailMetrics = <MapEntry<String, String>>[
      MapEntry('Durum', _repStatusLabel(rep)),
      MapEntry('Skor', _formatOptionalScore(rep.score)),
      MapEntry('Süre', _formatRepDuration(rep)),
      MapEntry('Taraf', _formatSideLabel(rep.selectedSideLabel)),
      MapEntry('Birincil Metrik', _formatOptionalMetric(rep.minPrimaryMetric)),
      MapEntry('En Kötü Form', _formatOptionalMetric(rep.worstFormMetric)),
      MapEntry('İniş / Çıkış', _formatRepTempo(rep)),
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
                  'Tekrar ${rep.repIndex}',
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
                  _repStatusLabel(rep),
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
              'Birincil sorun: ${_formatIssueLabel(rep.primaryValidationReason!)}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          if (rep.feedback != null && rep.feedback!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Feedback: ${rep.feedback!}',
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
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
  required WorkoutSession session,
  required SessionReport report,
}) {
  if (report.isHoldSession) {
    return <MapEntry<String, String>>[
      MapEntry('Süre', _formatDuration(session.duration)),
      MapEntry('Toplam Hold', _formatHoldSeconds(report.totalHoldSeconds)),
      MapEntry('En İyi Hold', _formatHoldSeconds(report.bestHoldSeconds)),
      MapEntry('Form Kesintisi', report.formBreakCount.toString()),
    ];
  }

  final metrics = <MapEntry<String, String>>[
    MapEntry('Toplam Tekrar', report.totalReps.toString()),
    MapEntry('Geçerli', report.validReps.toString()),
    MapEntry('Geçersiz', report.invalidReps.toString()),
    if (report.unknownReps > 0)
      MapEntry('Belirsiz', report.unknownReps.toString()),
    MapEntry(
      'Ortalama Skor',
      report.hasScoreData ? _formatScore(report.averageScore) : '--',
    ),
    MapEntry(
      'En İyi Skor',
      report.hasScoreData ? _formatScore(report.bestScore) : '--',
    ),
    MapEntry(
      'En Düşük Skor',
      report.hasScoreData ? _formatScore(report.worstScore) : '--',
    ),
    MapEntry('Form Uyarısı', report.formWarningCount.toString()),
  ];

  if (report.formViolationCount > 0) {
    metrics.add(MapEntry('Form İhlali', report.formViolationCount.toString()));
  }
  if (report.coverageDropCount > 0) {
    metrics.add(
      MapEntry('Görünürlük Kaybı', report.coverageDropCount.toString()),
    );
  }
  if (report.sideSwitchCount > 0) {
    metrics.add(MapEntry('Taraf Değişimi', report.sideSwitchCount.toString()));
  }

  return metrics;
}

String _repStatusLabel(WorkoutRep rep) {
  return switch (rep.validationStatus) {
    'valid' => 'Geçerli',
    'low confidence' => 'Düşük Güven',
    'invalid' => 'Geçersiz',
    _ => 'Belirsiz',
  };
}

Color _repStatusColor(WorkoutRep rep) {
  return switch (rep.validationStatus) {
    'valid' => Colors.greenAccent,
    'low confidence' => Colors.amberAccent,
    'invalid' => Colors.redAccent,
    _ => Colors.white70,
  };
}

String _analysisKindLabel(String analysisKind) {
  return switch (analysisKind) {
    'hold' => 'Hold',
    'rangeRep' => 'Range Rep',
    _ => analysisKind,
  };
}

String _exerciseTitle(String exerciseType) {
  return switch (exerciseType) {
    'squat' => 'Squat',
    'plank' => 'Plank',
    _ =>
      exerciseType
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' '),
  };
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  return '$minutes:$seconds';
}

String _formatHoldSeconds(double seconds) {
  return _formatDuration(Duration(seconds: seconds.round()));
}

String _formatScore(double score) {
  return score.toStringAsFixed(score.truncateToDouble() == score ? 0 : 1);
}

String _formatOptionalScore(double? score) {
  if (score == null) {
    return '--';
  }

  return _formatScore(score);
}

String _formatOptionalMetric(double? value) {
  if (value == null) {
    return '--';
  }

  return value.toStringAsFixed(1);
}

String _formatRepDuration(WorkoutRep rep) {
  final duration = rep.observedDuration;
  if (duration == null) {
    return '--';
  }

  return _formatDuration(duration);
}

String _formatRepTempo(WorkoutRep rep) {
  final descent = rep.descentMillis == null ? '--' : '${rep.descentMillis} ms';
  final ascent = rep.ascentMillis == null ? '--' : '${rep.ascentMillis} ms';

  return '$descent / $ascent';
}

String _formatSideLabel(String? value) {
  return switch (value) {
    'left' => 'Sol',
    'right' => 'Sağ',
    null => '--',
    _ => value,
  };
}

String _formatIssueLabel(String value) {
  switch (value) {
    case 'insufficient rom':
      return 'Yetersiz hareket açıklığı';
    case 'excessive descent speed':
      return 'İniş çok hızlı';
    case 'excessive ascent speed':
      return 'Çıkış çok hızlı';
    case 'persistent form break':
      return 'Kalıcı form bozulması';
    case 'coverage loss':
      return 'Görünürlük kaybı';
    case 'side switch during rep':
      return 'Tekrar içinde taraf değişimi';
    case 'incomplete phase':
      return 'Eksik faz tamamlanması';
    default:
      return value;
  }
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day.$month.$year $hour:$minute';
}
