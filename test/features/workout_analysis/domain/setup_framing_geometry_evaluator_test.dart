import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_setup_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_framing_geometry.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/setup_framing_geometry_evaluator.dart';

void main() {
  const evaluator = SetupFramingGeometryEvaluator();
  const thresholds = SetupFramingThresholds(
    minimumLandmarkLikelihood: 0.5,
    edgeMargin: 0.05,
    minimumBodyScaleRatio: 0.4,
    maximumBodyScaleRatio: 0.85,
    maximumHorizontalCenterOffset: 0.12,
  );

  group('SetupFramingGeometryEvaluator', () {
    test('reports no person when no confident landmark exists', () {
      final assessment = evaluator.evaluate(
        setupContract: _contract(
          requiredRegions: const <SetupBodyRegion>{SetupBodyRegion.shoulders},
        ),
        pose: _pose(<SetupBodyRegion, List<NormalizedSetupLandmark>>{
          SetupBodyRegion.shoulders: <NormalizedSetupLandmark>[
            _point(0.5, 0.3, likelihood: 0.2),
          ],
        }),
        thresholds: thresholds,
      );

      expect(assessment.status, SetupFramingStatus.noPerson);
      expect(assessment.personDetected, isFalse);
      expect(assessment.requiredLandmarksVisible, isFalse);
      expect(assessment.confidence, 0);
    });

    test('reports missing exercise-specific body coverage', () {
      final assessment = evaluator.evaluate(
        setupContract: _contract(
          requiredRegions: const <SetupBodyRegion>{
            SetupBodyRegion.shoulders,
            SetupBodyRegion.hips,
            SetupBodyRegion.feet,
          },
        ),
        pose: _pose(<SetupBodyRegion, List<NormalizedSetupLandmark>>{
          SetupBodyRegion.shoulders: <NormalizedSetupLandmark>[
            _point(0.45, 0.2),
          ],
          SetupBodyRegion.hips: <NormalizedSetupLandmark>[_point(0.5, 0.55)],
        }),
        thresholds: thresholds,
      );

      expect(assessment.status, SetupFramingStatus.incompleteCoverage);
      expect(assessment.personDetected, isTrue);
      expect(assessment.requiredLandmarksVisible, isFalse);
      expect(assessment.missingRequiredRegions, const <SetupBodyRegion>{
        SetupBodyRegion.feet,
      });
    });

    test('reports all clipped edges while keeping geometry diagnostics', () {
      final assessment = evaluator.evaluate(
        setupContract: _contract(
          requiredRegions: const <SetupBodyRegion>{
            SetupBodyRegion.head,
            SetupBodyRegion.feet,
          },
        ),
        pose: _pose(<SetupBodyRegion, List<NormalizedSetupLandmark>>{
          SetupBodyRegion.head: <NormalizedSetupLandmark>[_point(0.02, 0.03)],
          SetupBodyRegion.feet: <NormalizedSetupLandmark>[_point(0.98, 0.97)],
        }),
        thresholds: thresholds,
      );

      expect(assessment.status, SetupFramingStatus.clipped);
      expect(assessment.clippedEdges, const <SetupFrameEdge>{
        SetupFrameEdge.left,
        SetupFrameEdge.top,
        SetupFrameEdge.right,
        SetupFrameEdge.bottom,
      });
      expect(assessment.bodyScaleRatio, closeTo(0.96, 0.0001));
      expect(assessment.topMargin, closeTo(0.03, 0.0001));
      expect(assessment.bottomMargin, closeTo(0.03, 0.0001));
    });

    test('distinguishes too near from too far using normalized span', () {
      final contract = _contract(
        requiredRegions: const <SetupBodyRegion>{
          SetupBodyRegion.shoulders,
          SetupBodyRegion.feet,
        },
      );

      final tooNear = evaluator.evaluate(
        setupContract: contract,
        pose: _pose(<SetupBodyRegion, List<NormalizedSetupLandmark>>{
          SetupBodyRegion.shoulders: <NormalizedSetupLandmark>[
            _point(0.5, 0.06),
          ],
          SetupBodyRegion.feet: <NormalizedSetupLandmark>[_point(0.5, 0.94)],
        }),
        thresholds: thresholds,
      );
      final tooFar = evaluator.evaluate(
        setupContract: contract,
        pose: _pose(<SetupBodyRegion, List<NormalizedSetupLandmark>>{
          SetupBodyRegion.shoulders: <NormalizedSetupLandmark>[
            _point(0.48, 0.35),
          ],
          SetupBodyRegion.feet: <NormalizedSetupLandmark>[_point(0.52, 0.65)],
        }),
        thresholds: thresholds,
      );

      expect(tooNear.status, SetupFramingStatus.tooNear);
      expect(tooFar.status, SetupFramingStatus.tooFar);
    });

    test(
      'reports off-center only after coverage, clipping, and scale pass',
      () {
        final assessment = evaluator.evaluate(
          setupContract: _contract(
            requiredRegions: const <SetupBodyRegion>{
              SetupBodyRegion.shoulders,
              SetupBodyRegion.feet,
            },
          ),
          pose: _pose(<SetupBodyRegion, List<NormalizedSetupLandmark>>{
            SetupBodyRegion.shoulders: <NormalizedSetupLandmark>[
              _point(0.67, 0.25),
            ],
            SetupBodyRegion.feet: <NormalizedSetupLandmark>[_point(0.75, 0.75)],
          }),
          thresholds: thresholds,
        );

        expect(assessment.status, SetupFramingStatus.offCenter);
        expect(assessment.horizontalCenterOffset, closeTo(0.21, 0.0001));
      },
    );

    test('accepts centered vertical and horizontal body layouts', () {
      final contract = _contract(
        requiredRegions: const <SetupBodyRegion>{
          SetupBodyRegion.shoulders,
          SetupBodyRegion.feet,
        },
      );
      final standing = evaluator.evaluate(
        setupContract: contract,
        pose: _pose(<SetupBodyRegion, List<NormalizedSetupLandmark>>{
          SetupBodyRegion.shoulders: <NormalizedSetupLandmark>[
            _point(0.47, 0.2),
          ],
          SetupBodyRegion.feet: <NormalizedSetupLandmark>[_point(0.53, 0.8)],
        }),
        thresholds: thresholds,
      );
      final floor = evaluator.evaluate(
        setupContract: contract,
        pose: _pose(<SetupBodyRegion, List<NormalizedSetupLandmark>>{
          SetupBodyRegion.shoulders: <NormalizedSetupLandmark>[
            _point(0.2, 0.48),
          ],
          SetupBodyRegion.feet: <NormalizedSetupLandmark>[_point(0.8, 0.52)],
        }),
        thresholds: thresholds,
      );

      expect(standing.status, SetupFramingStatus.ready);
      expect(floor.status, SetupFramingStatus.ready);
      expect(standing.bodyScaleRatio, closeTo(0.6, 0.0001));
      expect(floor.bodyScaleRatio, closeTo(0.6, 0.0001));
    });

    test('confidence averages the strongest visible landmark per region', () {
      final assessment = evaluator.evaluate(
        setupContract: _contract(
          requiredRegions: const <SetupBodyRegion>{
            SetupBodyRegion.shoulders,
            SetupBodyRegion.hips,
          },
        ),
        pose: _pose(<SetupBodyRegion, List<NormalizedSetupLandmark>>{
          SetupBodyRegion.shoulders: <NormalizedSetupLandmark>[
            _point(0.4, 0.25, likelihood: 0.6),
            _point(0.6, 0.25, likelihood: 0.9),
          ],
          SetupBodyRegion.hips: <NormalizedSetupLandmark>[
            _point(0.5, 0.7, likelihood: 0.7),
          ],
        }),
        thresholds: thresholds,
      );

      expect(assessment.confidence, closeTo(0.8, 0.0001));
      expect(assessment.isReady, isTrue);
    });
  });

  group('SetupFramingThresholdResolver', () {
    const resolver = SetupFramingThresholdResolver();

    test('uses different geometry profiles for floor and standing setup', () {
      final standing = resolver.resolve(
        _contract(
          requiredRegions: const <SetupBodyRegion>{
            SetupBodyRegion.head,
            SetupBodyRegion.feet,
          },
        ),
      );
      final floor = resolver.resolve(
        _contract(
          requiredRegions: const <SetupBodyRegion>{
            SetupBodyRegion.head,
            SetupBodyRegion.feet,
          },
          supportSurface: SetupSupportSurface.floor,
        ),
      );

      expect(
        floor.minimumBodyScaleRatio,
        isNot(standing.minimumBodyScaleRatio),
      );
      expect(
        floor.maximumHorizontalCenterOffset,
        greaterThan(standing.maximumHorizontalCenterOffset),
      );
    });

    test('allows a smaller span for upper-body-only preparation', () {
      final upperBody = resolver.resolve(
        _contract(
          requiredRegions: const <SetupBodyRegion>{
            SetupBodyRegion.shoulders,
            SetupBodyRegion.elbows,
            SetupBodyRegion.wrists,
            SetupBodyRegion.hips,
          },
        ),
      );
      final fullBody = resolver.resolve(
        _contract(
          requiredRegions: const <SetupBodyRegion>{
            SetupBodyRegion.head,
            SetupBodyRegion.feet,
          },
        ),
      );

      expect(
        upperBody.minimumBodyScaleRatio,
        lessThan(fullBody.minimumBodyScaleRatio),
      );
      expect(
        upperBody.maximumBodyScaleRatio,
        lessThan(fullBody.maximumBodyScaleRatio),
      );
    });
  });

  test('setup pose and assessment collections are immutable', () {
    final source = <SetupBodyRegion, List<NormalizedSetupLandmark>>{
      SetupBodyRegion.shoulders: <NormalizedSetupLandmark>[_point(0.5, 0.3)],
    };
    final pose = _pose(source);
    source[SetupBodyRegion.shoulders]!.clear();

    expect(pose.landmarksFor(SetupBodyRegion.shoulders), hasLength(1));
    expect(
      () => pose.landmarksFor(SetupBodyRegion.shoulders).clear(),
      throwsUnsupportedError,
    );

    final assessment = evaluator.evaluate(
      setupContract: _contract(
        requiredRegions: const <SetupBodyRegion>{SetupBodyRegion.shoulders},
      ),
      pose: pose,
      thresholds: const SetupFramingThresholds(
        minimumLandmarkLikelihood: 0.5,
        edgeMargin: 0.05,
        minimumBodyScaleRatio: 0.1,
        maximumBodyScaleRatio: 0.9,
        maximumHorizontalCenterOffset: 0.2,
      ),
    );

    expect(
      () => assessment.visibleRequiredRegions.clear(),
      throwsUnsupportedError,
    );
    expect(() => assessment.clippedEdges.clear(), throwsUnsupportedError);
  });
}

