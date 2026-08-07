import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/domain/achievement_catalog.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_visibility.dart';

void main() {
  test(
    'v1 catalog contains eleven unique achievements without score chasing',
    () {
      final ids = AchievementCatalog.all.map((item) => item.id).toList();

      expect(AchievementCatalog.all, hasLength(11));
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, isNot(contains('score_90_plus')));
      expect(ids, isNot(contains('hundred_reps')));
      expect(ids, contains('first_reliable_analysis'));
      expect(ids, contains('rhythm_30_days'));
    },
  );

  test('only exotic achievements are hidden', () {
    final hidden = AchievementCatalog.all
        .where((item) => item.visibility == AchievementVisibility.hidden)
        .map((item) => item.id)
        .toSet();

    expect(hidden, {'return_after_14_days', 'rhythm_30_days', 'golden_week'});
  });
}
