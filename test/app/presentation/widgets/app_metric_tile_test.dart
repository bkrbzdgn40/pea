import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_metric_tile.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_status_tone.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_surface_card.dart';
import 'package:pose_estimation_app/app/theme/app_theme.dart';

void main() {
  testWidgets('presents one metric with label, value and supporting context', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: AppMetricTile(
            label: 'Form Skoru',
            value: '89',
            supportingText: 'Son oturum',
            icon: Icons.insights_rounded,
            tone: AppStatusTone.success,
          ),
        ),
      ),
    );

    expect(find.text('Form Skoru'), findsOneWidget);
    expect(find.text('89'), findsOneWidget);
    expect(find.text('Son oturum'), findsOneWidget);
    expect(find.byIcon(Icons.insights_rounded), findsOneWidget);

    final surface = tester.widget<AppSurfaceCard>(find.byType(AppSurfaceCard));
    expect(surface.variant, AppSurfaceVariant.muted);
  });
}
