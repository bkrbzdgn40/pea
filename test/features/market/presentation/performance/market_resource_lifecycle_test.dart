import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/market/application/repositories/market_catalog_repository.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_category.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_product.dart';
import 'package:pose_estimation_app/features/market/domain/models/money.dart';
import 'package:pose_estimation_app/features/market/presentation/providers/market_catalog_provider.dart';
import 'package:pose_estimation_app/features/market/presentation/screens/market_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('loads catalog only while the market route is active', (
    WidgetTester tester,
  ) async {
    final repository = _CountingMarketCatalogRepository();

    await pumpTestApp(
      tester,
      home: const _MarketLifecycleHost(),
      overrides: <Override>[
        marketCatalogRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();

    expect(repository.loadCount, 0);

    await tester.tap(find.byKey(const Key('open-market-route')));
    await tester.pumpAndSettle();

    expect(repository.loadCount, 1);

    final mobilityFilter = find.text('Mobilite');
    await tester.ensureVisible(mobilityFilter);
    await tester.tap(mobilityFilter);
    await tester.pumpAndSettle();

    expect(find.text('Foam Roller'), findsOneWidget);
    expect(find.text('Telefon Tripodu'), findsNothing);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pop();
    await tester.pumpAndSettle();

    expect(find.byType(MarketScreen), findsNothing);

    await tester.tap(find.byKey(const Key('open-market-route')));
    await tester.pumpAndSettle();

    expect(repository.loadCount, 2);
    expect(find.text('Telefon Tripodu'), findsOneWidget);
    expect(find.text('Foam Roller'), findsOneWidget);
  });

  testWidgets('keeps only the lightweight cart state between market visits', (
    WidgetTester tester,
  ) async {
    final repository = _CountingMarketCatalogRepository();

    await pumpTestApp(
      tester,
      home: const _MarketLifecycleHost(),
      overrides: <Override>[
        marketCatalogRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-market-route')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('market-product-phone_tripod')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('market-add-to-cart')));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-market-route')));
    await tester.pumpAndSettle();

    final badge = find.byKey(const Key('market-cart-count-badge'));
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('1')),
      findsOneWidget,
    );
    expect(repository.loadCount, 2);
  });
}

class _MarketLifecycleHost extends StatelessWidget {
  const _MarketLifecycleHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('open-market-route'),
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const MarketScreen()),
            );
          },
          child: const Text('Open market'),
        ),
      ),
    );
  }
}

class _CountingMarketCatalogRepository implements MarketCatalogRepository {
  int loadCount = 0;

  @override
  Future<List<MarketProduct>> loadProducts() async {
    loadCount += 1;
    return _products;
  }

  static const List<MarketProduct> _products = <MarketProduct>[
    MarketProduct(
      id: 'phone_tripod',
      category: MarketCategory.setup,
      price: Money(minorUnits: 79900, currencyCode: 'TRY'),
    ),
    MarketProduct(
      id: 'foam_roller',
      category: MarketCategory.mobility,
      price: Money(minorUnits: 54900, currencyCode: 'TRY'),
    ),
  ];
}
