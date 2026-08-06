import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/market/application/repositories/market_catalog_repository.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_category.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_product.dart';
import 'package:pose_estimation_app/features/market/domain/models/money.dart';
import 'package:pose_estimation_app/features/market/presentation/providers/market_catalog_provider.dart';
import 'package:pose_estimation_app/features/market/presentation/screens/market_screen.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('renders the Turkish local preview catalog', (
    WidgetTester tester,
  ) async {
    await _pumpMarketCatalog(tester);

    expect(find.text('Market'), findsOneWidget);
    expect(find.text('Antrenmanını destekleyen ekipmanlar'), findsNothing);
    expect(find.text('8 örnek ürün'), findsNothing);
    expect(find.text('Telefon Tripodu'), findsOneWidget);
    expect(find.text('Giyim'), findsOneWidget);
    expect(find.text('Tümü'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(
      find.byKey(const Key('market-category-filter-surface')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('market-product-visual-frame-phone_tripod')),
      findsOneWidget,
    );
    expect(find.text('Öne çıkan'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows a lightweight loading state while catalog data is read', (
    WidgetTester tester,
  ) async {
    final repository = _DeferredMarketCatalogRepository();

    await pumpTestApp(
      tester,
      locale: const Locale('tr'),
      overrides: [
        marketCatalogRepositoryProvider.overrideWithValue(repository),
      ],
      home: const MarketScreen(),
    );
    await tester.pump();

    expect(find.byKey(const Key('market-catalog-loading')), findsOneWidget);
    expect(find.text('Ürünler hazırlanıyor...'), findsOneWidget);

    repository.complete(_testProducts);
    await tester.pumpAndSettle();

    expect(find.text('Telefon Tripodu'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows a retryable error when the catalog contract cannot load', (
    WidgetTester tester,
  ) async {
    final repository = _FailingMarketCatalogRepository();

    await pumpTestApp(
      tester,
      locale: const Locale('tr'),
      overrides: [
        marketCatalogRepositoryProvider.overrideWithValue(repository),
      ],
      home: const MarketScreen(),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('market-catalog-error')), findsOneWidget);
    expect(find.text('Market kataloğu açılamadı'), findsOneWidget);
    expect(repository.loadCount, 1);

    await tester.tap(find.byKey(const Key('market-catalog-retry')));
    await tester.pumpAndSettle();

    expect(repository.loadCount, 2);
  });

  testWidgets('keeps catalog cards focused on name and price', (
    WidgetTester tester,
  ) async {
    await _pumpMarketCatalog(tester);

    final phoneCard = find.byKey(const ValueKey('market-product-phone_tripod'));

    expect(phoneCard, findsOneWidget);
    expect(
      find.descendant(of: phoneCard, matching: find.text('Telefon Tripodu')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: phoneCard,
        matching: find.text(
          'Kamerayı sabit tutarak analiz kadrajını daha kolay korumana yardımcı olur.',
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: phoneCard, matching: find.text('Kamera ve Kurulum')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: phoneCard,
        matching: find.text('Şablon ürün · Satış aktif değil'),
      ),
      findsNothing,
    );
  });

  testWidgets('shows the apparel templates in the clothing category', (
    WidgetTester tester,
  ) async {
    await _pumpMarketCatalog(tester);

    final apparelFilter = find.text('Giyim');
    await tester.ensureVisible(apparelFilter);
    await tester.pumpAndSettle();
    await tester.tap(apparelFilter);
    await tester.pumpAndSettle();

    expect(find.text('Antrenman Tişörtü'), findsOneWidget);
    expect(find.text('Antrenman Şortu'), findsOneWidget);
    expect(find.text('Telefon Tripodu'), findsNothing);
  });

  testWidgets('filters products by category without loading another service', (
    WidgetTester tester,
  ) async {
    await _pumpMarketCatalog(tester);

    await tester.tap(find.text('Mobilite'));
    await tester.pumpAndSettle();

    expect(find.text('Foam Roller'), findsOneWidget);
    expect(find.text('Telefon Tripodu'), findsNothing);
    expect(find.text('Ayarlanabilir Dambıl'), findsNothing);
  });

  testWidgets('marks Market as the selected drawer destination', (
    WidgetTester tester,
  ) async {
    await _pumpMarketCatalog(tester);

    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();

    final marketTileFinder = find.widgetWithText(ListTile, 'Market');
    final drawerScrollable = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    );

    expect(drawerScrollable, findsOneWidget);
    await tester.scrollUntilVisible(
      marketTileFinder,
      180,
      scrollable: drawerScrollable,
    );
    await tester.pumpAndSettle();

    final marketTile = tester.widget<ListTile>(marketTileFinder);
    expect(marketTile.selected, isTrue);
  });

  testWidgets('uses a two-column lazy grid on an expanded viewport', (
    WidgetTester tester,
  ) async {
    await _pumpMarketCatalog(
      tester,
      configuration: const PresentationTestConfiguration(
        viewport: PresentationTestViewport.expanded,
      ),
    );

    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.crossAxisCount, 2);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('keeps two columns on a compact viewport with large text', (
    WidgetTester tester,
  ) async {
    await _pumpMarketCatalog(
      tester,
      configuration: const PresentationTestConfiguration(
        viewport: PresentationTestViewport.compactPortrait,
        textScaleFactor: 2,
      ),
    );

    expect(find.text('Antrenmanını destekleyen ekipmanlar'), findsNothing);
    expect(find.byKey(const Key('market-catalog-scroll-view')), findsOneWidget);

    final catalogScrollable = find.descendant(
      of: find.byKey(const Key('market-catalog-scroll-view')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(catalogScrollable, findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('market-product-phone_tripod')),
      200,
      scrollable: catalogScrollable,
    );
    await tester.pumpAndSettle();

    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.crossAxisCount, 2);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('opens a product detail and returns to the catalog', (
    WidgetTester tester,
  ) async {
    await _pumpMarketCatalog(tester);

    await tester.tap(find.byKey(const ValueKey('market-product-phone_tripod')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('market-product-detail-phone_tripod')),
      findsOneWidget,
    );
    expect(find.text('Ürün bilgisi'), findsOneWidget);
    expect(
      find.text(
        'Kamerayı sabit tutarak analiz kadrajını daha kolay korumana yardımcı olur.',
      ),
      findsOneWidget,
    );

    final backButton = find.byType(BackButton);
    expect(backButton, findsOneWidget);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.text('Telefon Tripodu'), findsOneWidget);
    expect(find.text('Antrenmanını destekleyen ekipmanlar'), findsNothing);
  });
}

Future<void> _pumpMarketCatalog(
  WidgetTester tester, {
  PresentationTestConfiguration? configuration,
}) async {
  await pumpTestApp(
    tester,
    locale: const Locale('tr'),
    configuration: configuration,
    overrides: [
      marketCatalogRepositoryProvider.overrideWithValue(
        const _ImmediateMarketCatalogRepository(),
      ),
    ],
    home: const MarketScreen(),
  );

  // Do not use pumpAndSettle while the indeterminate loading indicator is
  // mounted. Two finite pumps flush the completed FutureProvider and render
  // the deterministic in-memory catalog without waiting on spinner frames.
  await tester.pump();
  await tester.pump();

  expect(find.byKey(const Key('market-catalog-loading')), findsNothing);
}

const List<MarketProduct> _previewProducts = <MarketProduct>[
  MarketProduct(
    id: 'phone_tripod',
    imageAssetPath: 'assets/market/products/phone_tripod.webp',
    category: MarketCategory.setup,
    price: Money(minorUnits: 79900, currencyCode: 'TRY'),
    isFeatured: true,
  ),
  MarketProduct(
    id: 'exercise_mat',
    imageAssetPath: 'assets/market/products/exercise_mat.webp',
    category: MarketCategory.accessories,
    price: Money(minorUnits: 64900, currencyCode: 'TRY'),
  ),
  MarketProduct(
    id: 'resistance_band_set',
    imageAssetPath: 'assets/market/products/resistance_band_set.webp',
    category: MarketCategory.strength,
    price: Money(minorUnits: 49900, currencyCode: 'TRY'),
    isFeatured: true,
  ),
  MarketProduct(
    id: 'mini_loop_band_set',
    imageAssetPath: 'assets/market/products/mini_loop_band_set.webp',
    category: MarketCategory.strength,
    price: Money(minorUnits: 27900, currencyCode: 'TRY'),
  ),
  MarketProduct(
    id: 'foam_roller',
    imageAssetPath: 'assets/market/products/foam_roller.webp',
    category: MarketCategory.mobility,
    price: Money(minorUnits: 54900, currencyCode: 'TRY'),
  ),
  MarketProduct(
    id: 'adjustable_dumbbell',
    imageAssetPath: 'assets/market/products/adjustable_dumbbell.webp',
    category: MarketCategory.strength,
    price: Money(minorUnits: 249900, currencyCode: 'TRY'),
  ),
  MarketProduct(
    id: 'training_tshirt',
    imageAssetPath: 'assets/market/products/training_tshirt.webp',
    category: MarketCategory.apparel,
    price: Money(minorUnits: 44900, currencyCode: 'TRY'),
  ),
  MarketProduct(
    id: 'training_shorts',
    imageAssetPath: 'assets/market/products/training_shorts.webp',
    category: MarketCategory.apparel,
    price: Money(minorUnits: 39900, currencyCode: 'TRY'),
  ),
];

class _ImmediateMarketCatalogRepository implements MarketCatalogRepository {
  const _ImmediateMarketCatalogRepository();

  @override
  Future<List<MarketProduct>> loadProducts() async => _previewProducts;
}

const List<MarketProduct> _testProducts = <MarketProduct>[
  MarketProduct(
    id: 'phone_tripod',
    imageAssetPath: 'assets/market/products/phone_tripod.webp',
    category: MarketCategory.setup,
    price: Money(minorUnits: 79900, currencyCode: 'TRY'),
  ),
];

class _DeferredMarketCatalogRepository implements MarketCatalogRepository {
  final Completer<List<MarketProduct>> _completer =
      Completer<List<MarketProduct>>();

  void complete(List<MarketProduct> products) {
    _completer.complete(products);
  }

  @override
  Future<List<MarketProduct>> loadProducts() => _completer.future;
}

class _FailingMarketCatalogRepository implements MarketCatalogRepository {
  int loadCount = 0;

  @override
  Future<List<MarketProduct>> loadProducts() async {
    loadCount += 1;
    throw const FormatException('invalid market fixture');
  }
}
