import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, this.label = '', this.value = ''});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with the production metric card design.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [Text(label), Text(value)],
    );
  }
}
