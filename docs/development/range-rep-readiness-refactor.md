# Range-Rep Readiness Refactor

## Goal

Prepare the current range-rep architecture for adding more exercises without growing `DefaultRangeRepCoordinator` with exercise-specific branches.

## Changes

- Replaced `identical(rangeRepContract, RangeRepContracts.*)` routing with semantic `RangeRepContract.extensionProfile` metadata.
- Moved Squat, Push-up, and Biceps Curl exercise-specific diagnostics/biomechanics behind `RangeRepExerciseAnalysisExtension`.
- Split each exercise extension into its own file.
- Added an injectable extension factory so custom tests or future wiring can replace an extension without changing the coordinator.
- Added explicit `RangeRepPrimaryMetricDirection` metadata.
- Added an engine-factory guard that rejects `increasingToPeak` contracts until the detection/core metric model is made direction-aware.
- Added `range_rep_extension_readiness_test.dart` to validate catalog/config/contract/landmark/factory readiness for every supported range-rep exercise.
- Added `range-rep-extension-guide.md` as the onboarding contract for new range-rep exercises.

## Intentionally unchanged

- Production range-rep detection behavior and thresholds.
- Existing scoring and validation semantics.
- Existing legacy `AnalysisEngine.update` compatibility path inside `RangeRepEngine`.
- Firestore schema and `firestore.rules`.

The production coordinator already uses `RangeRepEngine.updateDetectionFrame`, so the legacy engine path remains compatibility code rather than production orchestration.

## Required local verification

Run in the normal Flutter toolchain after integration:

```bash
dart format .
flutter analyze
flutter test
git diff --check
```

The build environment used for this refactor did not contain Flutter or Dart SDK binaries, so these commands were not executed here.
