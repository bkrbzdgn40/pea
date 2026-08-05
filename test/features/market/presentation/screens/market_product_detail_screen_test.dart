import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_category.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_product.dart';
import 'package:pose_estimation_app/features/market/domain/models/money.dart';
import 'package:pose_estimation_app/features/market/presentation/screens/market_product_detail_screen.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
  const product = MarketProduct(
    id: 'phone_tripod',
    category: MarketCategory.setup,
    price: Money(minorUnits: 79900, currencyCode: 'TRY'),
  );

  const galleryProduct = MarketProduct(
    id: 'phone_tripod',
    category: MarketCategory.setup,
    price: Money(minorUnits: 79900, currencyCode: 'TRY'),
    imageAssetPaths: <String>[
      'assets/market/products/phone_tripod.webp',
      'assets/market/products/exercise_mat.webp',
      'assets/market/products/foam_roller.webp',
    ],
  );

  testWidgets('renders the selected product information', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      locale: const Locale('tr'),
      home: const MarketProductDetailScreen(product: product),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('market-product-detail-phone_tripod')),
      findsOneWidget,
    );
    expect(find.text('Kamera ve Kurulum'), findsOneWidget);
    expect(find.text('Ürün bilgisi'), findsOneWidget);
    expect(
      find.text(
        'Kamerayı sabit tutarak analiz kadrajını daha kolay korumana yardımcı olur.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.menu), findsNothing);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('swipes between multiple product gallery images', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      locale: const Locale('tr'),
      home: const MarketProductDetailScreen(product: galleryProduct),
    );
    await tester.pumpAndSettle();

    final gallery = find.byKey(
      const ValueKey('market-product-gallery-pages-phone_tripod'),
    );
    expect(gallery, findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.fling(gallery, const Offset(-600, 0), 1200);
    await tester.pumpAndSettle();

    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('market-product-gallery-next')));
    await tester.pumpAndSettle();

    expect(find.text('3 / 3'), findsOneWidget);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('remains scrollable with large text on a compact viewport', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      locale: const Locale('tr'),
      configuration: const PresentationTestConfiguration(
        viewport: PresentationTestViewport.compactPortrait,
        textScaleFactor: 2,
      ),
      home: const MarketProductDetailScreen(product: product),
    );
    await tester.pumpAndSettle();

    final detailScrollable = find.descendant(
      of: find.byKey(const ValueKey('market-product-detail-phone_tripod')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(detailScrollable, findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('cihaz belleğinde geçici olarak'),
      180,
      scrollable: detailScrollable,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('cihaz belleğinde geçici olarak'),
      findsOneWidget,
    );
    expectNoPresentationExceptions(tester);
  });

  testWidgets('adds the product to the local cart and opens it', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      locale: const Locale('tr'),
      home: const MarketProductDetailScreen(product: product),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sepete ekle'), findsOneWidget);

    await tester.tap(find.byKey(const Key('market-add-to-cart')));
    await tester.pumpAndSettle();

    expect(find.text('Sepette (1)'), findsOneWidget);
    expect(find.text('Bir tane daha ekle'), findsOneWidget);
    expect(find.byKey(const Key('market-product-cart-status')), findsOneWidget);
    expect(find.byKey(const Key('market-cart-count-badge')), findsOneWidget);

    await tester.tap(find.byKey(const Key('market-cart-action')));
    await tester.pumpAndSettle();

    expect(find.text('Sepet'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('market-cart-line-phone_tripod')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('market-cart-subtotal-value')), findsOneWidget);
    expectNoPresentationExceptions(tester);
  });
}
