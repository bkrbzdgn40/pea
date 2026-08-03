import 'package:flutter/material.dart';

import '../../theme/app_semantic_colors.dart';

enum AppStatusTone { neutral, accent, success, caution, invalid, danger }

extension AppStatusTonePresentation on AppStatusTone {
  Color resolveColor(AppSemanticColors colors) {
    return switch (this) {
      AppStatusTone.neutral => colors.foregroundMuted,
      AppStatusTone.accent => colors.analysisAccent,
      AppStatusTone.success => colors.success,
      AppStatusTone.caution => colors.caution,
      AppStatusTone.invalid => colors.invalid,
      AppStatusTone.danger => colors.danger,
    };
  }

  IconData get defaultIcon {
    return switch (this) {
      AppStatusTone.neutral => Icons.remove_circle_outline_rounded,
      AppStatusTone.accent => Icons.auto_awesome_rounded,
      AppStatusTone.success => Icons.check_circle_outline_rounded,
      AppStatusTone.caution => Icons.warning_amber_rounded,
      AppStatusTone.invalid => Icons.cancel_outlined,
      AppStatusTone.danger => Icons.error_outline_rounded,
    };
  }
}
