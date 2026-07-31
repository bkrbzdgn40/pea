import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared viewport classes used by the presentation layer.
///
/// A layout class describes the available canvas, not a named device model.
/// This keeps split-screen, text scaling, and unusual aspect ratios from being
/// forced through phone/tablet guesses.
enum AppLayoutSize {
  compactPortrait,
  standardPortrait,
  compactLandscape,
  standardLandscape,
  expanded,
}

class AppLayoutBreakpoints {
  const AppLayoutBreakpoints._();

  static const double compactPortraitWidth = 390;
  static const double compactLandscapeHeight = 360;
  static const double expandedShortestSide = 600;

  static const double largeTextScale = 1.3;
}

@immutable
class AppLayout {
  const AppLayout._({
    required this.viewportSize,
    required this.size,
    required this.textScaleFactor,
    required this.viewPadding,
  });

  factory AppLayout.fromMediaQuery(MediaQueryData mediaQuery) {
    return AppLayout.fromSize(
      mediaQuery.size,
      textScaleFactor: mediaQuery.textScaler.scale(1),
      viewPadding: mediaQuery.viewPadding,
    );
  }

  factory AppLayout.fromConstraints(
    BoxConstraints constraints, {
    required MediaQueryData mediaQuery,
  }) {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : mediaQuery.size.width;
    final height = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : mediaQuery.size.height;

    return AppLayout.fromSize(
      Size(width, height),
      textScaleFactor: mediaQuery.textScaler.scale(1),
      viewPadding: mediaQuery.viewPadding,
    );
  }

  factory AppLayout.fromSize(
    Size viewportSize, {
    double textScaleFactor = 1,
    EdgeInsets viewPadding = EdgeInsets.zero,
  }) {
    assert(viewportSize.width >= 0);
    assert(viewportSize.height >= 0);
    assert(textScaleFactor > 0);

    return AppLayout._(
      viewportSize: viewportSize,
      size: classify(viewportSize),
      textScaleFactor: textScaleFactor,
      viewPadding: viewPadding,
    );
  }

  factory AppLayout.of(BuildContext context, {BoxConstraints? constraints}) {
    final mediaQuery = MediaQuery.of(context);
    if (constraints == null) {
      return AppLayout.fromMediaQuery(mediaQuery);
    }

    return AppLayout.fromConstraints(constraints, mediaQuery: mediaQuery);
  }

  final Size viewportSize;
  final AppLayoutSize size;
  final double textScaleFactor;
  final EdgeInsets viewPadding;

  static AppLayoutSize classify(Size viewportSize) {
    final shortestSide = math.min(viewportSize.width, viewportSize.height);
    if (shortestSide >= AppLayoutBreakpoints.expandedShortestSide) {
      return AppLayoutSize.expanded;
    }

    final isLandscape = viewportSize.width > viewportSize.height;
    if (isLandscape) {
      return viewportSize.height < AppLayoutBreakpoints.compactLandscapeHeight
          ? AppLayoutSize.compactLandscape
          : AppLayoutSize.standardLandscape;
    }

    return viewportSize.width < AppLayoutBreakpoints.compactPortraitWidth
        ? AppLayoutSize.compactPortrait
        : AppLayoutSize.standardPortrait;
  }

  bool get isLandscape => viewportSize.width > viewportSize.height;

  bool get isPortrait => !isLandscape;

  bool get isExpanded => size == AppLayoutSize.expanded;

  bool get isCompact => switch (size) {
    AppLayoutSize.compactPortrait || AppLayoutSize.compactLandscape => true,
    AppLayoutSize.standardPortrait ||
    AppLayoutSize.standardLandscape ||
    AppLayoutSize.expanded => false,
  };

  bool get hasLargeText =>
      textScaleFactor >= AppLayoutBreakpoints.largeTextScale;

  /// Default page padding for non-camera screens.
  EdgeInsets get pagePadding => switch (size) {
    AppLayoutSize.compactPortrait => const EdgeInsets.fromLTRB(16, 10, 16, 20),
    AppLayoutSize.standardPortrait => const EdgeInsets.fromLTRB(20, 12, 20, 24),
    AppLayoutSize.compactLandscape => const EdgeInsets.fromLTRB(12, 8, 12, 12),
    AppLayoutSize.standardLandscape => const EdgeInsets.fromLTRB(
      16,
      10,
      16,
      16,
    ),
    AppLayoutSize.expanded => const EdgeInsets.fromLTRB(24, 16, 24, 28),
  };

  /// Tighter outer padding for camera-first screens.
  EdgeInsets get cameraPadding => switch (size) {
    AppLayoutSize.compactPortrait => const EdgeInsets.fromLTRB(12, 8, 12, 12),
    AppLayoutSize.standardPortrait => const EdgeInsets.fromLTRB(16, 8, 16, 16),
    AppLayoutSize.compactLandscape => const EdgeInsets.fromLTRB(12, 8, 12, 12),
    AppLayoutSize.standardLandscape => const EdgeInsets.fromLTRB(
      16,
      10,
      16,
      16,
    ),
    AppLayoutSize.expanded => const EdgeInsets.fromLTRB(24, 16, 24, 24),
  };

  double get sectionGap => switch (size) {
    AppLayoutSize.compactPortrait || AppLayoutSize.compactLandscape => 10,
    AppLayoutSize.standardPortrait || AppLayoutSize.standardLandscape => 12,
    AppLayoutSize.expanded => 16,
  };

  double get panelGap => switch (size) {
    AppLayoutSize.compactPortrait || AppLayoutSize.compactLandscape => 12,
    AppLayoutSize.standardPortrait || AppLayoutSize.standardLandscape => 16,
    AppLayoutSize.expanded => 20,
  };
}
