import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
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
    _reps = widget.session.reps;
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
          ? nextSession.reps
          : List<WorkoutRep>.unmodifiable(reps);

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
        _repLoadError = 'Tekrar detaylari yuklenemedi. Lutfen tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Oturum Detayi',
      showDrawer: false,
      padding: EdgeInsets.zero,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SessionSummaryCard(session: _session),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                final columnCount = constraints.maxWidth < 340 ? 1 : 2;
                final tileWidth =
                    (constraints.maxWidth - spacing * (columnCount - 1)) /
                    columnCount;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _detailMetrics(_session)
                      .map(
                        (metric) => SizedBox(
                          width: tileWidth,
                          child: _MetricTile(
                            label: metric.key,
                            value: metric.value,
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
            const SizedBox(height: 14),
            _RepDetailsCard(
              reps: _reps,
              isLoading: _isLoadingRepDetails,
              errorMessage: _repLoadError,
              onRetry: _loadSessionDetails,
            ),
            const SizedBox(height: 14),
            _RecommendationCard(session: _session),
          ],
        ),
      ),
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
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
          Text(
            _summaryLine(session),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.3,
            ),
          ),
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
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
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
          const Text(
            'Tekrar Detaylari',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: CircularProgressIndicator(color: Colors.greenAccent),
              ),
            )
          else if (errorMessage != null)
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
          else if (reps == null || reps!.isEmpty)
            const Text(
              'Bu oturumda tekrar detaylari kaydedilmemis.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.35,
              ),
            )
          else
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
      ),
    );
  }
}

class _RepTile extends StatelessWidget {
  const _RepTile({required this.rep});

  final WorkoutRep rep;

  @override
  Widget build(BuildContext context) {
    final status = _repStatusLabel(rep);
    final statusColor = _repStatusColor(rep);
    final detailMetrics = <MapEntry<String, String>>[
      MapEntry('Skor', _formatOptionalScore(rep.score)),
      MapEntry('Sure', _formatRepDuration(rep)),
      MapEntry('Min Metric', _formatOptionalMetric(rep.minPrimaryMetric)),
      MapEntry('Worst Form', _formatOptionalMetric(rep.worstFormMetric)),
      MapEntry('Taraf', rep.selectedSideLabel ?? '--'),
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
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
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
          if (rep.feedback != null && rep.feedback!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Feedback: ${rep.feedback!}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          if (rep.primaryValidationReason != null) ...[
            const SizedBox(height: 6),
            Text(
              'Neden: ${rep.primaryValidationReason!}',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
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

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.session});

  final WorkoutSession session;

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
          const Text(
            'Oneri Ozeti',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _recommendationFor(session),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

List<MapEntry<String, String>> _detailMetrics(WorkoutSession session) {
  if (session.isHoldSession) {
    return <MapEntry<String, String>>[
      MapEntry('Sure', _formatDuration(session.duration)),
      MapEntry('Toplam Hold', _formatHoldSeconds(session.totalHoldSeconds)),
      MapEntry('En Iyi Hold', _formatHoldSeconds(session.bestHoldSeconds)),
      MapEntry('Form Kesintisi', session.formBreakCount.toString()),
    ];
  }

  return <MapEntry<String, String>>[
    MapEntry('Sure', _formatDuration(session.duration)),
    MapEntry('Toplam Tekrar', session.totalReps.toString()),
    MapEntry('Gecerli Tekrar', session.validReps.toString()),
    MapEntry('Gecersiz Tekrar', session.invalidReps.toString()),
    MapEntry('Ortalama Skor', _formatScore(session.averageScore)),
    MapEntry('En Iyi Skor', _formatScore(session.bestScore)),
    MapEntry('En Dusuk Skor', _formatScore(session.worstScore)),
    MapEntry('Form Uyarisi', session.formWarningCount.toString()),
  ];
}

String _summaryLine(WorkoutSession session) {
  if (session.isHoldSession) {
    return 'Toplam hold ${_formatHoldSeconds(session.totalHoldSeconds)} • '
        'En iyi hold ${_formatHoldSeconds(session.bestHoldSeconds)}';
  }

  return '${session.totalReps} tekrar • '
      'Ortalama skor ${_formatScore(session.averageScore)}';
}

String _recommendationFor(WorkoutSession session) {
  if (session.isHoldSession) {
    if (session.formBreakCount >= 3) {
      return 'Formunu biraz daha sabit tutmaya odaklan. Kisa ama temiz hold setleri iyi bir sonraki adim olur.';
    }

    if (session.bestHoldSeconds >= 30) {
      return 'Tutus suresi iyi gorunuyor. Ayni kaliteyi koruyarak sureyi kademeli artirabilirsin.';
    }

    if (session.totalHoldSeconds < 15) {
      return 'Biraz daha uzun ve kontrollu hold denemeleri faydali olabilir.';
    }

    return 'Dengeli bir hold oturumu gorunuyor. Siradaki sette ayni sabitligi korumaya odaklanabilirsin.';
  }

  if (session.formWarningCount >= 3) {
    return 'Form kontrolune biraz daha odaklan. Uyari sayisi yuksektiginde daha yavas ve kontrollu tekrarlar faydali olabilir.';
  }

  if (session.averageScore >= 85) {
    return 'Tempo ve form dengesi iyi gorunuyor. Ayni kaliteyi koruyarak set suresini kademeli artirabilirsin.';
  }

  if (session.totalReps < 5) {
    return 'Biraz daha uzun setlerle devam edebilirsin. Oncelik yine kontrollu hareket kalitesi olsun.';
  }

  return 'Dengeli bir oturum gorunuyor. Bir sonraki sette ayni formu korumaya odaklanabilirsin.';
}

String _repStatusLabel(WorkoutRep rep) {
  return switch (rep.validationStatus) {
    'valid' => 'Gecerli',
    'low confidence' => 'Dusuk Guven',
    'invalid' => 'Gecersiz',
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

String _exerciseTitle(String exerciseType) {
  return switch (exerciseType) {
    'squat' => 'Squat',
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
  return score.round().toString();
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

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day.$month.$year $hour:$minute';
}
