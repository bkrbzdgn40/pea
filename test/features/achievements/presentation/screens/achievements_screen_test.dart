import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/presentation/models/achievement.dart';
import 'package:pose_estimation_app/features/achievements/presentation/providers/achievements_provider.dart';
import 'package:pose_estimation_app/features/achievements/presentation/screens/achievements_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets(
    'shows the shared loading state while achievements are unresolved',
    (WidgetTester tester) async {
      final completer = Completer<AchievementsState>();

      await pumpTestApp(
        tester,
        home: const AchievementsScreen(),
        overrides: [
          achievementsProvider.overrideWith((ref) => completer.future),
        ],
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        const AchievementsState(
          source: AchievementsDataSource.real,
          achievements: <Achievement>[
            Achievement(
              id: 'first_analysis',
              title: 'Ilk Analiz',
              description: 'Ilk canli analiz oturumunu tamamladin.',
              isUnlocked: true,
              progress: 1,
              requirementText: '1 analiz tamamla',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Ilk Analiz'), findsOneWidget);
    },
  );

  testWidgets('shows the shared error state when achievements fail', (
    WidgetTester tester,
  ) async {
    final completer = Completer<AchievementsState>();

    await pumpTestApp(
      tester,
      home: const AchievementsScreen(),
      overrides: [achievementsProvider.overrideWith((ref) => completer.future)],
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.completeError(Exception('boom'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Başarılar yüklenemedi. Lütfen daha sonra tekrar dene.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
  });

  testWidgets('renders unlocked and locked achievement visual states', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const AchievementsScreen(),
      overrides: [
        achievementsProvider.overrideWith(
          (ref) => AchievementsState(
            source: AchievementsDataSource.real,
            achievements: const [
              Achievement(
                id: 'first_analysis',
                title: 'Ilk Analiz',
                description: 'Ilk canli analiz oturumunu tamamladin.',
                isUnlocked: true,
                progress: 1,
                requirementText: '1 analiz tamamla',
              ),
              Achievement(
                id: 'hundred_reps',
                title: '100 Tekrar',
                description: 'Toplam tekrar hacmini artir.',
                isUnlocked: false,
                progress: 0.4,
                requirementText: 'Toplam 100 tekrar tamamla',
              ),
            ],
          ),
        ),
      ],
    );
    await tester.pump();

    expect(find.text('Ilk Analiz'), findsOneWidget);
    expect(find.text('Açık'), findsOneWidget);
    expect(find.text('Kilitli'), findsOneWidget);
    expect(
      find.text('İlerlemeni ve açılan rozetleri burada göreceksin'),
      findsOneWidget,
    );
  });

  testWidgets('renders fallback achievements as the empty-state presentation', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const AchievementsScreen(),
      overrides: [
        achievementsProvider.overrideWith(
          (ref) => AchievementsState(
            source: AchievementsDataSource.empty,
            achievements: const [
              Achievement(
                id: 'demo_achievement',
                title: 'Demo rozet',
                description: 'Ornek rozet',
                isUnlocked: false,
                progress: 0.2,
                requirementText: '1 analiz tamamla',
              ),
            ],
          ),
        ),
      ],
    );
    await tester.pump();

    expect(
      find.text('İlk analizini tamamladığında rozetlerin burada görünür.'),
      findsOneWidget,
    );
    expect(find.text('Demo rozet'), findsNothing);
  });
}