ExerciseSetupContract _contract({
  required Set<SetupBodyRegion> requiredRegions,
  SetupSupportSurface supportSurface = SetupSupportSurface.none,
}) {
  final environment = switch (supportSurface) {
    SetupSupportSurface.none => const <SetupEnvironmentRequirement>{
      SetupEnvironmentRequirement.stableCamera,
    },
    SetupSupportSurface.floor => const <SetupEnvironmentRequirement>{
      SetupEnvironmentRequirement.stableCamera,
      SetupEnvironmentRequirement.clearFloorArea,
    },
    SetupSupportSurface.wall => const <SetupEnvironmentRequirement>{
      SetupEnvironmentRequirement.stableCamera,
      SetupEnvironmentRequirement.unobstructedWall,
    },
    SetupSupportSurface.raisedSurface => const <SetupEnvironmentRequirement>{
      SetupEnvironmentRequirement.stableCamera,
      SetupEnvironmentRequirement.stableRaisedSurface,
    },
  };

  return ExerciseSetupContract(
    bodyCoverage: SetupBodyCoverage(requiredRegions: requiredRegions),
    startPoseFamily: StartPoseFamily.standingNeutralSide,
    supportSurface: supportSurface,
    cameraHeight: SetupCameraHeight.midBodyLevel,
    environmentRequirements: environment,
  );
}

SetupFramingPose _pose(
  Map<SetupBodyRegion, List<NormalizedSetupLandmark>> landmarksByRegion,
) {
  return SetupFramingPose(landmarksByRegion: landmarksByRegion);
}

NormalizedSetupLandmark _point(double x, double y, {double likelihood = 1}) {
  return NormalizedSetupLandmark(x: x, y: y, likelihood: likelihood);
}
