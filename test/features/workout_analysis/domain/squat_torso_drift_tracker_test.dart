import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_technique_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/squat_torso_drift_tracker.dart';

void main() {
  group('SquatTorsoDriftTracker', () {
    test('observes signed torso inclination delta between adjacent phases', () {
      final tracker = SquatTorsoDriftTracker();
      tracker.record(
        phase: RangeRepTechniquePhase.descending,
        inclinationDegrees: 18.0,
      );
      tracker.record(
        phase: RangeRepTechniquePhase.peak,
        inclinationDegrees: 31.5,
      );

      final observation = tracker.observeTransition(
        referencePhase: RangeRepTechniquePhase.descending,
        measuredPhase: RangeRepTechniquePhase.peak,
      );

      expect(observation, isNotNull);
      expect(observation!.type, RangeRepTechniqueObservationType.torsoDrift);
      expect(observation.code, 'squat_torso_drift_observed');
      expect(observation.severity, RangeRepTechniqueSeverity.info);
      expect(observation.referencePhase, RangeRepTechniquePhase.descending);
      expect(observation.phase, RangeRepTechniquePhase.peak);
      expect(observation.referenceValue, 18.0);
      expect(observation.measuredValue, 31.5);
      expect(observation.deltaValue, 13.5);
    });

    test(
      'preserves drift direction without classifying it as bad technique',
      () {
        final tracker = SquatTorsoDriftTracker();
        tracker.record(
          phase: RangeRepTechniquePhase.peak,
          inclinationDegrees: 34.0,
        );
        tracker.record(
          phase: RangeRepTechniquePhase.ascending,
          inclinationDegrees: 20.0,
        );

        final observation = tracker.observeTransition(
          referencePhase: RangeRepTechniquePhase.peak,
          measuredPhase: RangeRepTechniquePhase.ascending,
        );

        expect(observation, isNotNull);
        expect(observation!.deltaValue, -14.0);
        expect(observation.severity, RangeRepTechniqueSeverity.info);
      },
    );

    test('does not fabricate an observation when either phase is missing', () {
      final tracker = SquatTorsoDriftTracker();
      tracker.record(
        phase: RangeRepTechniquePhase.descending,
        inclinationDegrees: 18.0,
      );

      expect(
        tracker.observeTransition(
          referencePhase: RangeRepTechniquePhase.descending,
          measuredPhase: RangeRepTechniquePhase.peak,
        ),
        isNull,
      );
    });

    test('ignores non-finite measurements', () {
      final tracker = SquatTorsoDriftTracker();
      tracker.record(
        phase: RangeRepTechniquePhase.descending,
        inclinationDegrees: double.nan,
      );
      tracker.record(
        phase: RangeRepTechniquePhase.peak,
        inclinationDegrees: 20.0,
      );

      expect(
        tracker.observeTransition(
          referencePhase: RangeRepTechniquePhase.descending,
          measuredPhase: RangeRepTechniquePhase.peak,
        ),
        isNull,
      );
    });

    test('reset prevents values leaking into the next rep', () {
      final tracker = SquatTorsoDriftTracker();
      tracker.record(
        phase: RangeRepTechniquePhase.descending,
        inclinationDegrees: 18.0,
      );
      tracker.record(
        phase: RangeRepTechniquePhase.peak,
        inclinationDegrees: 30.0,
      );
      tracker.reset();
      tracker.record(
        phase: RangeRepTechniquePhase.peak,
        inclinationDegrees: 22.0,
      );

      expect(
        tracker.observeTransition(
          referencePhase: RangeRepTechniquePhase.descending,
          measuredPhase: RangeRepTechniquePhase.peak,
        ),
        isNull,
      );
    });
  });
}
