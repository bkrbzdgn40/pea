import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/layout/app_layout.dart';
import 'package:pose_estimation_app/app/layout/camera_layout_spec.dart';

void main() {
  group('AppCameraLayoutSpec', () {
    test('keeps portrait camera screens stacked', () {
      final spec = AppCameraLayoutSpec.resolve(
        layout: AppLayout.fromSize(const Size(390, 844)),
        constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      );

      expect(spec.mode, AppCameraLayoutMode.stacked);
      expect(spec.sidePanelWidth, isNull);
      expect(spec.gap, 12);
    });

    test('uses a side panel on compact landscape without starving camera', () {
      const viewport = Size(568, 320);
      final layout = AppLayout.fromSize(viewport);
      final spec = AppCameraLayoutSpec.resolve(
        layout: layout,
        constraints: BoxConstraints.tightFor(
          width: viewport.width,
          height: viewport.height,
        ),
      );

      expect(spec.mode, AppCameraLayoutMode.sidePanel);
      expect(spec.sidePanelWidth, 240);

      final cameraWidth =
          viewport.width -
          spec.outerPadding.horizontal -
          spec.gap -
          spec.sidePanelWidth!;
      expect(
        cameraWidth,
        greaterThanOrEqualTo(AppCameraLayoutBreakpoints.minimumCameraPaneWidth),
      );
    });

    test('uses the same contract for wider landscape viewports', () {
      const viewport = Size(1024, 768);
      final spec = AppCameraLayoutSpec.resolve(
        layout: AppLayout.fromSize(viewport),
        constraints: BoxConstraints.tightFor(
          width: viewport.width,
          height: viewport.height,
        ),
      );

      expect(spec.usesSidePanel, isTrue);
      expect(
        spec.sidePanelWidth,
        inInclusiveRange(
          AppCameraLayoutBreakpoints.minimumSidePanelWidth,
          AppCameraLayoutBreakpoints.maximumSidePanelWidth,
        ),
      );
    });

    test('resolves orientation from available constraints', () {
      const viewport = Size(768, 1024);
      final spec = AppCameraLayoutSpec.resolve(
        layout: AppLayout.fromSize(viewport),
        constraints: const BoxConstraints.tightFor(width: 700, height: 320),
      );

      expect(spec.mode, AppCameraLayoutMode.sidePanel);
    });

    test('falls back to stacked layout when split height is unsafe', () {
      const viewport = Size(700, 260);
      final spec = AppCameraLayoutSpec.resolve(
        layout: AppLayout.fromSize(viewport),
        constraints: BoxConstraints.tightFor(
          width: viewport.width,
          height: viewport.height,
        ),
      );

      expect(spec.mode, AppCameraLayoutMode.stacked);
      expect(spec.sidePanelWidth, isNull);
    });
  });
}
