import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/core/orientation/app_display_orientation.dart';

void main() {
  test(
    'maps viewport orientation to the two supported device orientations',
    () {
      expect(
        appDeviceOrientationFor(Orientation.portrait),
        DeviceOrientation.portraitUp,
      );
      expect(
        appDeviceOrientationFor(Orientation.landscape),
        DeviceOrientation.landscapeLeft,
      );
    },
  );
}
