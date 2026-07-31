import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/workout_session.dart';
import '../providers/session_repository_provider.dart';
import '../widgets/session_history_content.dart';
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
  static const String _allExercisesFilter = '__all_exercises__';

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
  String _selectedExerciseFilter = _allExercisesFilter;

  String? get _selectedExerciseType =>
      _selectedExerciseFilter == _allExercisesFilter
      ? null
      : _selectedExerciseFilter;

  bool get _hasExerciseFilter => _selectedExerciseType != null;

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
          .listSessions(
            ownerId: ownerId,
            limit: _pageSize,
            exerciseType: _selectedExerciseType,
          );
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
            exerciseType: _selectedExerciseType,
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

  void _selectExerciseFilter(String value) {
    if (value == _selectedExerciseFilter) return;
    setState(() {
      _selectedExerciseFilter = value;
    });
    unawaited(_loadInitialSessions());
  }

  void _clearExerciseFilter() {
    _selectExerciseFilter(_allExercisesFilter);
  }

  Future<void> _openSession(WorkoutSession session) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session)),
    );
    if (deleted == true && mounted) {
      setState(() {
        _sessions.removeWhere((item) => item.id == session.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AppScaffoldShell(
      title: localizations.sessionHistory,
      currentPage: AppDestination.sessionHistory,
      padding: EdgeInsets.zero,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppLayout.of(context, constraints: constraints);
          return Padding(
            padding: layout.pagePadding,
            child: _buildBody(localizations, layout),
          );
        },
      ),
    );
  }

  Widget _buildBody(AppLocalizations localizations, AppLayout layout) {
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
        title: _hasExerciseFilter
            ? localizations.noMatchingSessions
            : localizations.noSessionsYet,
        message: _hasExerciseFilter
            ? localizations.noMatchingSessionsDetail
            : _emptyMessage == null
            ? localizations.savedWorkoutsAppearHere
            : _historyMessage(localizations, _emptyMessage!),
        actionLabel: _hasExerciseFilter ? localizations.showAllExercises : null,
        onAction: _hasExerciseFilter ? _clearExerciseFilter : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SessionHistoryToolbar(
          layout: layout,
          sessionCount: _sessions.length,
          selectedExerciseFilter: _selectedExerciseFilter,
          allExercisesFilter: _allExercisesFilter,
          onExerciseSelected: _selectExerciseFilter,
        ),
        SizedBox(height: layout.sectionGap),
        Expanded(
          child: SessionHistoryCollection(
            layout: layout,
            sessions: _sessions,
            onOpenSession: (session) => unawaited(_openSession(session)),
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
