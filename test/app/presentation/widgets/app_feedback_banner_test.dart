import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_feedback_banner.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_status_tone.dart';
import 'package:pose_estimation_app/app/theme/app_theme.dart';

void main() {
  testWidgets('shows semantic feedback and invokes its optional action', (
    WidgetTester tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AppFeedbackBanner(
            title: 'Kadraj uygun degil',
            message: 'Vucudunun tamami gorunecek kadar uzaklas.',
            tone: AppStatusTone.caution,
            actionLabel: 'Tekrar Kontrol Et',
            onAction: () => tapCount += 1,
          ),
        ),
      ),
    );

    expect(find.text('Kadraj uygun degil'), findsOneWidget);
    expect(
      find.text('Vucudunun tamami gorunecek kadar uzaklas.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    await tester.tap(find.text('Tekrar Kontrol Et'));
    await tester.pump();

    expect(tapCount, 1);
  });
}
