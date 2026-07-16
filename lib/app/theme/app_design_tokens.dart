import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color scaffoldBackground = Colors.black;
  static const Color appBarBackground = Colors.black;
  static const Color primarySurface = Color(0xFF151515);
  static const Color secondarySurface = Color(0xFF111111);
  static const Color surfaceBorder = Colors.white12;
  static const Color subtleBorder = Colors.white10;
  static const Color primaryForeground = Colors.white;
  static const Color accent = Colors.greenAccent;
}

class AppSpacing {
  const AppSpacing._();

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 12, 20, 24);
  static const double listGap = 12;
  static const EdgeInsets surfacePadding = EdgeInsets.all(16);
  static const EdgeInsets headerSurfacePadding = EdgeInsets.all(18);
}

class AppRadii {
  const AppRadii._();

  static const double small = 12;
  static const double surface = 16;
  static const double compact = 14;
  static const double pill = 999;
}
