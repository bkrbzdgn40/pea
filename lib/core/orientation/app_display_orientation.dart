import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Maps the rendered viewport to the only two physical orientations supported
/// by the app. Camera analysis must follow this committed display orientation
/// instead of reacting to raw sensor changes during the stability delay.
DeviceOrientation appDeviceOrientationFor(Orientation viewportOrientation) {
  return switch (viewportOrientation) {
    Orientation.portrait => DeviceOrientation.portraitUp,
    Orientation.landscape => DeviceOrientation.landscapeLeft,
  };
}
