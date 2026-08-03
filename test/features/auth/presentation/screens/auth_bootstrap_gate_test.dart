import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_state_views.dart';
import 'package:pose_estimation_app/features/auth/presentation/providers/auth_bootstrap_provider.dart';
import 'package:pose_estimation_app/features/auth/presentation/screens/auth_bootstrap_gate.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('loading state uses the shared root state shell', (
    WidgetTester tester,
  ) async {
    final completer = Completer<AuthBootstrapState>();

    await pumpTestApp(
      tester,
      home: const AuthBootstrapGate(),
      overrides: [
        authBootstrapProvider.overrideWith((ref) => completer.future),
      ],
    );
    await tester.pump();

    expect(find.byType(AppRootStateScaffold), findsOneWidget);
    expect(find.byType(AppLoadingView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state stays usable with compact large text', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const AuthBootstrapGate(),
      configuration: const PresentationTestConfiguration(
        viewport: PresentationTestViewport.compactPortrait,
        textScaleFactor: 2,
      ),
      overrides: [
        authBootstrapProvider.overrideWith(
          (ref) async => const AuthBootstrapState.error('bootstrap failed'),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppRootStateScaffold), findsOneWidget);
    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    expectNoPresentationExceptions(tester);
  });
}
