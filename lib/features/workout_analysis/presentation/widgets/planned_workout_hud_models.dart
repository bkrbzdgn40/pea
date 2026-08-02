import 'package:flutter/material.dart';

enum PlannedWorkoutHudTone { positive, caution, invalid, muted }

class PlannedWorkoutLiveHudData {
  const PlannedWorkoutLiveHudData({
    required this.exerciseTitle,
    required this.primaryLabel,
    required this.primaryValue,
    required this.primaryIcon,
    required this.secondaryLabel,
    required this.secondaryValue,
    required this.secondaryTone,
    required this.progressLabel,
    required this.progressValue,
    required this.progress,
    this.sideLabel,
    this.feedbackTitle,
    this.feedbackMessage,
    this.feedbackMeasurementConfidenceLabel,
    this.feedbackTone = PlannedWorkoutHudTone.positive,
    this.feedbackIcon = Icons.check_rounded,
  });

  final String exerciseTitle;
  final String primaryLabel;
  final String primaryValue;
  final IconData primaryIcon;
  final String secondaryLabel;
  final String secondaryValue;
  final PlannedWorkoutHudTone secondaryTone;
  final String progressLabel;
  final String progressValue;
  final double progress;
  final String? sideLabel;
  final String? feedbackTitle;
  final String? feedbackMessage;
  final String? feedbackMeasurementConfidenceLabel;
  final PlannedWorkoutHudTone feedbackTone;
  final IconData feedbackIcon;

  bool get hasFeedback =>
      feedbackTitle != null &&
      feedbackTitle!.isNotEmpty &&
      feedbackMessage != null &&
      feedbackMessage!.isNotEmpty;
}
