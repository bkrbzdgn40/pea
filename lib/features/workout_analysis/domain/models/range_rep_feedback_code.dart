/// High-level feedback families for range-rep analysis.
enum RangeRepFeedbackFamily { systemState, movementCue, correctiveCue }

/// Stable domain-level feedback codes for range-rep analysis.
///
/// These identifiers are exercise-agnostic within the range-rep family and are
/// intentionally separate from UI strings, telemetry text, and persistence
/// concerns.
enum RangeRepFeedbackCode {
  awaitNeutral,
  ready,
  waitForBody,
  bodyNotVisible,
  descend,
  ascend,
  repCompleted,
  repIncomplete,
  keepBodyUpright,
  controlDescent,
  controlAscent,
  stabilizeTransition,
  maintainForm,
}

/// Optional surface for range-rep engines that can expose a typed feedback code.
abstract class RangeRepFeedbackSource {
  RangeRepFeedbackCode? get feedbackCode;
}

extension RangeRepFeedbackCodeX on RangeRepFeedbackCode {
  RangeRepFeedbackFamily get family {
    switch (this) {
      case RangeRepFeedbackCode.awaitNeutral:
      case RangeRepFeedbackCode.ready:
      case RangeRepFeedbackCode.waitForBody:
      case RangeRepFeedbackCode.bodyNotVisible:
        return RangeRepFeedbackFamily.systemState;
      case RangeRepFeedbackCode.descend:
      case RangeRepFeedbackCode.ascend:
      case RangeRepFeedbackCode.repCompleted:
      case RangeRepFeedbackCode.repIncomplete:
        return RangeRepFeedbackFamily.movementCue;
      case RangeRepFeedbackCode.keepBodyUpright:
      case RangeRepFeedbackCode.controlDescent:
      case RangeRepFeedbackCode.controlAscent:
      case RangeRepFeedbackCode.stabilizeTransition:
      case RangeRepFeedbackCode.maintainForm:
        return RangeRepFeedbackFamily.correctiveCue;
    }
  }

  String get code {
    switch (this) {
      case RangeRepFeedbackCode.awaitNeutral:
        return 'await_neutral';
      case RangeRepFeedbackCode.ready:
        return 'ready';
      case RangeRepFeedbackCode.waitForBody:
        return 'wait_for_body';
      case RangeRepFeedbackCode.bodyNotVisible:
        return 'body_not_visible';
      case RangeRepFeedbackCode.descend:
        return 'descend';
      case RangeRepFeedbackCode.ascend:
        return 'ascend';
      case RangeRepFeedbackCode.repCompleted:
        return 'rep_completed';
      case RangeRepFeedbackCode.repIncomplete:
        return 'rep_incomplete';
      case RangeRepFeedbackCode.keepBodyUpright:
        return 'keep_body_upright';
      case RangeRepFeedbackCode.controlDescent:
        return 'control_descent';
      case RangeRepFeedbackCode.controlAscent:
        return 'control_ascent';
      case RangeRepFeedbackCode.stabilizeTransition:
        return 'stabilize_transition';
      case RangeRepFeedbackCode.maintainForm:
        return 'maintain_form';
    }
  }
}
