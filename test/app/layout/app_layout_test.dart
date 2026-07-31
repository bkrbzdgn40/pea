import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/layout/app_layout.dart';

void main() {
  group('AppLayout', () {
    test(
      'classifies phone and expanded viewport profiles by available size',
      () {
        expect(
          AppLayout.classify(const Size(320, 568)),
          AppLayoutSize.compactPortrait,
        );
        expect(
          AppLayout.classify(const Size(390, 844)),
          AppLayoutSize.standardPortrait,
        );
        expect(
          AppLayout.classify(const Size(430, 932)),
          AppLayoutSize.standardPortrait,
        );
        expect(
          AppLayout.classify(const Size(568, 320)),
          AppLayoutSize.compactLandscape,
        );
        expect(
          AppLayout.classify(const Size(844, 390)),
          AppLayoutSize.standardLandscape,
        );
        expect(
          AppLayout.classify(const Size(932, 430)),
          AppLayoutSize.standardLandscape,
        );
        expect(
          AppLayout.classify(const Size(768, 1024)),
          AppLayoutSize.expanded,
        );
        expect(
          AppLayout.classify(const Size(1024, 768)),
          AppLayoutSize.expanded,
        );
      },
    );

    test('uses bounded constraints instead of assuming the full viewport', () {
      final mediaQuery = MediaQueryData(
        size: const Size(1024, 768),
        textScaler: const TextScaler.linear(1.5),
      );
      final layout = AppLayout.fromConstraints(
        const BoxConstraints(maxWidth: 320, maxHeight: 568),
        mediaQuery: mediaQuery,
      );

      expect(layout.viewportSize, const Size(320, 568));
      expect(layout.size, AppLayoutSize.compactPortrait);
      expect(layout.textScaleFactor, 1.5);
    });

    test('keeps orientation and text scaling as independent layout inputs', () {
      final layout = AppLayout.fromSize(
        const Size(844, 390),
        textScaleFactor: 2,
        viewPadding: const EdgeInsets.only(left: 24),
      );

      expect(layout.isLandscape, isTrue);
      expect(layout.isPortrait, isFalse);
      expect(layout.hasLargeText, isTrue);
      expect(layout.viewPadding.left, 24);
      expect(layout.size, AppLayoutSize.standardLandscape);
    });

    test(
      'provides denser phone padding without shrinking expanded layouts',
      () {
        final compactLandscape = AppLayout.fromSize(const Size(568, 320));
        final expanded = AppLayout.fromSize(const Size(1024, 768));

        expect(compactLandscape.pagePadding.horizontal, 24);
        expect(compactLandscape.panelGap, 12);
        expect(expanded.pagePadding.horizontal, 48);
        expect(expanded.panelGap, 20);
      },
    );
  });
}
