# P0.3 automatic selected-side tracking

## Scope

This step applies only to unilateral standing range-rep movements whose
analysis contract explicitly enables automatic side selection:

- Standing Hamstring Curl
- Standing Hip Abduction
- Standing Hip Extension
- Standing Knee Raise
- Standing Straight-Leg Raise

Bilateral and effectively symmetric movements keep their existing side policy.

## Runtime behavior

1. Pose quality still filters unusable landmark sides.
2. Until a side is confirmed, both usable primary metrics are compared with
   the configured neutral threshold.
3. A side must show at least 6 degrees of toward-peak excursion and beat the
   opposite side by at least 4 degrees for two consecutive accepted frames.
4. The confirmed moving side becomes the preferred analysis side.
5. The first confirmed moving side remains locked for the session.
6. Changing legs requires a session reset, which keeps one set tied to one leg.

## User-visible behavior

Before a leg is confirmed, the live screen explains that the moving leg will be
selected automatically. After confirmation, the selected leg is named in the
live indicator and its hip-knee-ankle chain is highlighted on the pose overlay.

## Device acceptance

For each supported exercise:

1. Start neutral with both legs visible.
2. Move the leg farther from the camera first; the indicator must name and
   highlight that anatomical leg.
3. Complete a repetition and confirm it counts.
4. Return to neutral, then move the opposite leg; the indicator must remain on
   the first confirmed leg for the rest of the session.
5. Reset or restart the session, move the opposite leg first, and confirm the new
   session locks onto that leg.
