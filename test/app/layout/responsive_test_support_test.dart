import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/layout/app_layout.dart';

import '../../support/responsive_test_support.dart';

void main() {
  testWidgets('shared viewport profile applies size and text scaling', (
    tester,
  ) async {
    final viewport = TestViewport.compactLandscape.copyWith(
      textScaler: const TextScaler.linear(2),
    );
    configureTestViewport(tester, viewport);

    await tester.pumpWidget(
      MaterialApp(
        home: viewport.wrap(
          Builder(
            builder: (context) {
              final layout = AppLayout.of(context);
              return Text('${layout.size.name}:${layout.textScaleFactor}');
            },
          ),
        ),
      ),
    );

    expect(find.text('compactLandscape:2.0'), findsOneWidget);
  });
}
