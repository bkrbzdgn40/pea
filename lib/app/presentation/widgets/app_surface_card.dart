import 'package:flutter/material.dart';

import '../../theme/app_design_tokens.dart';

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.surfacePadding,
    this.color = AppColors.primarySurface,
    this.borderColor = AppColors.surfaceBorder,
    this.radius = AppRadii.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}
