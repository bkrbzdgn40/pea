# P0 Standing Hip Extension Device Calibration

## Evidence

The first device recording showed backward leg excursions near 151, 148, 160,
and 150 degrees. A later real-device smoke test showed that a normal controlled
repetition can bottom out around the displayed 160-degree value. Under the
previous 152-degree peak threshold, that movement stayed in the toward-peak
phase and was aborted on return, producing "move backward" followed by
"complete the full movement".

## Calibration

- Neutral threshold remains 172 degrees because the standing start pose is
  acquired reliably.
- Active threshold moves from 165 to 170 degrees. With the shared 3-degree
  active-entry margin, the effective active gate is below 167 degrees.
- Peak threshold moves from 152 to 163 degrees with zero peak-entry margin. A
  controlled displayed angle around 160 degrees can therefore confirm peak,
  while a 165-166 degree shallow excursion remains below full range.
- The ROM scoring target moves from 148 to 160 degrees.
- Peak evidence is retained across active-entry confirmation. This preserves the
  full neutral-to-peak excursion instead of reducing validation to the narrow
  active-to-peak segment.
- Validation minimum ROM remains 10 degrees. With retained neutral evidence, a
  176-to-160 degree repetition reports about 16 degrees of primary ROM.

## Acceptance

- A controlled repetition reaching about 160 degrees should enter peak, cue the
  user to return to the start, and complete successfully near neutral.
- A 165-166 degree shallow excursion should not count.
- Returning from a confirmed 160-degree peak must not emit incomplete-movement
  feedback.
- Knee-straightness feedback remains unchanged and will be evaluated after the
  selected-side UX work.

This remains a single-device calibration. Broader production calibration still
requires raw-angle recordings from multiple users and both sides.
