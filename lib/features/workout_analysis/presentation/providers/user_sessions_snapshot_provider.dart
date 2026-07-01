import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/workout_session.dart';
import 'session_repository_provider.dart';

final userSessionsSnapshotProvider =
    FutureProvider<UserSessionsSnapshot>((ref) async {
      final repositoryUserId = ref.read(authRepositoryProvider).currentUserId;
      final providerUserId = ref.watch(currentUserIdProvider);
      final ownerId = repositoryUserId ?? providerUserId;

      if (ownerId == null) {
        return const UserSessionsSnapshot(
          sessions: [],
          source: UserSessionsSnapshotSource.noUser,
        );
      }

      try {
        final sessions = await ref
            .read(sessionRepositoryProvider)
            .listSessions(ownerId: ownerId, limit: 100);

        if (sessions.isEmpty) {
          return const UserSessionsSnapshot(
            sessions: [],
            source: UserSessionsSnapshotSource.empty,
          );
        }

        return UserSessionsSnapshot(
          sessions: sessions,
          source: UserSessionsSnapshotSource.real,
        );
      } catch (_) {
        return const UserSessionsSnapshot(
          sessions: [],
          source: UserSessionsSnapshotSource.error,
        );
      }
    });

class UserSessionsSnapshot {
  const UserSessionsSnapshot({
    required this.sessions,
    required this.source,
  });

  final List<WorkoutSession> sessions;
  final UserSessionsSnapshotSource source;

  bool get isFallback => source != UserSessionsSnapshotSource.real;

  String get sourceMessage {
    return switch (source) {
      UserSessionsSnapshotSource.real => 'Gerçek oturum verisi',
      UserSessionsSnapshotSource.noUser =>
        'Kullanıcı verisi yok, örnek gösterim',
      UserSessionsSnapshotSource.empty => 'Henüz oturum yok, örnek gösterim',
      UserSessionsSnapshotSource.error => 'Veri alınamadı, örnek gösterim',
    };
  }
}

enum UserSessionsSnapshotSource {
  real,
  noUser,
  empty,
  error,
}
