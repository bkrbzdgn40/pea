import 'package:flutter/material.dart';

import '../../../../app/theme/app_semantic_colors.dart';

class MarketProductVisual extends StatelessWidget {
  const MarketProductVisual({
    super.key,
    required this.productId,
    this.imageAssetPath,
    this.iconSize = 48,
    this.semanticLabel,
  });

  final String productId;
  final String? imageAssetPath;
  final double iconSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Semantics(
      image: semanticLabel != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: ColoredBox(
        color: colors.analysisAccent.withValues(alpha: 0.08),
        child: imageAssetPath == null
            ? _FallbackProductIcon(productId: productId, iconSize: iconSize)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final devicePixelRatio = MediaQuery.devicePixelRatioOf(
                    context,
                  );
                  final logicalWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 512.0;
                  final cacheWidth = (logicalWidth * devicePixelRatio)
                      .round()
                      .clamp(1, 1024)
                      .toInt();

                  return RepaintBoundary(
                    child: Image.asset(
                      imageAssetPath!,
                      fit: BoxFit.contain,
                      cacheWidth: cacheWidth,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => _FallbackProductIcon(
                        productId: productId,
                        iconSize: iconSize,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _FallbackProductIcon extends StatelessWidget {
  const _FallbackProductIcon({required this.productId, required this.iconSize});

  final String productId;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Center(
      child: Icon(
        marketProductIcon(productId),
        size: iconSize,
        color: colors.analysisAccent,
      ),
    );
  }
}

IconData marketProductIcon(String productId) {
  return switch (productId) {
    'phone_tripod' => Icons.camera_alt_outlined,
    'exercise_mat' => Icons.self_improvement_rounded,
    'resistance_band_set' => Icons.fitness_center_rounded,
    'mini_loop_band_set' => Icons.link_rounded,
    'foam_roller' => Icons.view_week_outlined,
    'adjustable_dumbbell' => Icons.sports_gymnastics_rounded,
    'training_tshirt' => Icons.checkroom_rounded,
    'training_shorts' => Icons.dry_cleaning_outlined,
    _ => Icons.shopping_bag_outlined,
  };
}
