import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_surface_card.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';

void main() {
  testWidgets('renders its child with the default surface contract', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AppSurfaceCard(child: Text('surface-child')),
      ),
    );

    expect(find.text('surface-child'), findsOneWidget);

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border! as Border;

    expect(decoration.color, AppColors.primarySurface);
    expect(decoration.borderRadius, BorderRadius.circular(AppRadii.surface));
    expect(border.top.color, AppColors.surfaceBorder);
  });

  testWidgets('applies custom border color and radius when provided', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AppSurfaceCard(
          borderColor: Colors.red,
          radius: 20,
          child: Text('custom-surface'),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border! as Border;

    expect(border.top.color, Colors.red);
    expect(decoration.borderRadius, BorderRadius.circular(20));
  });

  testWidgets('resolves semantic surface variants without custom colors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AppSurfaceCard(
          variant: AppSurfaceVariant.accent,
          child: Text('accent-surface'),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border! as Border;

    expect(
      decoration.color,
      AppColors.analysisAccent.withValues(alpha: AppOpacity.subtle),
    );
    expect(
      border.top.color,
      AppColors.analysisAccent.withValues(alpha: AppOpacity.strongBorder),
    );
  });
}
