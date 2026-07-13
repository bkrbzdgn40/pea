import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_acceptance_stabilizer.dart';

void main() {
  group('PoseAcceptanceStabilizer', () {
    test('one accepted frame after loss does not reacquire tracking', () {
      final stabilizer = PoseAcceptanceStabilizer()
        ..recordAcceptedFrame()
        ..recordAcceptedFrame()
        ..recordInvalidFrame();

      final assessment = stabilizer.recordAcceptedFrame();

      expect(assessment.shouldAcceptForAnalysis, isFalse);
      expect(assessment.didBecomeStable, isFalse);
      expect(assessment.consecutiveAcceptedFrameCount, 1);
    });

    test('two consecutive accepted frames reacquire tracking', () {
      final stabilizer = PoseAcceptanceStabilizer();

      stabilizer.recordAcceptedFrame();
      final assessment = stabilizer.recordAcceptedFrame();

      expect(assessment.shouldAcceptForAnalysis, isTrue);
      expect(assessment.didBecomeStable, isTrue);
      expect(assessment.isTrackingStable, isTrue);
    });

    test('accepted then rejected resets confirmation', () {
      final stabilizer = PoseAcceptanceStabilizer();

      stabilizer.recordAcceptedFrame();
      stabilizer.recordInvalidFrame();
      final assessment = stabilizer.recordAcceptedFrame();

      expect(assessment.shouldAcceptForAnalysis, isFalse);
      expect(assessment.consecutiveAcceptedFrameCount, 1);
    });

    test('accepted then no-pose resets confirmation', () {
      final stabilizer = PoseAcceptanceStabilizer();

      stabilizer.recordAcceptedFrame();
      stabilizer.recordInvalidFrame();
      final assessment = stabilizer.recordAcceptedFrame();

      expect(assessment.shouldAcceptForAnalysis, isFalse);
      expect(assessment.consecutiveAcceptedFrameCount, 1);
    });

    test('stable tracking accepted frame has no extra two-frame delay', () {
      final stabilizer = PoseAcceptanceStabilizer();

      stabilizer.recordAcceptedFrame();
      stabilizer.recordAcceptedFrame();
      final assessment = stabilizer.recordAcceptedFrame();

      expect(assessment.shouldAcceptForAnalysis, isTrue);
      expect(assessment.didBecomeStable, isFalse);
      expect(assessment.isTrackingStable, isTrue);
    });
  });
}
