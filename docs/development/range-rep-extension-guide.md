# Range-Rep Extension Guide

This guide defines the extension boundary for adding new range-rep exercises without growing the production coordinator into an exercise switchboard.

## Generic ownership

The generic range-rep pipeline owns:

- pose/frame acceptance
- side selection and stabilization
- primary metric smoothing
- neutral -> descending -> peak -> ascending -> neutral detection
- rep lifecycle and timing
- validation orchestration
- score orchestration
- rep outcome publication

`RangeRepEngine.updateDetectionFrame` is the production detection API. The legacy `AnalysisEngine.update` path remains only as a compatibility surface for older direct callers and tests.

## Exercise-owned extensions

Exercise-specific biomechanics and diagnostics belong behind `RangeRepExerciseAnalysisExtension`.

Current profiles:

- `none`
- `squat`
- `pushUp`
- `bicepsCurl`

The coordinator resolves the extension from `RangeRepContract.extensionProfile`. It does not compare contract object identity and it does not contain per-exercise `if` branches.

When adding an exercise-specific extension:

1. Add a semantic `RangeRepExtensionProfile` value.
2. Implement `RangeRepExerciseAnalysisExtension` in its own exercise-specific file.
3. Register the implementation in `RangeRepExerciseAnalysisExtensionFactory`.
4. Set the profile on the exercise's `RangeRepContract`.
5. Keep threshold-free physical measurements separate from validation/scoring unless an explicit contract requires otherwise.

## Primary metric direction

`RangeRepContract.primaryMetricDirection` makes the engine's movement assumption explicit.

The current engine supports `decreasingToPeak` only. An exercise whose primary metric increases from neutral toward peak must not be enabled by tuning thresholds until the detection/core data model becomes direction-aware. The engine factory rejects that contract early instead of silently producing incorrect reps.

## New exercise readiness checklist

A new range-rep exercise should satisfy all of the following before it is marked supported:

- catalog definition exists
- config asset exists and parses
- camera-view contract is explicit
- range-rep contract declares descending, peak, and ascending
- primary metric and current form-metric carrier are declared
- primary metric direction is supported
- landmark requirements resolve
- neutral acquisition works
- one complete cycle counts exactly one rep
- aborted cycle does not count
- validation config is exercise-owned
- exercise-specific biomechanics use an extension, not coordinator branches
- production controller path test passes
- rep persistence test passes

`range_rep_extension_readiness_test.dart` provides a shared guard for the current contract assumptions.
