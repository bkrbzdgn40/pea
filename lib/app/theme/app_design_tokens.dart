import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color scaffoldBackground = Colors.black;
  static const Color appBarBackground = Colors.black;
  static const Color primarySurface = Color(0xFF151515);
  static const Color secondarySurface = Color(0xFF111111);
  static const Color elevatedSurface = Color(0xFF1A2026);
  static const Color strongSurface = Color(0xFF171D23);
  static const Color surfaceBorder = Colors.white12;
  static const Color subtleBorder = Colors.white10;
  static const Color primaryForeground = Colors.white;
  static const Color secondaryForeground = Colors.white70;
  static const Color mutedForeground = Colors.white54;
  static const Color disabledForeground = Colors.white38;
  static const Color accent = Colors.greenAccent;
  static const Color analysisAccent = Color(0xFF61E6BE);
  static const Color success = Color(0xFF61E6BE);
  static const Color caution = Colors.amberAccent;
  static const Color invalid = Colors.orangeAccent;
  static const Color danger = Colors.redAccent;
}

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 12, 20, 24);
  static const double listGap = sm;
  static const EdgeInsets surfacePadding = EdgeInsets.all(md);
  static const EdgeInsets headerSurfacePadding = EdgeInsets.all(18);
}

class AppRadii {
  const AppRadii._();

  static const double small = 12;
  static const double compact = 14;
  static const double surface = 16;
  static const double large = 24;
  static const double pill = 999;
}

class AppElevation {
  const AppElevation._();

  static const double flat = 0;
  static const double raised = 2;
  static const double overlay = 8;
}

class AppOpacity {
  const AppOpacity._();

  static const double subtle = 0.10;
  static const double border = 0.28;
  static const double strongBorder = 0.48;
  static const double disabled = 0.38;
  static const double scrim = 0.68;
}

class AppFontWeights {
  const AppFontWeights._();

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight heavy = FontWeight.w800;
}

class AppMotionDurations {
  const AppMotionDurations._();

  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration emphasized = Duration(milliseconds: 360);
  static const Duration celebration = Duration(milliseconds: 560);
  static const Duration deliberate = Duration(milliseconds: 720);
}

class AppMotionCurves {
  const AppMotionCurves._();

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
}

class AppTouchTargets {
  const AppTouchTargets._();

  static const double minimum = 48;
}

class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> hud = <BoxShadow>[
    BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 7)),
  ];
}
