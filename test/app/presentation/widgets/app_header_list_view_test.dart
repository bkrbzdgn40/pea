import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/layout/app_layout.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_header_list_view.dart';

import '../../../support/presentation_test_harness.dart';
import '../../../support/presentation_test_support.dart';

void main() {
  testWidgets('uses viewport-aware page padding by default', (
    WidgetTester tester,
  ) async {
    const configuration = PresentationTestConfiguration(
      viewport: PresentationTestViewport.compactLandscape,
    );

    await pumpTestApp(
      tester,
      configuration: configuration,
      home: Scaffold(
        body: AppHeaderListView<int>(
          header: const Text('Header'),
          items: const <int>[1],
          itemBuilder: (_, item) => Text('Item $item'),
          emptyState: const Text('Empty'),
        ),
      ),
    );

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(
      listView.padding,
      AppLayout.fromSize(configuration.logicalSize).pagePadding,
    );
  });
}
