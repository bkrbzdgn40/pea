import 'package:flutter/material.dart';

const Color liveHudAccent = Color(0xFF61E6BE);
const Color liveHudSurface = Color(0xD91A2026);
const Color liveHudSurfaceStrong = Color(0xE6171D23);
const Color liveHudMetricSurface = Color(0x8F1A2026);
const Color liveHudMetricSurfaceStrong = Color(0xA6171D23);

BoxDecoration liveHudSurfaceDecoration({
  required Color accentColor,
  required double radius,
  bool strong = false,
  Color? surfaceColor,
}) {
  return BoxDecoration(
    color: surfaceColor ?? (strong ? liveHudSurfaceStrong : liveHudSurface),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: accentColor.withValues(alpha: strong ? 0.48 : 0.28),
    ),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 7)),
    ],
  );
}

String sentenceCaseLiveMetricLabel(String value) {
  if (value.isEmpty) {
    return value;
  }
  final lower = value.toLowerCase();
  return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
}
