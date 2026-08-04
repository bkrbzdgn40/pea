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

    await tester.scrollUntilVisible(
      find.textContaining('cihaz belleğinde geçici olarak'),
      180,
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
