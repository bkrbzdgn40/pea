import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../application/repositories/reward_ledger_repository.dart';
import '../../infrastructure/repositories/firestore_reward_ledger_repository.dart';

final rewardLedgerRepositoryProvider = Provider<RewardLedgerRepository>((ref) {
  return FirestoreRewardLedgerRepository(ref.watch(firebaseFirestoreProvider));
});
