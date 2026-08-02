import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_analysis_failure_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/workout_analysis_health_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_analysis_health_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/live_analysis/workout_analysis_failure_overlay.dart';

void main() {
  testWidgets('blocked timeout shows a retryable safety overlay', (
    tester,
  ) async {
    final container = ProviderContainer();
    final healthSubscription = container.listen<WorkoutAnalysisHealthState>(
      workoutAnalysisHealthControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(() {
      healthSubscription.close();
      container.dispose();
    });
    container
        .read(workoutAnalysisHealthControllerProvider.notifier)
        .publish(
          const WorkoutAnalysisFailureDecision(
            kind: WorkoutAnalysisFailureKind.poseDetectionTimeout,
            disposition: WorkoutAnalysisFailureDisposition.blocked,
            consecutiveFailureCount: 1,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('tr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Stack(children: <Widget>[WorkoutAnalysisFailureOverlay()]),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('workout-analysis-failure-overlay')),
      findsOneWidget,
    );
    expect(find.text('Analiz durduruldu'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('workout-analysis-retry-button')),
      findsOneWidget,
    );
  });

  testWidgets('recovering failure does not expose retry yet', (tester) async {
    final container = ProviderContainer();
    final healthSubscription = container.listen<WorkoutAnalysisHealthState>(
      workoutAnalysisHealthControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(() {
      healthSubscription.close();
      container.dispose();
    });
    container
        .read(workoutAnalysisHealthControllerProvider.notifier)
        .publish(
          const WorkoutAnalysisFailureDecision(
            kind: WorkoutAnalysisFailureKind.processingException,
            disposition: WorkoutAnalysisFailureDisposition.recovering,
            consecutiveFailureCount: 1,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Stack(children: <Widget>[WorkoutAnalysisFailureOverlay()]),
          ),
        ),
      ),
    );

    expect(find.text('Recovering analysis'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('workout-analysis-retry-button')),
      findsNothing,
    );
  });
}
