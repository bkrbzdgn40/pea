import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_checkout_customer.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_session.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_session_repository.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_cart.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_cart_line.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_category.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_product.dart';
import 'package:pose_estimation_app/features/market/domain/models/money.dart';
import 'package:pose_estimation_app/features/market/presentation/providers/market_cart_provider.dart';
import 'package:pose_estimation_app/features/market/presentation/providers/market_payment_session_provider.dart';
import 'package:pose_estimation_app/features/market/presentation/screens/market_cart_screen.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
  const product = MarketProduct(
    id: 'phone_tripod',
    category: MarketCategory.setup,
    price: Money(minorUnits: 79900, currencyCode: 'TRY'),
  );

  testWidgets('renders an honest empty cart state', (tester) async {
    await pumpTestApp(
      tester,
      locale: const Locale('tr'),
      home: const MarketCartScreen(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sepetin boş'), findsOneWidget);
    expect(
      find.textContaining('Ürün detayından bir şablon ürün'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('market-cart-return-to-products')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.menu), findsNothing);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('updates quantity, subtotal, and removal locally', (
    tester,
  ) async {
    final initialCart = MarketCart(
      lines: const [MarketCartLine(product: product, quantity: 1)],
    );

    await pumpTestApp(
      tester,
      locale: const Locale('tr'),
      overrides: [
        marketCartProvider.overrideWith(
          (ref) => MarketCartController(initialState: initialCart),
        ),
      ],
      home: const MarketCartScreen(),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('market-cart-overview')), findsOneWidget);
    expect(find.text('1 ürün · 1 çeşit'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('market-cart-line-phone_tripod')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('market-cart-quantity-phone_tripod')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('market-cart-subtotal-value')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('market-cart-increment-phone_tripod')),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('2 ürün · 1 çeşit'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('market-cart-decrement-phone_tripod')),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('1 ürün · 1 çeşit'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('market-cart-remove-phone_tripod')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sepetin boş'), findsOneWidget);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('opens the real checkout from a non-empty cart', (tester) async {
    final initialCart = MarketCart(
      lines: const [MarketCartLine(product: product, quantity: 1)],
    );

    await pumpTestApp(
      tester,
      locale: const Locale('tr'),
      overrides: [
        marketCartProvider.overrideWith(
          (ref) => MarketCartController(initialState: initialCart),
        ),
        marketPaymentSessionRepositoryProvider.overrideWithValue(
          const _UnexpectedPaymentRepository(),
        ),
      ],
      home: const MarketCartScreen(),
    );
    await tester.pumpAndSettle();

    final proceedButton = find.byKey(const Key('market-proceed-to-checkout'));
    await tester.scrollUntilVisible(proceedButton, 180);
    await tester.pumpAndSettle();

    expect(proceedButton, findsOneWidget);
    await tester.tap(proceedButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('market-checkout-security-notice')),
      findsOneWidget,
    );

    await _scrollCheckoutUntilVisible(
      tester,
      find.byKey(const Key('market-checkout-payment-card')),
    );

    expect(find.text('PayTR güvenli ödeme'), findsOneWidget);

    await _scrollCheckoutUntilVisible(
      tester,
      find.byKey(const Key('market-checkout-order-items')),
    );

    expect(
      find.byKey(const ValueKey('market-checkout-line-phone_tripod')),
      findsOneWidget,
    );
    expectNoPresentationExceptions(tester);
  });

  testWidgets('remains usable with large text on a compact viewport', (
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
      home: const MarketCartScreen(),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('market-cart-summary')),
      180,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('market-cart-summary')), findsOneWidget);
    expectNoPresentationExceptions(tester);
  });
}

Future<void> _scrollCheckoutUntilVisible(
  WidgetTester tester,
  Finder target,
) async {
  final checkoutScrollView = find.byKey(
    const Key('market-checkout-scroll-view'),
  );
  expect(checkoutScrollView, findsOneWidget);

  for (var attempt = 0; attempt < 24 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(checkoutScrollView, const Offset(0, -240));
    await tester.pump();
  }

  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

class _UnexpectedPaymentRepository implements MarketPaymentSessionRepository {
  const _UnexpectedPaymentRepository();

  @override
  Future<MarketPaymentSession> createSession({
    required MarketCart cart,
    required MarketCheckoutCustomer customer,
    required String idempotencyKey,
  }) {
    throw StateError('Payment session must not be created in this test.');
  }
}
