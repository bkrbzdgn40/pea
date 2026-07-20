# PEA Analysis Core v2 Completion Report

This working copy implements the canonical R23-R35 roadmap sequence while
keeping the documented parking-lot scope out of the change set.

## Implemented roadmap steps

- **R23 - Plank hip deviation**: normalized shoulder-ankle line deviation is
  derived in a plank-specific boundary selected by explicit hold family.
- **R24 - Plank shoulder-elbow offset**: normalized physical offset is derived
  separately from the legacy elbow-angle support gate.
- **R25 - Plank severity separation**: pose acceptance, hold validity,
  hold-break disposition, technique observations, severity, and feedback have
  separate ownership. Legacy hard-gate results are compatibility evidence only
  and do not determine technique severity.
- **R26 - Biceps torso swing**: bilateral torso inclination is measured and a
  neutral-to-peak delta observation is produced.
- **R27 - Biceps ROM delta**: completed-rep detection carries `startAngle` and
  `primaryRom = startAngle - peak/minAngle`; optional delta validation is
  supported without inventing a production threshold.
- **R28 - Calibration semantics**: exercise-owned technique thresholds are no
  longer rewritten by calibration. A calibration-derived correction candidate
  remains diagnostic only until an independent trusted correction source is
  available.
- **R29 - Saturating ROM scoring**: ROM scoring exposes `insufficient`,
  `acceptable`, and `targetReached` regions and saturates at 100 after target.
- **R30 - Score components**: ROM, tempo, technique, consistency, and confidence
  are exposed separately while the existing final-score calculation remains
  compatible.
- **R31 - Explainability**: applied score-component penalties carry evidence
  codes and observed/reference values where applicable.
- **R32 - Rep analysis persistence**: validation status, confidence, primary
  ROM, eccentric/concentric duration, technique observations, selected side,
  and coverage quality flow through the rep model, lifecycle collection,
  Firestore mapper, and Firestore rules.
- **R33 - Hollow Hold variation contract**: tuck, bent-knee, straight-leg, and
  straight-leg-overhead variations are explicit domain contracts.
- **R34 - Limb elevation measurements**: normalized shoulder and heel elevation
  measurements are available from the hold coordinator.
- **R35 - Variation-specific validation**: Hollow Hold engine creation,
  landmark requirements, signal extraction, posture validation, and feedback
  follow the selected variation's required signals.

## Compatibility fix

Several application-layer imports referenced `core/` one directory too high.
Those paths were corrected because they would block analysis/compilation. No
camera scheduling, ML Kit model, UI redesign, or other parking-lot expansion was
introduced.

## Validation performed in this environment

The execution environment did not contain Flutter or Dart SDK binaries, so the
canonical `dart format`, `flutter analyze`, and `flutter test` gates could not
be executed here. This archive therefore must not be treated as CI-verified
until those commands run in the project's normal Flutter toolchain.

The following static checks were performed before packaging:

- internal Dart import target existence check
- lightweight delimiter/string/comment structural scan across `lib/` and `test/`
- JSON parse validation
- `git diff --check`
- constructor/call-site sweeps for changed hold contracts, hold evaluation, and
  coordinator wiring
- focused source review of R23-R35 model-to-runtime-to-persistence paths

## Recommended verification commands

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

If the repository's Firebase emulator suite is available, also run the existing
Firestore rules tests before merge.
