import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/app/theme/app_theme.dart';
import 'package:pose_estimation_app/features/auth/application/repositories/auth_repository.dart';
import 'package:pose_estimation_app/features/auth/domain/models/auth_user.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/repositories/session_repository.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';

class TestAuthRepository implements AuthRepository {
  const TestAuthRepository({this.currentUserId});

  @override
  final String? currentUserId;

  @override
  AuthUser? get currentUser => currentUserId == null
      ? null
      : AuthUser(
          uid: currentUserId!,
          email: null,
          displayName: null,
          isAnonymous: true,
        );

  @override
  Stream<AuthUser?> authStateChanges() => Stream<AuthUser?>.value(currentUser);

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteCurrentUser() async {}
}

class TestSessionRepository implements SessionRepository {
  TestSessionRepository({
    List<WorkoutSession> sessions = const <WorkoutSession>[],
    Map<String, WorkoutSession?> sessionById =
        const <String, WorkoutSession?>{},
    Map<String, List<WorkoutRep>> repsBySessionId =
        const <String, List<WorkoutRep>>{},
    this.listSessionsError,
    this.getSessionByIdError,
    this.listSessionRepsError,
    this.deleteSessionError,
    this.deleteAllSessionsError,
  }) : _sessions = List<WorkoutSession>.from(sessions),
       _sessionById = Map<String, WorkoutSession?>.from(sessionById),
       _repsBySessionId = Map<String, List<WorkoutRep>>.from(repsBySessionId);

  final List<WorkoutSession> _sessions;
  final Map<String, WorkoutSession?> _sessionById;
  final Map<String, List<WorkoutRep>> _repsBySessionId;
  final Object? listSessionsError;
  final Object? getSessionByIdError;
  final Object? listSessionRepsError;
  final Object? deleteSessionError;
  final Object? deleteAllSessionsError;
  final List<String> deletedSessionIds = <String>[];
  final List<String> deletedAllOwnerIds = <String>[];

  @override
  Future<void> saveSession(WorkoutSession session) async {
    _sessions.removeWhere((existing) => existing.id == session.id);
    _sessions.add(session);
    _sessionById[session.id] = session;
  }

  @override
  Future<WorkoutSession?> getSessionById({
    required String ownerId,
    required String sessionId,
  }) async {
    if (getSessionByIdError != null) {
      throw getSessionByIdError!;
    }

    if (_sessionById.containsKey(sessionId)) {
      return _sessionById[sessionId];
    }

    for (final session in _sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }

    return null;
  }

  @override
  Future<List<WorkoutRep>> listSessionReps({
    required String ownerId,
    required String sessionId,
  }) async {
    if (listSessionRepsError != null) {
      throw listSessionRepsError!;
    }

    final reps = _repsBySessionId[sessionId];
    if (reps != null) {
      return List<WorkoutRep>.unmodifiable(reps);
    }

    final session = _sessionById[sessionId];
    if (session?.reps != null) {
      return List<WorkoutRep>.unmodifiable(session!.reps!);
    }

    return const <WorkoutRep>[];
  }

  @override
  Future<List<WorkoutSession>> listSessions({
    required String ownerId,
    int limit = 20,
    String? exerciseType,
    WorkoutSession? startAfter,
  }) async {
    if (listSessionsError != null) {
      throw listSessionsError!;
    }

    var filtered = _sessions.where((session) => session.ownerId == ownerId);
    if (exerciseType != null) {
      filtered = filtered.where(
        (session) => session.exerciseType == exerciseType,
      );
    }

    final sessions = filtered.toList(growable: false);
    if (startAfter != null) {
      final startIndex = sessions.indexWhere(
        (session) => session.id == startAfter.id,
      );
      if (startIndex != -1 && startIndex + 1 < sessions.length) {
        return List<WorkoutSession>.unmodifiable(
          sessions.skip(startIndex + 1).take(limit),
        );
      }
      if (startIndex != -1) {
        return const <WorkoutSession>[];
      }
    }

    return List<WorkoutSession>.unmodifiable(sessions.take(limit));
  }

  @override
  Future<void> deleteSession({
    required String ownerId,
    required String sessionId,
  }) async {
    if (deleteSessionError != null) {
      throw deleteSessionError!;
    }
    deletedSessionIds.add(sessionId);
    _sessions.removeWhere(
      (session) => session.ownerId == ownerId && session.id == sessionId,
    );
    _sessionById.remove(sessionId);
    _repsBySessionId.remove(sessionId);
  }

  @override
  Future<void> deleteAllSessions({required String ownerId}) async {
    if (deleteAllSessionsError != null) {
      throw deleteAllSessionsError!;
    }
    deletedAllOwnerIds.add(ownerId);
    final sessionIds = _sessions
        .where((session) => session.ownerId == ownerId)
        .map((session) => session.id)
        .toList();
    _sessions.removeWhere((session) => session.ownerId == ownerId);
    for (final sessionId in sessionIds) {
      _sessionById.remove(sessionId);
      _repsBySessionId.remove(sessionId);
    }
  }
}

class RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    lastPushedRoute = route;
    super.didPush(route, previousRoute);
  }
}

Future<void> pumpTestApp(
  WidgetTester tester, {
  required Widget home,
  List<Override> overrides = const <Override>[],
  List<NavigatorObserver> navigatorObservers = const <NavigatorObserver>[],
  Locale? locale,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale ?? const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        navigatorObservers: navigatorObservers,
        home: home,
      ),
    ),
  );
}
