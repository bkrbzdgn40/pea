import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../application/outbox/achievement_event_outbox.dart';
import '../../application/repositories/achievement_event_repository.dart';
import '../../infrastructure/local/shared_preferences_achievement_event_outbox.dart';
import '../../infrastructure/repositories/firestore_achievement_event_repository.dart';

final achievementEventOutboxProvider = Provider<AchievementEventOutbox>((ref) {
  return const SharedPreferencesAchievementEventOutbox();
});

final achievementEventRepositoryProvider = Provider<AchievementEventRepository>(
  (ref) {
    return FirestoreAchievementEventRepository(
      ref.watch(firebaseFirestoreProvider),
    );
  },
);
