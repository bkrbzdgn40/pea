# P1.3 device follow-up: Bent-Knee Leg Raise and Frog Pump

## Bent-Knee Leg Raise

Device evidence showed that readiness could pass while the preparation ghost still implied that the feet rested on the floor. The dedicated template now keeps both knees flexed and raises the ankle markers clearly above the floor line.

## Frog Pump

Preparation accepted the intended floor setup, but live analysis remained in `AWAITING_NEUTRAL` while the observed primary metric was approximately 150 degrees. The production thresholds previously required a value below 125 degrees, so setup and live analysis described different neutral poses.

The calibrated lifecycle uses:

- neutral: 152 degrees
- active: 158 degrees
- peak: 165 degrees
- literal peak entry, without an additional three-degree margin
- 600 ms stable initial neutral confirmation
- retained neutral-to-peak evidence for ROM validation

This is a device-derived engineering calibration, not a clinical joint-angle claim.

## Deferred: weighted-equipment occlusion

Floor Chest Press remains vulnerable when a dumbbell covers the wrist, elbow, or torso landmark. That is a general landmark-occlusion and visibility problem affecting multiple weighted exercises, so it is intentionally deferred from this start-pose patch.
