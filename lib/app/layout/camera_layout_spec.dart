import 'package:flutter/material.dart';
import 'package:pose_estimation_app/app/layout/app_layout.dart';

enum AppCameraLayoutMode { stacked, sidePanel }

class AppCameraLayoutBreakpoints {
  const AppCameraLayoutBreakpoints._();

  static const double minimumSplitWidth = 560;
  static const double minimumSplitHeight = 280;
  static const double minimumCameraPaneWidth = 280;
  static const double minimumSidePanelWidth = 240;
  static const double maximumSidePanelWidth = 360;
  static const double preferredSidePanelFraction = 0.34;
}

/// Resolves the outer composition for camera-first screens.
///
/// Pose/camera coordinate transforms remain owned by the camera surface. This
/// contract only decides whether supporting UI belongs below the preview or in
/// a trailing panel, so screens do not invent incompatible breakpoints.
@immutable
class AppCameraLayoutSpec {
  const AppCameraLayoutSpec._({
    required this.mode,
    required this.outerPadding,
    required this.gap,
    required this.sidePanelWidth,
  });

  factory AppCameraLayoutSpec.resolve({
    required AppLayout layout,
    required BoxConstraints constraints,
  }) {
    final maxWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : layout.viewportSize.width;
    final maxHeight = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : layout.viewportSize.height;
    final outerPadding = layout.cameraPadding;
    final gap = layout.panelGap;
    final usableWidth = maxWidth - outerPadding.horizontal - gap;

    final canSplit =
        maxWidth > maxHeight &&
        maxWidth >= AppCameraLayoutBreakpoints.minimumSplitWidth &&
        maxHeight >= AppCameraLayoutBreakpoints.minimumSplitHeight &&
        usableWidth >=
            AppCameraLayoutBreakpoints.minimumCameraPaneWidth +
                AppCameraLayoutBreakpoints.minimumSidePanelWidth;

    if (!canSplit) {
      return AppCameraLayoutSpec._(
        mode: AppCameraLayoutMode.stacked,
        outerPadding: outerPadding,
        gap: layout.sectionGap,
        sidePanelWidth: null,
      );
    }

    final preferredPanelWidth =
        usableWidth * AppCameraLayoutBreakpoints.preferredSidePanelFraction;
    final maximumAllowedPanelWidth =
        usableWidth - AppCameraLayoutBreakpoints.minimumCameraPaneWidth;
    final sidePanelWidth = preferredPanelWidth
        .clamp(
          AppCameraLayoutBreakpoints.minimumSidePanelWidth,
          AppCameraLayoutBreakpoints.maximumSidePanelWidth,
        )
        .clamp(
          AppCameraLayoutBreakpoints.minimumSidePanelWidth,
          maximumAllowedPanelWidth,
        )
        .toDouble();

    return AppCameraLayoutSpec._(
      mode: AppCameraLayoutMode.sidePanel,
      outerPadding: outerPadding,
      gap: gap,
      sidePanelWidth: sidePanelWidth,
    );
  }

  final AppCameraLayoutMode mode;
  final EdgeInsets outerPadding;
  final double gap;
  final double? sidePanelWidth;

  bool get usesSidePanel => mode == AppCameraLayoutMode.sidePanel;
}
