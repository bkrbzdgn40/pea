import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/guide_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('renders guide chrome and exercise copy in English', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const GuideScreen(),
      locale: const Locale('en'),
    );
    await tester.pump();

    expect(find.text('Exercise Guide'), findsOneWidget);
    expect(
      find.text(
        'A foundational movement for lower-body strength and knee-hip control.',
      ),
      findsOneWidget,
    );
    expect(find.text('Analysis active'), findsAtLeastNWidgets(1));
  });
}
