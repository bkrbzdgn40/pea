import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/how_to_use_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('shows only six compact onboarding cards without scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTestApp(tester, home: const HowToUseScreen());
    await tester.pump();
    await _finishEntranceAnimations(tester);

    expect(find.byKey(const ValueKey<String>('how-to-use-hero')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('how-to-use-select-exercise')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('how-to-use-test-camera')),
      findsNothing,
    );

    const expectedSteps = <(String, String)>[
      ('1', 'Egzersiz seç'),
      ('2', 'Telefonu yerleştir'),
      ('3', 'Kadraja gir'),
      ('4', 'Hazırlığı tamamla'),
      ('5', 'Analizi başlat'),
      ('6', 'Sonucu incele'),
    ];

    for (final step in expectedSteps) {
      expect(
        find.byKey(ValueKey<String>('how-to-use-step-${step.$1}')),
        findsOneWidget,
      );
      expect(find.text(step.$2), findsOneWidget);
      expect(
        find.byKey(ValueKey<String>('how-to-use-step-${step.$1}-details')),
        findsNothing,
      );

      final surface = find.byKey(
        ValueKey<String>('how-to-use-step-${step.$1}-surface'),
      );
      expect(tester.getSize(surface).height, greaterThanOrEqualTo(66));

      final numberBadge = find.byKey(
        ValueKey<String>('how-to-use-step-${step.$1}-number'),
      );
      final numberBadgeSize = tester.getSize(numberBadge);
      expect(numberBadgeSize.width, moreOrLessEquals(36, epsilon: 0.1));
      expect(numberBadgeSize.height, moreOrLessEquals(36, epsilon: 0.1));
    }

    final listView = find.byKey(const ValueKey<String>('how-to-use-scroll'));
    final scrollable = find.descendant(
      of: listView,
      matching: find.byType(Scrollable),
    );
    final scrollableState = tester.state<ScrollableState>(scrollable);
    final viewportRect = tester.getRect(listView);
    final firstCardRect = tester.getRect(
      find.byKey(const ValueKey<String>('how-to-use-step-1-surface')),
    );
    final lastCardRect = tester.getRect(
      find.byKey(const ValueKey<String>('how-to-use-step-6-surface')),
    );

    expect(scrollableState.position.maxScrollExtent, 0);
    expect(
      firstCardRect.top,
      moreOrLessEquals(viewportRect.top + 10, epsilon: 1),
    );
    expect(
      lastCardRect.bottom,
      moreOrLessEquals(viewportRect.bottom - 14, epsilon: 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expands a card downward and reveals the full explanation', (
    tester,
  ) async {
    await pumpTestApp(tester, home: const HowToUseScreen());
    await tester.pump();
    await _finishEntranceAnimations(tester);

    const stepId = '3';
    final toggle = find.byKey(
      ValueKey<String>('how-to-use-step-$stepId-header'),
    );

    expect(
      find.text(
        'Başından ayaklarına kadar kadrajda kal ve ışığın yeterli olduğundan emin ol.',
      ),
      findsNothing,
    );

    await tester.tap(toggle);
    await tester.pump();

    final details = find.byKey(
      ValueKey<String>('how-to-use-step-$stepId-details'),
    );
    expect(details, findsOneWidget);

    final bodyText = tester.widget<Text>(
      find.text(
        'Başından ayaklarına kadar kadrajda kal ve ışığın yeterli olduğundan emin ol.',
      ),
    );
    expect(bodyText.maxLines, isNull);
    expect(bodyText.overflow, isNull);

    await tester.pump(const Duration(milliseconds: 720));
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapses an expanded card when it is tapped again', (
    tester,
  ) async {
    await pumpTestApp(tester, home: const HowToUseScreen());
    await tester.pump();
    await _finishEntranceAnimations(tester);

    final toggle = find.byKey(
      const ValueKey<String>('how-to-use-step-1-header'),
    );
    final details = find.byKey(
      const ValueKey<String>('how-to-use-step-1-details'),
    );

    await tester.tap(toggle);
    await tester.pump(const Duration(milliseconds: 720));
    expect(details, findsOneWidget);

    await tester.ensureVisible(toggle);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump(const Duration(milliseconds: 720));
    expect(details, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to scrolling on short or large-text layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTestApp(
      tester,
      home: const MediaQuery(
        data: MediaQueryData(
          size: Size(320, 600),
          textScaler: TextScaler.linear(2),
        ),
        child: HowToUseScreen(),
      ),
    );
    await tester.pump();
    await _finishEntranceAnimations(tester);

    final scrollable = find.descendant(
      of: find.byKey(const ValueKey<String>('how-to-use-scroll')),
      matching: find.byType(Scrollable),
    );
    final scrollableState = tester.state<ScrollableState>(scrollable);

    expect(scrollableState.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _finishEntranceAnimations(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 720));
}
