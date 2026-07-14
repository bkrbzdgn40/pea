enum HoldFeedbackFamily { systemState, correctiveCue }

enum HoldFeedbackCode {
  preparePosition,
  holdPosition,
  bodyNotVisible,
  alignHips,
  adjustElbowSupport,
  extendLegs,
  correctForm,
}

abstract interface class HoldFeedbackSource {
  HoldFeedbackCode get feedbackCode;
}

extension HoldFeedbackCodeX on HoldFeedbackCode {
  HoldFeedbackFamily get family {
    switch (this) {
      case HoldFeedbackCode.preparePosition:
      case HoldFeedbackCode.holdPosition:
      case HoldFeedbackCode.bodyNotVisible:
        return HoldFeedbackFamily.systemState;
      case HoldFeedbackCode.alignHips:
      case HoldFeedbackCode.adjustElbowSupport:
      case HoldFeedbackCode.extendLegs:
      case HoldFeedbackCode.correctForm:
        return HoldFeedbackFamily.correctiveCue;
    }
  }

  String get code {
    switch (this) {
      case HoldFeedbackCode.preparePosition:
        return 'prepare_position';
      case HoldFeedbackCode.holdPosition:
        return 'hold_position';
      case HoldFeedbackCode.bodyNotVisible:
        return 'body_not_visible';
      case HoldFeedbackCode.alignHips:
        return 'align_hips';
      case HoldFeedbackCode.adjustElbowSupport:
        return 'adjust_elbow_support';
      case HoldFeedbackCode.extendLegs:
        return 'extend_legs';
      case HoldFeedbackCode.correctForm:
        return 'correct_form';
    }
  }
}
