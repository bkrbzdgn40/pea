# RangeRep exercise batch: biomechanical signal selection

This batch intentionally keeps the measured signal set small. A measurable joint angle is not automatically a useful product signal.

## Added in this batch

1. Lying Leg Raise
2. Bench Dip (stable internal id: `triceps_dip`)
3. Romanian Deadlift
4. Stationary Lunge
5. Lateral Raise
6. Shoulder Press

Alternating Lunge is deliberately not enabled here. It belongs to the still-unimplemented alternating-rep engine family and should not be disguised as a standard range-rep exercise.

## Signal policy

### Lying Leg Raise
- Primary: hip angle (`shoulder -> hip -> knee`), decreasing toward the raised-leg peak.
- Technique: knee extension (`hip -> knee -> ankle`).
- Rationale: bilateral/straight leg raises are hip-flexion tasks with meaningful abdominal stabilization demand; knee extension is the only extra angle retained because bending the knee materially changes the task.

### Bench Dip
- Stable internal exercise id: `triceps_dip`.
- Primary: elbow angle (`shoulder -> elbow -> wrist`), decreasing toward the bottom.
- Technique: shoulder-extension proxy (`elbow -> shoulder -> hip`, complemented to preserve the existing low-is-warning form convention).
- Product scope: bench/chair dip with the feet supported on the floor; parallel-bar dip is no longer the canonical positive path.
- Rationale: dip kinematics are dominated by elbow flexion plus shoulder extension. Bench dips use more shoulder extension and less elbow flexion than bar dips in comparative 3D kinematic evidence (PMCID: PMC9603242), so excessive shoulder extension remains a warning rather than a hard validity gate. The production peak threshold is aligned to a controlled bottom near a 90-degree elbow angle instead of rewarding unnecessary depth.

### Romanian Deadlift
- Primary: hip angle (`shoulder -> hip -> knee`), decreasing through the hinge.
- Technique: knee angle (`hip -> knee -> ankle`).
- Rationale: RDL is a hip-hinge pattern with comparatively limited knee motion. Literature reports roughly 15-33 degrees of knee flexion depending on protocol and depth; the product threshold is intentionally permissive and treated as technique feedback, not rep validity.

### Stationary Lunge
- Primary: working/front knee angle (`hip -> knee -> ankle`), decreasing toward the bottom.
- No additional technique angle in v1.
- Rationale: sagittal knee motion is sufficient for rep lifecycle. Frontal-plane valgus, pelvic drop and stance quality need a different camera/measurement contract and are not inferred from a side-view knee angle.
- Product setup: the camera-near leg should be the front/working leg so selected-side tracking follows the intended knee.

### Lateral Raise
- Primary: shoulder abduction proxy (`elbow -> shoulder -> hip`), increasing toward shoulder height.
- Technique: elbow extension (`shoulder -> elbow -> wrist`).
- Rationale: the movement is shoulder abduction/adduction. The implementation targets approximately shoulder-height raises instead of rewarding unnecessary elevation above the target.

### Shoulder Press
- Primary: elbow angle (`shoulder -> elbow -> wrist`), increasing toward extension.
- No extra technique angle in v1.
- Rationale: elbow extension is a robust 2D rep signal from the front. Scapular mechanics are biomechanically important during overhead pressing but are not estimated reliably from a single ML Kit shoulder landmark, so no pseudo-precision is added.

## ROM validation note

`primaryRom` is measured from the engine's confirmed active-phase start to the observed peak, not from the last anatomical-neutral frame. The new `minAcceptableRomDelta` values are therefore conservative consistency guards derived below the configured active-to-peak gate span. They are not clinical range-of-motion cutoffs. Peak detection itself remains the main lifecycle gate, and real-device data should drive any future tightening.

## Engine change

`RangeRepEngine` now supports both:
- `decreasingToPeak`
- `increasingToPeak`

Threshold ordering is validated by `AnalysisEngineFactory`, and bilateral primary-metric resolution is direction-aware.

The contract also declares the dominant muscle action while moving toward peak. This keeps Firestore rep tempo fields biomechanically correct: `descentMillis` / `ascentMillis` remain legacy topology timings, while `eccentricMillis` / `concentricMillis` are mapped according to the exercise contract.

## Research anchors

- Active/straight leg raise and hip flexor/abdominal recruitment: PMID 22728211, 9118976, 34455371.
- Dip kinematics: PMCID PMC9603242 and PMC9659300. Bar dip peak shoulder extension is around the high-60 degree range and peak elbow flexion is around 110+ degrees in the cited sample; bench dips use substantially more shoulder extension.
- Romanian deadlift: PMCID PMC6323186. The study discusses approximately 15 degrees of prescribed knee flexion, observed RDL knee flexion around 33 degrees in its deeper protocol, and much greater hip than knee contribution compared with conventional deadlift.
- Forward lunge biomechanics: PMID 22889652 and 22297808. Knee and hip flexion are key sagittal kinematic variables; this product deliberately avoids claiming frontal-plane technique quality from a side-only view.
- Lateral raise: PMCID PMC6908899 and PMC7719663. Controlled lateral raises in the cited protocols use roughly 10-100 degrees of shoulder abduction and treat <90 degrees as incomplete in the fatigue protocol.
- Military/shoulder press: PMID 24439246 and 20508462. Overhead pressing combines shoulder/scapular motion with elbow extension; the current product tracks the robust elbow component and avoids pretending a single 2D scapular landmark can resolve scapulothoracic mechanics.

These values are engineering starting points for phase detection and warning-level feedback, not clinical diagnostic cutoffs. Real-device calibration data should be used before tightening any threshold.
