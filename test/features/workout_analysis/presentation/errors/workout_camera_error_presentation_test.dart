import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/errors/workout_camera_error_presentation.dart';

void main() {
  const localizations = AppLocalizations(Locale('en'));

  test('maps permission failures to permission recovery copy', () {
    final presentation = presentWorkoutCameraError(
      error: CameraException('cameraPermission', 'secret plugin detail'),
      localizations: localizations,
    );

    expect(presentation.kind, WorkoutCameraErrorKind.permission);
    expect(presentation.requiresPermissionAction, isTrue);
    expect(presentation.actionLabel, 'Check Permission');
    expect(presentation.message, isNot(contains('secret plugin detail')));
  });

  test('maps camera-in-use failures to actionable product copy', () {
    final presentation = presentWorkoutCameraError(
      error: PlatformException(
        code: 'camera_in_use',
        message: 'opaque platform detail',
      ),
      localizations: localizations,
    );

    expect(presentation.kind, WorkoutCameraErrorKind.inUse);
    expect(presentation.actionLabel, 'Retry');
    expect(presentation.message, contains('another app'));
    expect(presentation.message, isNot(contains('opaque platform detail')));
  });

  test('maps unknown failures without exposing exception text', () {
    final presentation = presentWorkoutCameraError(
      error: StateError('internal camera stack detail'),
      localizations: localizations,
    );

    expect(presentation.kind, WorkoutCameraErrorKind.unavailable);
    expect(presentation.message, contains('could not be started'));
    expect(
      presentation.message,
      isNot(contains('internal camera stack detail')),
    );
  });

  test('recognizes transient camera lifecycle failures', () {
    expect(
      isTransientWorkoutCameraLifecycleError(
        StateError('CameraController was disposed'),
      ),
      isTrue,
    );
    expect(
      isTransientWorkoutCameraLifecycleError(
        StateError('camera hardware error'),
      ),
      isFalse,
    );
  });
}
