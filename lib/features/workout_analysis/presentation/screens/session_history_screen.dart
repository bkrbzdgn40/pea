import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/workout_session.dart';
import '../providers/session_repository_provider.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadInitialSessions());
    });
  }

  Future<void> _loadInitialSessions() async {
    if (!mounted) return;

    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
      _emptyMessage = null;
    });

    final ownerId = ref.read(currentUserIdProvider);
    if (ownerId == null) {
      if (!mounted) return;

      setState(() {
        _sessions.clear();
        _hasMore = false;
        _isInitialLoading = false;
        _emptyMessage = 'Geçmiş oturumları görmek için önce bir analiz başlat.';
      });
      return;
    }

    try {
      final sessions = await ref
          .read(sessionRepositoryProvider)
          .listSessions(ownerId: ownerId, limit: _pageSize);
      if (!mounted) return;

      setState(() {
        _sessions
          ..clear()
          ..addAll(sessions);
        _hasMore = sessions.length == _pageSize;
        _isInitialLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _sessions.clear();
        _hasMore = false;
        _isInitialLoading = false;
        _errorMessage = 'Geçmiş oturumlar yüklenemedi. Lütfen tekrar dene.';
      });
    }
  }

  Future<void> _loadMoreSessions() async {
    if (_isLoadingMore || !_hasMore || _sessions.isEmpty) return;

    final ownerId = ref.read(currentUserIdProvider);
    if (ownerId == null) return;

    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final sessions = await ref
          .read(sessionRepositoryProvider)
          .listSessions(
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
        _errorMessage = 'Daha fazla oturum yüklenemedi. Lütfen tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Geçmiş Oturumlar'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: _buildBody(),
        ),
      ),
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
        title: 'Geçmiş yüklenemedi',
        message: _errorMessage!,
        actionLabel: 'Tekrar Dene',
        onAction: () => unawaited(_loadInitialSessions()),
      );
    }

    if (_sessions.isEmpty) {
      return _HistoryMessage(
        icon: Icons.history_rounded,
        title: 'Henüz oturum yok',
        message:
            _emptyMessage ?? 'Kaydedilmiş antrenmanların burada görünecek.',
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
              return _SessionCard(session: _sessions[index]);
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
            label: Text(_isLoadingMore ? 'Yükleniyor' : 'Daha Fazla Yükle'),
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
            children: [
              _SessionMetric(
                label: 'Süre',
                value: _formatDuration(session.duration),
              ),
              _SessionMetric(
                label: 'Tekrar',
                value: session.totalReps.toString(),
              ),
              _SessionMetric(
                label: 'Ort. Skor',
                value: _formatScore(session.averageScore),
              ),
              _SessionMetric(
                label: 'En İyi',
                value: _formatScore(session.bestScore),
              ),
              _SessionMetric(
                label: 'Uyarı',
                value: session.formWarningCount.toString(),
              ),
            ],
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
