# P0.4 Range-rep count, score, and validation semantics

## User-facing rule

A completed range-rep attempt has one of three outcomes:

- `valid`: counted in REPS and scored.
- `lowConfidence`: counted in REPS and scored, while the caution outcome remains visible.
- `invalid`: shown as a corrective outcome, but it does not advance REPS and does not publish a score.

The underlying detection engine may still retain its attempt index for diagnostics. The live repetition total is owned by the validation outcome tracker so rejected attempts cannot advance planned workouts or session totals.

## Persistence rule

Persisted `WorkoutRep` entries retain every evaluated attempt so invalid reasons remain available in session details. Their `repIndex` is the diagnostic attempt index. Invalid attempts persist with a null score and do not contribute to `totalReps`, ROM/tempo session metrics, or score aggregates. `totalReps` is the accepted live count (`valid + lowConfidence`), `validReps` is the strict-valid subset, `lowConfidenceReps` is the accepted caution subset, and `invalidReps` records rejected attempts outside that accepted total. Summary copy therefore presents all three outcomes separately and describes invalid outcomes as excluded attempts rather than as part of the live total.

## Score rule

Scoring runs only after validation classifies the attempt. Invalid attempts clear the current score presentation and do not enter average, best, or worst score aggregates. Low-confidence repetitions keep an explainable score because they completed the movement lifecycle but carry a caution such as tempo, coverage, or persistent form feedback.
