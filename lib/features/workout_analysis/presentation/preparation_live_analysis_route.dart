import 'package:flutter/material.dart';

import '../../../app/theme/app_design_tokens.dart';
import '../../../app/theme/app_motion.dart';

/// A short fade-only route for the preparation-to-live camera handoff.
///
/// Keeping the preparation route visible beneath the entering page preserves
/// the last camera texture during ownership transfer without adding the
/// horizontal movement used by standard application navigation.
class PreparationLiveAnalysisRoute<T> extends PageRouteBuilder<T> {
  PreparationLiveAnalysisRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: AppMotionDurations.fast,
        reverseTransitionDuration: AppMotionDurations.fast,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (AppMotion.prefersReducedMotion(context)) {
            return child;
          }

          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: AppMotionCurves.standard,
              reverseCurve: AppMotionCurves.emphasized,
            ),
            child: child,
          );
        },
      );
}
