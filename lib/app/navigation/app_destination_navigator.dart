import 'package:flutter/material.dart';

import 'app_destination.dart';

abstract final class AppDestinationNavigator {
  static void open(
    BuildContext context, {
    required AppDestination destination,
    required AppDestination? currentDestination,
  }) {
    final navigator = Navigator.of(context);
    navigator.pop();

    if (destination == currentDestination) {
      return;
    }

    if (destination == AppDestination.home) {
      navigator.pushNamedAndRemoveUntil<void>(
        destination.routeName,
        (_) => false,
      );
      return;
    }

    if (currentDestination == AppDestination.home) {
      navigator.pushNamed<void>(destination.routeName);
      return;
    }

    navigator.pushReplacementNamed<void, void>(destination.routeName);
  }
}
