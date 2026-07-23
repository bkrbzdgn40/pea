import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metric_registry.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/feedback_delivery_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/workout_live_metric_display_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/feedback_delivery_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

void main() {
  test(
    'live metric display suppresses frames with the same rounded values',
    () {
      var now = DateTime.utc(2030, 1, 1);
      final container = ProviderContainer(
        overrides: <Override>[
          activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.lunge),
          exerciseConfigProvider.overrideWith((ref) => _lungeConfig()),
          poseDetectorProvider.overrideWith((ref) => _FakePoseDetector()),
          feedbackDeliveryProvider.overrideWithValue(_NoopFeedbackDelivery()),
          workoutClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      final workoutSubscription = container.listen(
        workoutControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(workoutSubscription.close);

      final published = <WorkoutLiveMetricDisplayState>[];
      final metricsSubscription = container.listen(
        workoutLiveMetricsProvider,
        (_, next) => published.add(next),
        fireImmediately: true,
      );
      addTearDown(metricsSubscription.close);
      final controller = container.read(workoutControllerProvider.notifier);

      void feed(double angle) {
        controller.processExerciseMetricsForTesting(
          metrics: _bilateralMetrics(left: angle, right: null),
          now: now,
        );
        now = now.add(const Duration(milliseconds: 100));
      }

      feed(165.1);
      feed(165.2);
      feed(165.4);

      expect(published, hasLength(2));
      expect(published.first, WorkoutLiveMetricDisplayState.empty);
      expect(published.last.angleDegrees, 165);
    },
  );

  test(
    'lunge runtime feeds alternating sidecar and publishes symmetry metrics',
    () {
      var now = DateTime.utc(2030, 1, 1);
      final container = ProviderContainer(
        overrides: <Override>[
          activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.lunge),
          exerciseConfigProvider.overrideWith((ref) => _lungeConfig()),
          poseDetectorProvider.overrideWith((ref) => _FakePoseDetector()),
          feedbackDeliveryProvider.overrideWithValue(_NoopFeedbackDelivery()),
          workoutClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        workoutControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final metricsSubscription = container.listen(
        workoutLiveMetricsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(metricsSubscription.close);
      final controller = container.read(workoutControllerProvider.notifier);

      void feed({double? left, double? right}) {
        controller.processExerciseMetricsForTesting(
          metrics: _bilateralMetrics(left: left, right: right),
          now: now,
        );
        now = now.add(const Duration(milliseconds: 100));
      }

      void completeRep({required bool leftSide}) {
        for (final value in <double>[
          165,
          165,
          140,
          140,
          110,
          110,
          130,
          130,
          165,
          165,
        ]) {
          feed(left: leftSide ? value : null, right: leftSide ? null : value);
        }
      }

      completeRep(leftSide: true);
      completeRep(leftSide: false);

      final metrics = controller.liveMetricsSnapshot();
      final display = container.read(workoutLiveMetricsProvider);
      expect(display.asymmetryScore, 0);
      expect(metrics.leftRepCount, 1);
      expect(metrics.rightRepCount, 1);
      expect(
        metrics.sessionMetrics.valueFor(ExerciseMetricRegistry.symmetry),
        0,
      );
      expect(
        metrics.sessionMetrics.valueFor(ExerciseMetricRegistry.asymmetryScore),
        0,
      );
    },
  );
}

ExerciseMetrics _bilateralMetrics({double? left, double? right}) {
  RangeRepSideMetrics side(RangeRepSide side, double? value) {
    if (value == null) {
      return RangeRepSideMetrics.unavailable(side);
    }
    return RangeRepSideMetrics(
      side: side,
      primaryAngle: value,
      formMetric: 170,
      hasPrimaryAngle: true,
      hasFormMetric: true,
      sideConfidence: 1,
    );
  }

  final leftMetrics = side(RangeRepSide.left, left);
  final rightMetrics = side(RangeRepSide.right, right);
  final selected = left ?? right;
  return ExerciseMetrics(
    primaryAngle: selected ?? 180,
    formMetric: 170,
    hasPrimaryAngle: selected != null,
    hasFormMetric: selected != null,
    hasPose: selected != null,
    landmarks: const <PoseLandmark>[],
    leftRangeRepMetrics: leftMetrics,
    rightRangeRepMetrics: rightMetrics,
  );
}

ExerciseConfig _lungeConfig() {
  return ExerciseConfig(
    name: 'Stationary Lunge',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 145,
    thresholdPeak: 115,
  );
}

class _FakePoseDetector implements PoseDetector {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopFeedbackDelivery implements FeedbackDeliveryPort {
  @override
  Future<FeedbackDeliveryResult> deliver(FeedbackDeliveryCue cue) async {
    return FeedbackDeliveryResult(
      disposition: FeedbackDeliveryDisposition.delivered,
      cue: cue,
      hapticPattern: FeedbackHapticPattern.none,
    );
  }

  @override
  void reset() {}

  @override
  Future<void> stop() async {}
}
