enum HoldFeedbackFamily { systemState, correctiveCue }

enum HoldFeedbackCode {
  preparePosition,
  holdPosition,
  bodyNotVisible,
  alignHips,
  adjustElbowSupport,
  extendLegs,
  increaseHollowCompression,
  extendArmsOverhead,
  straightenKnees,
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
      case HoldFeedbackCode.increaseHollowCompression:
      case HoldFeedbackCode.extendArmsOverhead:
      case HoldFeedbackCode.straightenKnees:
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
      case HoldFeedbackCode.increaseHollowCompression:
        return 'increase_hollow_compression';
      case HoldFeedbackCode.extendArmsOverhead:
        return 'extend_arms_overhead';
      case HoldFeedbackCode.straightenKnees:
        return 'straighten_knees';
      case HoldFeedbackCode.correctForm:
        return 'correct_form';
    }
  }
}
