import 'package:flutter/material.dart';

import '../../../../app/presentation/widgets/app_status_tone.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/workout_rep.dart';
import '../../domain/models/workout_session.dart';

enum SessionResultTone { excellent, strong, steady, focus, completed }

SessionResultTone sessionResultTone(WorkoutSession session) {
  if (session.isHoldSession) {
    if (session.totalHoldSeconds <= 0) return SessionResultTone.focus;
    if (session.formBreakCount == 0 && session.totalHoldSeconds >= 30) {
      return SessionResultTone.strong;
    }
    return SessionResultTone.completed;
  }

  if (session.averageScore <= 0) return SessionResultTone.completed;
  if (session.averageScore >= 90) return SessionResultTone.excellent;
  if (session.averageScore >= 80) return SessionResultTone.strong;
  if (session.averageScore >= 70) return SessionResultTone.steady;
  return SessionResultTone.focus;
}

extension SessionResultTonePresentation on SessionResultTone {
  AppStatusTone get statusTone {
    return switch (this) {
      SessionResultTone.excellent ||
      SessionResultTone.strong => AppStatusTone.success,
      SessionResultTone.steady => AppStatusTone.accent,
      SessionResultTone.focus => AppStatusTone.caution,
      SessionResultTone.completed => AppStatusTone.neutral,
    };
  }

  IconData get icon {
    return switch (this) {
      SessionResultTone.excellent => Icons.auto_awesome_rounded,
      SessionResultTone.strong => Icons.verified_rounded,
      SessionResultTone.steady => Icons.trending_up_rounded,
      SessionResultTone.focus => Icons.track_changes_rounded,
      SessionResultTone.completed => Icons.check_circle_outline_rounded,
    };
  }

  Color resolveColor(AppSemanticColors colors) {
    return statusTone.resolveColor(colors);
  }
}

AppStatusTone repStatusTone(WorkoutRep rep) {
  if (rep.isValidatedAsValid) return AppStatusTone.success;
  if (rep.isValidatedAsLowConfidence) return AppStatusTone.caution;
  if (rep.isValidatedAsInvalid) return AppStatusTone.invalid;
  return AppStatusTone.neutral;
}
