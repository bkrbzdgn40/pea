import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/layout/app_layout.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_scaffold_shell.dart';

import '../../../support/presentation_test_harness.dart';
import '../../../support/presentation_test_support.dart';

void main() {
  testWidgets('renders title, body, actions, drawer, and responsive padding', (
    WidgetTester tester,
  ) async {
    const bodyKey = Key('shell-body');
    const configuration = PresentationTestConfiguration(
      viewport: PresentationTestViewport.standardPortrait,
    );

    await pumpTestApp(
      tester,
      configuration: configuration,
      home: const AppScaffoldShell(
        title: 'Kabuk',
        currentPage: AppDestination.howToUse,
        actions: [Icon(Icons.add)],
        body: SizedBox(key: bodyKey),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kabuk'), findsOneWidget);
    expect(find.byKey(bodyKey), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    final materialLocalizations = MaterialLocalizations.of(
      tester.element(find.byType(AppScaffoldShell)),
    );
    expect(
      find.byTooltip(materialLocalizations.openAppDrawerTooltip),
      findsOneWidget,
    );

    final expectedPadding = AppLayout.fromSize(
      configuration.logicalSize,
    ).pagePadding;
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Padding && widget.padding == expectedPadding,
      ),
      findsOneWidget,
    );
  });

  testWidgets('honors explicit edge-to-edge padding', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const AppScaffoldShell(
        title: 'Edge to edge',
        padding: EdgeInsets.zero,
        body: SizedBox.shrink(),
      ),
    );
    await tester.pumpAndSettle();

    final contentPadding = tester.widget<Padding>(
      find.byKey(AppScaffoldShell.contentPaddingKey),
    );
    expect(contentPadding.padding, EdgeInsets.zero);
  });

  testWidgets('omits the drawer menu when showDrawer is false', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const AppScaffoldShell(
        title: 'No Drawer',
        showDrawer: false,
        body: SizedBox.shrink(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Drawer'), findsOneWidget);
    final materialLocalizations = MaterialLocalizations.of(
      tester.element(find.byType(AppScaffoldShell)),
    );
    expect(
      find.byTooltip(materialLocalizations.openAppDrawerTooltip),
      findsNothing,
    );
  });
}
