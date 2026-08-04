import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_cart.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_cart_line.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_category.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_product.dart';
import 'package:pose_estimation_app/features/market/domain/models/money.dart';
import 'package:pose_estimation_app/features/market/presentation/providers/market_cart_provider.dart';
import 'package:pose_estimation_app/features/market/presentation/screens/market_checkout_screen.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
  const product = MarketProduct(
    id: 'phone_tripod',
    category: MarketCategory.setup,
    price: Money(minorUnits: 79900, currencyCode: 'TRY'),
  );

  testWidgets('renders an honest empty checkout state', (tester) async {
    await pumpTestApp(
      tester,
      locale: const Locale('tr'),
      home: const MarketCheckoutScreen(),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('market-checkout-empty-state')),
      findsOneWidget,
    );
    expect(find.text('Sipariş özeti hazır değil'), findsOneWidget);
    expect(
      find.byKey(const Key('market-checkout-return-to-cart')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.menu), findsNothing);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('renders the local order summary without enabling payment', (
    tester,
  ) async {
    final initialCart = MarketCart(
      lines: const [MarketCartLine(product: product, quantity: 2)],
    );

    await pumpTestApp(
      tester,
      locale: const Locale('tr'),
      overrides: [
        marketCartProvider.overrideWith(
          (ref) => MarketCartController(initialState: initialCart),
        ),
      ],
      home: const MarketCheckoutScreen(),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('market-checkout-template-notice')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('market-checkout-payment-card')),
      180,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('market-checkout-payment-card')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('market-checkout-order-items')),
      180,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('market-checkout-line-phone_tripod')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('market-checkout-total-card')),
      180,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('market-checkout-total-value')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('market-checkout-disabled-payment')),
      180,
    );
    await tester.pumpAndSettle();

    final paymentButton = tester.widget<FilledButton>(
      find.byKey(const Key('market-checkout-disabled-payment')),
    );
    expect(paymentButton.onPressed, isNull);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('remains scrollable with large text on a compact viewport', (
    tester,
  ) async {
    final initialCart = MarketCart(
      lines: const [MarketCartLine(product: product, quantity: 2)],
    );

    await pumpTestApp(
      tester,
      locale: const Locale('tr'),
      configuration: const PresentationTestConfiguration(
        viewport: PresentationTestViewport.compactPortrait,
        textScaleFactor: 2,
      ),
      overrides: [
        marketCartProvider.overrideWith(
          (ref) => MarketCartController(initialState: initialCart),
        ),
      ],
      home: const MarketCheckoutScreen(),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('market-checkout-disabled-payment')),
      180,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('market-checkout-disabled-payment')),
      findsOneWidget,
    );
    expectNoPresentationExceptions(tester);
  });
}
