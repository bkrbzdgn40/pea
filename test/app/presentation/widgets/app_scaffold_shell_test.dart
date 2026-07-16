import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_scaffold_shell.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';

import '../../../support/presentation_test_support.dart';

void main() {
  testWidgets('renders title, body, actions, drawer, and default padding', (
    WidgetTester tester,
  ) async {
    const bodyKey = Key('shell-body');

    await pumpTestApp(
      tester,
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
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Padding && widget.padding == AppSpacing.pagePadding,
      ),
      findsOneWidget,
    );
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
    expect(find.byTooltip('Open navigation menu'), findsNothing);
  });
}
