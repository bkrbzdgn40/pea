import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_state_views.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/workout_presentation_formatter.dart';
import '../providers/session_repository_provider.dart';
import 'session_detail_screen.dart';

enum _HistoryMessage { requiresAnalysis, loadFailed, loadMoreFailed }

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
  _HistoryMessage? _errorMessage;
  _HistoryMessage? _emptyMessage;
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
        _emptyMessage = _HistoryMessage.requiresAnalysis;
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
        _errorMessage = _HistoryMessage.loadFailed;
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
        _errorMessage = _HistoryMessage.loadMoreFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AppScaffoldShell(
      title: localizations.sessionHistory,
      currentPage: AppDestination.sessionHistory,
      body: _buildBody(localizations),
    );
  }

  Widget _buildBody(AppLocalizations localizations) {
    if (_isInitialLoading) {
      return const AppLoadingView();
    }

    if (_errorMessage != null && _sessions.isEmpty) {
      return AppErrorView(
        icon: Icons.history_toggle_off_rounded,
        title: localizations.historyUnavailable,
        message: _historyMessage(localizations, _errorMessage!),
        actionLabel: localizations.retry,
        onAction: () => unawaited(_loadInitialSessions()),
      );
    }

    if (_sessions.isEmpty) {
      return AppEmptyView(
        centered: true,
        icon: Icons.history_rounded,
        title: localizations.noSessionsYet,
        message: _emptyMessage == null
            ? localizations.savedWorkoutsAppearHere
            : _historyMessage(localizations, _emptyMessage!),
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
                onTap: () async {
                  final deleted = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionDetailScreen(session: session),
                    ),
                  );
                  if (deleted == true && mounted) {
                    setState(() {
                      _sessions.removeWhere((item) => item.id == session.id);
                    });
                  }
                },
                child: _SessionCard(
                  session: session,
                  localizations: localizations,
                ),
              );
            },
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _historyMessage(localizations, _errorMessage!),
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
            label: Text(
              _isLoadingMore ? localizations.loading : localizations.loadMore,
            ),
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

String _historyMessage(
  AppLocalizations localizations,
  _HistoryMessage message,
) {
  return switch (message) {
    _HistoryMessage.requiresAnalysis => localizations.historyRequiresAnalysis,
    _HistoryMessage.loadFailed => localizations.historyLoadFailed,
    _HistoryMessage.loadMoreFailed => localizations.historyLoadMoreFailed,
  };
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.localizations});

  final WorkoutSession session;
  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    final metrics = session.isHoldSession
        ? <MapEntry<String, String>>[
            MapEntry(
              localizations.duration,
              WorkoutPresentationFormatter.duration(session.duration),
            ),
            MapEntry(
              localizations.totalHold,
              WorkoutPresentationFormatter.holdDuration(
                session.totalHoldSeconds,
              ),
            ),
            MapEntry(
              localizations.bestHold,
              WorkoutPresentationFormatter.holdDuration(
                session.bestHoldSeconds,
              ),
            ),
            MapEntry(
              localizations.interruptions,
              session.formBreakCount.toString(),
            ),
          ]
        : <MapEntry<String, String>>[
            MapEntry(
              localizations.duration,
              WorkoutPresentationFormatter.duration(session.duration),
            ),
            MapEntry(localizations.reps, session.totalReps.toString()),
            MapEntry(
              localizations.averageFormRangeScoreShort,
              WorkoutPresentationFormatter.roundedScore(session.averageScore),
            ),
            MapEntry(
              localizations.bestShort,
              WorkoutPresentationFormatter.roundedScore(session.bestScore),
            ),
            MapEntry(
              localizations.warnings,
              session.formWarningCount.toString(),
            ),
          ];

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  localizations.exerciseTitle(session.exerciseType),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                WorkoutPresentationFormatter.dateTime(session.startedAt),
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
