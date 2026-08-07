import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/features/rewards/presentation/widgets/reward_marks.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/medal_tier.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('achievement badge exposes one concise image semantic', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpTestApp(
        tester,
        home: const Scaffold(
          body: Center(
            child: AchievementBadgeMark(
              achievementId: 'first_reliable_analysis',
              accent: AppColors.achievementTrust,
              secret: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Güvenilir Başlangıç başarım rozeti'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('gold medal exposes tier semantics and paints without errors', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpTestApp(
        tester,
        home: const Scaffold(
          body: Center(child: MedalBadgeMark(tier: MedalTier.gold)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Altın madalya'), findsOneWidget);
      expectNoPresentationExceptions(tester);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'reward reveal resolves immediately when animations are disabled',
    (tester) async {
      await pumpTestApp(
        tester,
        configuration: const PresentationTestConfiguration(
          disableAnimations: true,
        ),
        home: const Scaffold(
          body: Center(
            child: AchievementBadgeMark(
              achievementId: 'exercise_explorer_3',
              accent: AppColors.achievementExplore,
              secret: false,
              emphasized: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, 1);
      expectNoPresentationExceptions(tester);
    },
  );
}
