import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';
import '../theme/app_motion.dart';

/// Shared transition contract for all Material routes in the application.
///
/// The transition stays deliberately restrained so camera-first flows do not
/// feel delayed. System reduced-motion preferences remove the decorative
/// transition while preserving the route lifecycle itself.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder({this.preserveCupertinoGesture = false});

  final bool preserveCupertinoGesture;

  static const Offset _enterOffset = Offset(0.025, 0);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.prefersReducedMotion(context)) {
      return child;
    }

    if (preserveCupertinoGesture) {
      return const CupertinoPageTransitionsBuilder().buildTransitions<T>(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: AppMotionCurves.standard,
      reverseCurve: AppMotionCurves.emphasized,
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: _enterOffset,
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}
