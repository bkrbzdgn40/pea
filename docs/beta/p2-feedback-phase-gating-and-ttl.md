# P2.1 feedback phase gating and TTL

Range-rep feedback now has an explicit live lifecycle instead of keeping the
last selected code until an unrelated transition overwrites it.

## Phase gating

- A live form correction is scoped to the movement phase in which it was
  observed.
- Entering a different phase clears the previous correction immediately.
- `peakWindowOnly` exercises remain strict: a correction disappears on the
  first clean frame in the same peak window.
- Completed-rep phase-quality findings are presented through the existing
  validated outcome card rather than becoming the underlying live cue after
  that card expires.

## TTL

- Normal live corrective cues have a 1200 ms phase-scoped TTL. This prevents
  one noisy clean frame from making the message flicker while still ensuring
  that a recovered correction disappears.
- `repCompleted` and `repIncomplete` have a 1600 ms neutral-phase TTL so they
  remain readable but cannot leak into the next repetition.
- The validated rep outcome card keeps its existing 2800 ms display TTL and
  remains the primary post-rep result surface.

## Non-goals

This change does not modify exercise thresholds, repetition detection,
validation, scoring, tempo limits, pose acceptance, or hold-engine feedback.
It only controls how already-selected range-rep feedback is retained and
cleared.
