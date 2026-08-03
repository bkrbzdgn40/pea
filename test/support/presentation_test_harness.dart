import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

enum PresentationTestViewport {
  compactPortrait(Size(320, 568)),
  standardPortrait(Size(390, 844)),
  compactLandscape(Size(568, 320)),
  standardLandscape(Size(844, 390)),
  expanded(Size(1024, 768));

  const PresentationTestViewport(this.logicalSize);

  final Size logicalSize;
}

@immutable
class PresentationTestConfiguration {
  const PresentationTestConfiguration({
    this.viewport = PresentationTestViewport.standardPortrait,
    this.textScaleFactor = 1,
    this.disableAnimations = false,
    this.accessibleNavigation = false,
    this.name,
  }) : assert(textScaleFactor > 0);

  final PresentationTestViewport viewport;
  final double textScaleFactor;
  final bool disableAnimations;
  final bool accessibleNavigation;
  final String? name;

  Size get logicalSize => viewport.logicalSize;

  String get label =>
      name ??
      '${viewport.name}-text-$textScaleFactor'
          '${disableAnimations ? '-reduced-motion' : ''}'
          '${accessibleNavigation ? '-accessible-navigation' : ''}';

  MediaQueryData applyTo(MediaQueryData base) {
    return base.copyWith(
      textScaler: TextScaler.linear(textScaleFactor),
      disableAnimations: disableAnimations,
      accessibleNavigation: accessibleNavigation,
    );
  }
}

abstract final class PresentationTestMatrix {
  static const List<PresentationTestConfiguration> critical = [
    PresentationTestConfiguration(
      viewport: PresentationTestViewport.compactPortrait,
    ),
    PresentationTestConfiguration(
      viewport: PresentationTestViewport.standardPortrait,
      textScaleFactor: 1.3,
    ),
    PresentationTestConfiguration(
      viewport: PresentationTestViewport.compactLandscape,
    ),
    PresentationTestConfiguration(
      viewport: PresentationTestViewport.standardLandscape,
    ),
    PresentationTestConfiguration(viewport: PresentationTestViewport.expanded),
    PresentationTestConfiguration(
      viewport: PresentationTestViewport.compactPortrait,
      textScaleFactor: 2,
      name: 'compact-portrait-large-text',
    ),
    PresentationTestConfiguration(
      viewport: PresentationTestViewport.standardPortrait,
      disableAnimations: true,
      name: 'standard-portrait-reduced-motion',
    ),
  ];
}

void configurePresentationTestView(
  WidgetTester tester,
  PresentationTestConfiguration configuration,
) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = configuration.logicalSize;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class PresentationTestMediaQuery extends StatelessWidget {
  const PresentationTestMediaQuery({
    super.key,
    required this.configuration,
    required this.child,
  });

  final PresentationTestConfiguration configuration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: configuration.applyTo(MediaQuery.of(context)),
      child: child,
    );
  }
}

void testWidgetsAcrossPresentationMatrix(
  String description,
  Iterable<PresentationTestConfiguration> configurations,
  Future<void> Function(
    WidgetTester tester,
    PresentationTestConfiguration configuration,
  )
  body,
) {
  for (final configuration in configurations) {
    testWidgets('$description [${configuration.label}]', (tester) async {
      await body(tester, configuration);
    });
  }
}

void expectNoPresentationExceptions(WidgetTester tester) {
  final exceptions = <Object>[];
  Object? exception = tester.takeException();
  while (exception != null) {
    exceptions.add(exception);
    exception = tester.takeException();
  }

  expect(
    exceptions,
    isEmpty,
    reason: exceptions.isEmpty
        ? null
        : 'Presentation produced layout or paint exceptions:\n'
              '${exceptions.join('\n\n')}',
  );
}
