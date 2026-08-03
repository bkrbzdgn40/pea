import 'package:flutter/material.dart';

import 'app_design_tokens.dart';

class AppMotion {
  const AppMotion._();

  static bool prefersReducedMotion(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return false;
    }
    return mediaQuery.disableAnimations || mediaQuery.accessibleNavigation;
  }

  static Duration resolveDuration(
    BuildContext context,
    Duration requestedDuration,
  ) {
    return prefersReducedMotion(context)
        ? AppMotionDurations.instant
        : requestedDuration;
  }

  static Curve resolveCurve(BuildContext context, Curve requestedCurve) {
    return prefersReducedMotion(context) ? Curves.linear : requestedCurve;
  }
}
