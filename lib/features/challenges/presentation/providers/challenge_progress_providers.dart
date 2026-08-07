import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../application/repositories/challenge_progress_repository.dart';
import '../../infrastructure/repositories/firestore_challenge_progress_repository.dart';

final challengeProgressRepositoryProvider =
    Provider<ChallengeProgressRepository>((ref) {
      return FirestoreChallengeProgressRepository(
        ref.watch(firebaseFirestoreProvider),
      );
    });
