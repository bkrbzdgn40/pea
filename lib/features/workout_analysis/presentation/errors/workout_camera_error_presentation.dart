import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../../../../app/localization/app_localizations.dart';

enum WorkoutCameraErrorKind { permission, inUse, unavailable }

class WorkoutCameraErrorPresentation {
  const WorkoutCameraErrorPresentation({
    required this.kind,
    required this.message,
    required this.actionLabel,
  });

  final WorkoutCameraErrorKind kind;
  final String message;
  final String actionLabel;

  bool get requiresPermissionAction =>
      kind == WorkoutCameraErrorKind.permission;
}

WorkoutCameraErrorPresentation presentWorkoutCameraError({
  required Object error,
  required AppLocalizations localizations,
}) {
  final kind = classifyWorkoutCameraError(error);

  return switch (kind) {
    WorkoutCameraErrorKind.permission => WorkoutCameraErrorPresentation(
      kind: kind,
      message: localizations.cameraPermissionFallbackBody,
      actionLabel: localizations.checkPermission,
    ),
    WorkoutCameraErrorKind.inUse => WorkoutCameraErrorPresentation(
      kind: kind,
      message: localizations.cameraInUseMessage,
      actionLabel: localizations.retry,
    ),
    WorkoutCameraErrorKind.unavailable => WorkoutCameraErrorPresentation(
      kind: kind,
      message: localizations.cameraStartFailedMessage,
      actionLabel: localizations.retry,
    ),
  };
}

WorkoutCameraErrorKind classifyWorkoutCameraError(Object error) {
  final code = switch (error) {
    CameraException(:final code) => code,
    PlatformException(:final code) => code,
    _ => '',
  };
  final normalized = '$code ${error.toString()}'.toLowerCase();

  if (_containsAny(normalized, const <String>[
    'camerapermission',
    'cameraaccessdenied',
    'accessdenied',
    'permission denied',
    'permission missing',
    'restricted',
  ])) {
    return WorkoutCameraErrorKind.permission;
  }

  if (_containsAny(normalized, const <String>[
    'camerainuse',
    'camera_in_use',
    'camera in use',
    'camera busy',
    'maxcamerasinuse',
    'max_cameras_in_use',
    'already in use',
    'another application',
    'another app',
  ])) {
    return WorkoutCameraErrorKind.inUse;
  }

  return WorkoutCameraErrorKind.unavailable;
}

bool isTransientWorkoutCameraLifecycleError(Object error) {
  final message = error.toString().toLowerCase();

  return _containsAny(message, const <String>[
    'dispose',
    'disposed',
    'controller',
    'initialize',
    'camera is closed',
    'camera closed',
  ]);
}

bool _containsAny(String value, List<String> candidates) {
  return candidates.any(value.contains);
}
