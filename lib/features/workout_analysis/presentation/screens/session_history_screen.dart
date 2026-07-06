import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/workout_session.dart';
import '../providers/session_repository_provider.dart';
import 'session_detail_screen.dart';

class SessionHistoryScreen extends ConsumerStatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  ConsumerState<SessionHistoryScreen> createState() =>
      _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends ConsumerState<SessionHistoryScreen> {
  static const int _pageSize = 20;

  final List<WorkoutSession> _sessions = [];
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  String? _emptyMessage;
  ProviderSubscription<String?>? _userIdSubscription;
  String? _loadedOwnerId;
  String? _loadingOwnerId;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _userIdSubscription = ref.listenManual<String?>(currentUserIdProvider, (
      _,
      _,
    ) {
      final ownerId = _resolveOwnerId();
      if (ownerId == null ||
          ownerId == _loadedOwnerId ||
          ownerId == _loadingOwnerId) {
        return;
      }

      unawaited(_loadInitialSessions(ownerIdOverride: ownerId));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadInitialSessions());
    });
  }

  @override
  void dispose() {
    _userIdSubscription?.close();
    super.dispose();
  }

  String? _resolveOwnerId() {
    return ref.read(authRepositoryProvider).currentUserId ??
        ref.read(currentUserIdProvider);
  }

  Future<void> _loadInitialSessions({String? ownerIdOverride}) async {
    if (!mounted) return;

    final loadRequestId = ++_loadRequestId;
    final ownerId = ownerIdOverride ?? _resolveOwnerId();
    _loadingOwnerId = ownerId;

    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
      _emptyMessage = null;
    });

    if (ownerId == null) {
      if (!mounted || loadRequestId != _loadRequestId) return;

      _loadingOwnerId = null;
      _loadedOwnerId = null;
      setState(() {
        _sessions.clear();
        _hasMore = false;
        _isInitialLoading = false;
        _emptyMessage = 'Gecmis oturumlari gormek icin once bir analiz baslat.';
      });
      return;
    }

    try {
      final sessions = await ref
          .read(sessionRepositoryProvider)
          .listSessions(ownerId: ownerId, limit: _pageSize);
      if (!mounted || loadRequestId != _loadRequestId) return;

      _loadingOwnerId = null;
      _loadedOwnerId = ownerId;
      setState(() {
        _sessions
          ..clear()
          ..addAll(sessions);
        _hasMore = sessions.length == _pageSize;
        _isInitialLoading = false;
        _emptyMessage = null;
      });
    } catch (_) {
      if (!mounted || loadRequestId != _loadRequestId) return;

      _loadingOwnerId = null;
      setState(() {
        _sessions.clear();
        _hasMore = false;
        _isInitialLoading = false;
        _errorMessage = 'Gecmis oturumlar yuklenemedi. Lutfen tekrar dene.';
      });
    }
  }

  Future<void> _loadMoreSessions() async {
    if (_isLoadingMore || !_hasMore || _sessions.isEmpty) return;

    final ownerId = _resolveOwnerId();
    if (ownerId == null) return;

    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final sessions = await ref.read(sessionRepositoryProvider).listSessions(
        ownerId: ownerId,
        limit: _pageSize,
        startAfter: _sessions.last,
      );
      if (!mounted) return;

      setState(() {
        _sessions.addAll(sessions);
        _hasMore = sessions.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _errorMessage =
            'Daha fazla oturum yuklenemedi. Lutfen tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Gecmis Oturumlar',
      currentPage: AppDrawerPage.sessionHistory,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      );
    }

    if (_errorMessage != null && _sessions.isEmpty) {
      return _HistoryMessage(
        icon: Icons.history_toggle_off_rounded,
        title: 'Gecmis yuklenemedi',
        message: _errorMessage!,
        actionLabel: 'Tekrar Dene',
        onAction: () => unawaited(_loadInitialSessions()),
      );
    }

    if (_sessions.isEmpty) {
      return _HistoryMessage(
        icon: Icons.history_rounded,
        title: 'Henuz oturum yok',
        message: _emptyMessage ?? 'Kaydedilmis antrenmanlarin burada gorunecek.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _sessions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final session = _sessions[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionDetailScreen(session: session),
                    ),
                  );
                },
                child: _SessionCard(session: session),
              );
            },
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (_hasMore) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _isLoadingMore
                ? null
                : () => unawaited(_loadMoreSessions()),
            icon: _isLoadingMore
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: Text(_isLoadingMore ? 'Yukleniyor' : 'Daha Fazla Yukle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.greenAccent, size: 42),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 15,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final metrics = session.isHoldSession
        ? <MapEntry<String, String>>[
            MapEntry('Sure', _formatDuration(session.duration)),
            MapEntry('Toplam Hold', _formatHoldSeconds(session.totalHoldSeconds)),
            MapEntry('En Iyi Hold', _formatHoldSeconds(session.bestHoldSeconds)),
            MapEntry('Kesinti', session.formBreakCount.toString()),
          ]
        : <MapEntry<String, String>>[
            MapEntry('Sure', _formatDuration(session.duration)),
            MapEntry('Tekrar', session.totalReps.toString()),
            MapEntry('Ort. Skor', _formatScore(session.averageScore)),
            MapEntry('En Iyi', _formatScore(session.bestScore)),
            MapEntry('Uyari', session.formWarningCount.toString()),
          ];

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _exerciseTitle(session.exerciseType),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDateTime(session.startedAt),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 13,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metrics
                .map(
                  (entry) =>
                      _SessionMetric(label: entry.key, value: entry.value),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SessionMetric extends StatelessWidget {
  const _SessionMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _exerciseTitle(String exerciseType) {
  return switch (exerciseType) {
    'squat' => 'Squat',
    _ => exerciseType
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

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day.$month.$year $hour:$minute';
}
