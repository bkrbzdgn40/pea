import 'package:flutter/material.dart';

class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({super.key, this.message = '', this.isVisible = false});

  final String message;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    // TODO: Replace with the production feedback banner design.
    return Text(message);
  }
}
