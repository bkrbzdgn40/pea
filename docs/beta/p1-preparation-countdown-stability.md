# P1 preparation countdown stability

The preparation gate now follows the readiness state machine's temporary-loss grace instead of cancelling the countdown on the first dropped pose frame.

## Behaviour

- Stable readiness starts the normal three-step countdown.
- `temporarilyLost` pauses the current countdown step and preserves its remaining time.
- Returning to `ready` within the readiness grace window resumes the same step instead of restarting the countdown.
- A conclusive framing, view, or start-pose failure still cancels the countdown and returns to monitoring.
- Manual-override countdowns remain independent from pose-readiness changes.
- Countdown approval cannot occur while readiness is temporarily lost.

This change does not relax start-pose, framing, camera-view, or exercise thresholds. It only prevents short landmark dropouts from repeatedly resetting an otherwise valid preparation countdown.
