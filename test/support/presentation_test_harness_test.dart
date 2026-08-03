import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'presentation_test_harness.dart';
import 'presentation_test_support.dart';

void main() {
  testWidgets('applies viewport, text scale, and reduced-motion inputs', (
    WidgetTester tester,
  ) async {
    const configuration = PresentationTestConfiguration(
      viewport: PresentationTestViewport.compactLandscape,
      textScaleFactor: 2,
      disableAnimations: true,
      accessibleNavigation: true,
    );
    late MediaQueryData mediaQuery;

    await pumpTestApp(
      tester,
      configuration: configuration,
      home: Builder(
        builder: (context) {
          mediaQuery = MediaQuery.of(context);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(mediaQuery.size, configuration.logicalSize);
    expect(mediaQuery.textScaler.scale(10), 20);
    expect(mediaQuery.disableAnimations, isTrue);
    expect(mediaQuery.accessibleNavigation, isTrue);
    expectNoPresentationExceptions(tester);
  });

  test('critical matrix covers required layout and accessibility profiles', () {
    final configurations = PresentationTestMatrix.critical;

    expect(
      configurations.map((configuration) => configuration.viewport),
      containsAll(PresentationTestViewport.values),
    );
    expect(
      configurations.any((configuration) => configuration.textScaleFactor == 2),
      isTrue,
    );
    expect(
      configurations.any((configuration) => configuration.disableAnimations),
      isTrue,
    );
    expect(
      configurations.map((configuration) => configuration.label).toSet(),
      hasLength(configurations.length),
    );
  });
}
