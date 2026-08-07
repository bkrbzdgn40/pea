import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/theme/app_semantic_colors.dart';
import 'package:pose_estimation_app/app/theme/app_theme.dart';

void main() {
  test('production theme is explicitly dark and keeps readable contrast', () {
    final theme = AppTheme.dark;
    final colors = theme.extension<AppSemanticColors>();

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(colors, isNotNull);

    final semantic = colors!;
    expect(
      _contrastRatio(semantic.foreground, semantic.surface),
      greaterThan(7),
    );
    expect(
      _contrastRatio(semantic.foregroundMuted, semantic.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(semantic.foregroundSubtle, semantic.surface),
      greaterThanOrEqualTo(4.5),
    );
  });
}

double _contrastRatio(Color first, Color second) {
  final opaqueFirst = Color.alphaBlend(first, second);
  final firstLuminance = opaqueFirst.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
