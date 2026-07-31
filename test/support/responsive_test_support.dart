import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

@immutable
class TestViewport {
  const TestViewport({
    required this.size,
    this.devicePixelRatio = 1,
    this.textScaler = TextScaler.noScaling,
  });

  static const compactPortrait = TestViewport(size: Size(320, 568));
  static const standardPortrait = TestViewport(size: Size(390, 844));
  static const compactLandscape = TestViewport(size: Size(568, 320));
  static const standardLandscape = TestViewport(size: Size(844, 390));
  static const tabletPortrait = TestViewport(size: Size(768, 1024));
  static const tabletLandscape = TestViewport(size: Size(1024, 768));

  final Size size;
  final double devicePixelRatio;
  final TextScaler textScaler;

  TestViewport copyWith({
    Size? size,
    double? devicePixelRatio,
    TextScaler? textScaler,
  }) {
    return TestViewport(
      size: size ?? this.size,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
      textScaler: textScaler ?? this.textScaler,
    );
  }

  Widget wrap(Widget child) {
    return Builder(
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child,
        );
      },
    );
  }
}

void configureTestViewport(WidgetTester tester, TestViewport viewport) {
  tester.view.physicalSize = viewport.size * viewport.devicePixelRatio;
  tester.view.devicePixelRatio = viewport.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
