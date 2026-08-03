import 'package:flutter/material.dart';

import 'app_design_tokens.dart';
import 'app_semantic_colors.dart';

class AppTheme {
  const AppTheme._();

  static final ThemeData dark = _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    final base = ThemeData.dark();
    final colorScheme = base.colorScheme.copyWith(
      primary: AppColors.accent,
      onPrimary: Colors.black,
      secondary: AppColors.accent,
      onSecondary: Colors.black,
      error: AppColors.danger,
      onError: Colors.black,
      surface: AppColors.primarySurface,
      onSurface: AppColors.primaryForeground,
      outline: AppColors.surfaceBorder,
      outlineVariant: AppColors.subtleBorder,
    );
    final textTheme = _buildTextTheme(base.textTheme);
    final defaultInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.compact),
      borderSide: const BorderSide(color: AppColors.surfaceBorder),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.scaffoldBackground,
      canvasColor: AppColors.scaffoldBackground,
      cardColor: AppColors.primarySurface,
      dividerColor: AppColors.subtleBorder,
      shadowColor: Colors.black,
      disabledColor: AppColors.disabledForeground,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: const <ThemeExtension<dynamic>>[AppSemanticColors.dark],
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.scaffoldBackground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.primaryForeground,
        elevation: AppElevation.flat,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: AppColors.primarySurface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.flat,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.surface),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: AppColors.strongSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: AppColors.strongSurface,
        modalBackgroundColor: AppColors.strongSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.large),
          ),
        ),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: AppColors.strongSurface,
        contentTextStyle: textTheme.bodyMedium,
        actionTextColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.compact),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.secondarySurface,
        selectedColor: AppColors.analysisAccent.withValues(alpha: 0.16),
        disabledColor: AppColors.secondarySurface,
        side: const BorderSide(color: AppColors.surfaceBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: AppColors.secondarySurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: defaultInputBorder,
        enabledBorder: defaultInputBorder,
        focusedBorder: defaultInputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
        errorBorder: defaultInputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: defaultInputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.secondaryForeground,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.mutedForeground,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.secondarySurface,
          disabledForegroundColor: AppColors.disabledForeground,
          elevation: AppElevation.flat,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.compact),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.secondarySurface,
          disabledForegroundColor: AppColors.disabledForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.compact),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryForeground,
          disabledForegroundColor: AppColors.disabledForeground,
          side: const BorderSide(color: AppColors.surfaceBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.compact),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          disabledForegroundColor: AppColors.disabledForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.secondarySurface,
        circularTrackColor: AppColors.secondarySurface,
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: textTheme.labelMedium,
        decoration: BoxDecoration(
          color: AppColors.strongSurface,
          borderRadius: BorderRadius.circular(AppRadii.small),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        color: AppColors.primaryForeground,
      ),
      displayMedium: base.displayMedium?.copyWith(
        color: AppColors.primaryForeground,
      ),
      displaySmall: base.displaySmall?.copyWith(
        color: AppColors.primaryForeground,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        color: AppColors.primaryForeground,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: AppColors.primaryForeground,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        color: AppColors.primaryForeground,
      ),
      titleLarge: base.titleLarge?.copyWith(color: AppColors.primaryForeground),
      titleMedium: base.titleMedium?.copyWith(
        color: AppColors.primaryForeground,
      ),
      titleSmall: base.titleSmall?.copyWith(color: AppColors.primaryForeground),
      bodyLarge: base.bodyLarge?.copyWith(color: AppColors.primaryForeground),
      bodyMedium: base.bodyMedium?.copyWith(
        color: AppColors.secondaryForeground,
      ),
      bodySmall: base.bodySmall?.copyWith(color: AppColors.mutedForeground),
      labelLarge: base.labelLarge?.copyWith(color: AppColors.primaryForeground),
      labelMedium: base.labelMedium?.copyWith(
        color: AppColors.secondaryForeground,
      ),
      labelSmall: base.labelSmall?.copyWith(color: AppColors.mutedForeground),
    );
  }
}
