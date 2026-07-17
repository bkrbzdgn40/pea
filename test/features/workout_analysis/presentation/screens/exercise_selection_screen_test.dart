import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/camera_permission_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/exercise_selection_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          switch (call.method) {
            case 'checkPermissionStatus':
              return 0;
            case 'checkServiceStatus':
              return 1;
          }
          return 0;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  testWidgets('sit-up card is analysis-active and starts the permission flow', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final observer = RecordingNavigatorObserver();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: const ExerciseSelectionScreen(),
          navigatorObservers: <NavigatorObserver>[observer],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final pushCountBeforeTap = observer.pushCount;

    await tester.scrollUntilVisible(find.text('Sit-up'), 300);
    await tester.pumpAndSettle();

    expect(find.text('Sit-up'), findsOneWidget);
    expect(find.text('Analiz aktif'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Sit-up'));
    await tester.pump();
    await tester.pump();

    expect(observer.pushCount, pushCountBeforeTap + 1);
    expect(container.read(selectedExerciseProvider), ExerciseType.sitUp);
    expect(find.byType(CameraPermissionScreen), findsOneWidget);
  });

  testWidgets(
    'hollow hold card is analysis-active and starts the permission flow',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final observer = RecordingNavigatorObserver();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const ExerciseSelectionScreen(),
            navigatorObservers: <NavigatorObserver>[observer],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final pushCountBeforeTap = observer.pushCount;

      await tester.scrollUntilVisible(find.text('Hollow Hold'), 300);
      await tester.pumpAndSettle();

      expect(find.text('Hollow Hold'), findsOneWidget);
      expect(find.text('Analiz aktif'), findsAtLeastNWidgets(1));

      await tester.tap(find.text('Hollow Hold'));
      await tester.pump();
      await tester.pump();

      expect(observer.pushCount, pushCountBeforeTap + 1);
      expect(container.read(selectedExerciseProvider), ExerciseType.hollowHold);
      expect(find.byType(CameraPermissionScreen), findsOneWidget);
    },
  );

  testWidgets('lunge remains unsupported and only shows the guide snackbar', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final observer = RecordingNavigatorObserver();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: const ExerciseSelectionScreen(),
          navigatorObservers: <NavigatorObserver>[observer],
        ),
      ),
    );
    await tester.pump();

    final pushCountBeforeTap = observer.pushCount;

    await tester.tap(find.text('Lunge'));
    await tester.pump();

    expect(observer.pushCount, pushCountBeforeTap);
    expect(container.read(selectedExerciseProvider), isNull);
    expect(find.textContaining('rehber'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets(
    'biceps curl card is analysis-active and starts the permission flow',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final observer = RecordingNavigatorObserver();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const ExerciseSelectionScreen(),
            navigatorObservers: <NavigatorObserver>[observer],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final pushCountBeforeTap = observer.pushCount;

      await tester.scrollUntilVisible(find.text('Biceps Curl'), 300);
      await tester.pumpAndSettle();

      expect(find.text('Biceps Curl'), findsOneWidget);
      expect(find.text('Analiz aktif'), findsAtLeastNWidgets(1));

      await tester.tap(find.text('Biceps Curl'));
      await tester.pump();
      await tester.pump();

      expect(observer.pushCount, pushCountBeforeTap + 1);
      expect(container.read(selectedExerciseProvider), ExerciseType.bicepsCurl);
      expect(find.byType(CameraPermissionScreen), findsOneWidget);
    },
  );
}
