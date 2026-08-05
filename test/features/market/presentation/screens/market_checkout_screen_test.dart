import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_checkout_customer.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_session.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_session_failure.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_session_repository.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_cart.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_cart_line.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_category.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_product.dart';
import 'package:pose_estimation_app/features/market/domain/models/money.dart';
import 'package:pose_estimation_app/features/market/presentation/providers/market_cart_provider.dart';
import 'package:pose_estimation_app/features/market/presentation/providers/market_payment_session_provider.dart';
import 'package:pose_estimation_app/features/market/presentation/screens/market_checkout_screen.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
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

  testWidgets('renders the real checkout form and local order summary', (
    tester,
  ) async {
    await _pumpCheckout(tester);

    expect(
      find.byKey(const Key('market-checkout-security-notice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('market-checkout-delivery-card')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('market-checkout-full-name')), findsOneWidget);
    expect(find.byKey(const Key('market-checkout-email')), findsOneWidget);
    expect(find.byKey(const Key('market-checkout-phone')), findsOneWidget);
    expect(find.byKey(const Key('market-checkout-address')), findsOneWidget);

    await _ensureVisible(
      tester,
      find.byKey(const Key('market-checkout-payment-card')),
    );
    expect(find.text('PayTR güvenli ödeme'), findsOneWidget);

    await _ensureVisible(
      tester,
      find.byKey(const Key('market-checkout-order-items')),
    );
    expect(
      find.byKey(const ValueKey('market-checkout-line-phone_tripod')),
      findsOneWidget,
    );

    await _ensureVisible(
      tester,
      find.byKey(const Key('market-checkout-create-payment-session')),
    );
    final paymentButton = tester.widget<FilledButton>(
      find.byKey(const Key('market-checkout-create-payment-session')),
    );
    expect(paymentButton.onPressed, isNotNull);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('validates required customer fields before calling backend', (
    tester,
  ) async {
    final repository = _RecordingPaymentRepository();
    await _pumpCheckout(tester, repository: repository);

    final paymentButton = find.byKey(
      const Key('market-checkout-create-payment-session'),
    );
    await _ensureVisible(tester, paymentButton);
    await tester.tap(paymentButton);
    await tester.pumpAndSettle();

    expect(find.text('Bu alan zorunludur.'), findsNWidgets(4));
    expect(repository.calls, isEmpty);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('creates a backend payment session from normalized form data', (
    tester,
  ) async {
    final repository = _RecordingPaymentRepository(session: session);
    await _pumpCheckout(tester, repository: repository);

    await tester.enterText(
      find.byKey(const Key('market-checkout-full-name')),
      '  Test User  ',
    );
    await tester.enterText(
      find.byKey(const Key('market-checkout-email')),
      '  user@example.com  ',
    );
    await tester.enterText(
      find.byKey(const Key('market-checkout-phone')),
      '  0555 000 00 00  ',
    );
    await tester.enterText(
      find.byKey(const Key('market-checkout-address')),
      '  Test Mahallesi Test Sokak No 1  ',
    );

    final paymentButton = find.byKey(
      const Key('market-checkout-create-payment-session'),
    );
    await _ensureVisible(tester, paymentButton);
    await tester.tap(paymentButton);
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(1));
    expect(repository.calls.single.customer.email, 'user@example.com');
    expect(repository.calls.single.customer.fullName, 'Test User');
    expect(repository.calls.single.customer.phone, '0555 000 00 00');
    expect(
      repository.calls.single.customer.address,
      'Test Mahallesi Test Sokak No 1',
    );
    expect(repository.calls.single.idempotencyKey, 'checkout_test_key_123456');

    await _ensureVisible(
      tester,
      find.byKey(const Key('market-checkout-payment-session-ready')),
    );
    expect(
      find.byKey(const Key('market-checkout-payment-session-ready')),
      findsOneWidget,
    );
    expect(find.text('Sipariş referansı: order-1'), findsOneWidget);
    expect(
      find.textContaining('Backend tarafından doğrulanan toplam'),
      findsOneWidget,
    );

    final readyButton = tester.widget<FilledButton>(paymentButton);
    expect(readyButton.onPressed, isNotNull);
    expect(find.text('PayTR ödeme ekranını aç'), findsOneWidget);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('shows a retryable inline error without clearing the cart', (
    tester,
  ) async {
    final repository = _RecordingPaymentRepository(
      failure: const MarketPaymentSessionFailure(
        code: 'payment_session_network_error',
        message: 'Network unavailable.',
        retryDisposition: MarketPaymentRetryDisposition.reuseIdempotencyKey,
      ),
    );
    await _pumpCheckout(tester, repository: repository);
    await _fillValidForm(tester);

    final paymentButton = find.byKey(
      const Key('market-checkout-create-payment-session'),
    );
    await _ensureVisible(tester, paymentButton);
    await tester.tap(paymentButton);
    await tester.pumpAndSettle();

    await _ensureVisible(
      tester,
      find.byKey(const Key('market-checkout-payment-session-error')),
    );
    expect(
      find.byKey(const Key('market-checkout-payment-session-error')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Aynı güvenli işlem anahtarıyla'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('market-checkout-line-phone_tripod')),
      findsOneWidget,
    );

    final retryButton = tester.widget<FilledButton>(paymentButton);
    expect(retryButton.onPressed, isNotNull);
    expectNoPresentationExceptions(tester);
  });

  testWidgets(
    'keeps the address keyboard open when editing invalidates payment state',
    (tester) async {
      final repository = _RecordingPaymentRepository(
        failure: const MarketPaymentSessionFailure(
          code: 'payment_session_network_error',
          message: 'Network unavailable.',
          retryDisposition: MarketPaymentRetryDisposition.reuseIdempotencyKey,
        ),
      );
      await _pumpCheckout(tester, repository: repository);
      await _fillValidForm(tester);

      final paymentButton = find.byKey(
        const Key('market-checkout-create-payment-session'),
      );
      await _ensureVisible(tester, paymentButton);
      await tester.tap(paymentButton);
      await tester.pumpAndSettle();

      final addressField = find.byKey(const Key('market-checkout-address'));
      await _ensureVisible(tester, addressField);
      await tester.tap(addressField);
      await tester.showKeyboard(addressField);
      await tester.pump();

      expect(tester.testTextInput.isVisible, isTrue);

      tester.testTextInput.enterText('Updated Mahallesi Updated Sokak No 2');
      await tester.pump();
      await tester.pump();

      final editableText = tester.widget<EditableText>(
        find.descendant(of: addressField, matching: find.byType(EditableText)),
      );
      expect(editableText.focusNode.hasFocus, isTrue);
      expect(editableText.keyboardType, TextInputType.multiline);
      expect(editableText.textInputAction, TextInputAction.newline);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        find.byKey(const Key('market-checkout-payment-session-error')),
        findsNothing,
      );
      expectNoPresentationExceptions(tester);
    },
  );

  testWidgets('remains scrollable with large text on a compact viewport', (
    tester,
  ) async {
    await _pumpCheckout(
      tester,
      configuration: const PresentationTestConfiguration(
        viewport: PresentationTestViewport.compactPortrait,
        textScaleFactor: 2,
      ),
    );

    await _ensureVisible(
      tester,
      find.byKey(const Key('market-checkout-create-payment-session')),
    );

    expect(
      find.byKey(const Key('market-checkout-create-payment-session')),
      findsOneWidget,
    );
    expectNoPresentationExceptions(tester);
  });
}

Future<void> _ensureVisible(WidgetTester tester, Finder target) async {
  final checkoutScrollView = find.byKey(
    const Key('market-checkout-scroll-view'),
  );
  expect(checkoutScrollView, findsOneWidget);
  expect(target, findsOneWidget);

  // Text entry leaves the final field focused. Close that editing session before
  // moving to the payment action so focus-driven reveal requests cannot pull the
  // checkout back toward the address field.
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();

  final viewport = tester.getRect(checkoutScrollView).deflate(8);

  for (var attempt = 0; attempt < 24; attempt++) {
    final targetCenter = tester.getRect(target).center;
    if (viewport.contains(targetCenter)) {
      break;
    }

    final dragOffset = targetCenter.dy > viewport.bottom
        ? const Offset(0, -240)
        : const Offset(0, 240);
    await tester.drag(checkoutScrollView, dragOffset);
    await tester.pump();
  }

  await tester.pumpAndSettle();
  expect(
    viewport.contains(tester.getRect(target).center),
    isTrue,
    reason: 'Target must be inside the checkout viewport before interaction.',
  );
}

Future<void> _pumpCheckout(
  WidgetTester tester, {
  _RecordingPaymentRepository? repository,
  PresentationTestConfiguration? configuration,
}) async {
  final initialCart = MarketCart(
    lines: const <MarketCartLine>[
      MarketCartLine(product: product, quantity: 2),
    ],
  );

  await pumpTestApp(
    tester,
    locale: const Locale('tr'),
    configuration: configuration,
    overrides: <Override>[
      marketCartProvider.overrideWith(
        (ref) => MarketCartController(initialState: initialCart),
      ),
      marketPaymentSessionRepositoryProvider.overrideWithValue(
        repository ?? _RecordingPaymentRepository(session: session),
      ),
      marketPaymentIdempotencyKeyFactoryProvider.overrideWithValue(
        () => 'checkout_test_key_123456',
      ),
    ],
    home: const MarketCheckoutScreen(),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('market-checkout-full-name')),
    'Test User',
  );
  await tester.enterText(
    find.byKey(const Key('market-checkout-email')),
    'user@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('market-checkout-phone')),
    '05550000000',
  );
  await tester.enterText(
    find.byKey(const Key('market-checkout-address')),
    'Test Mahallesi Test Sokak No 1',
  );
}

class _PaymentCall {
  const _PaymentCall({
    required this.cart,
    required this.customer,
    required this.idempotencyKey,
  });

  final MarketCart cart;
  final MarketCheckoutCustomer customer;
  final String idempotencyKey;
}

class _RecordingPaymentRepository implements MarketPaymentSessionRepository {
  _RecordingPaymentRepository({this.session, this.failure});

  final MarketPaymentSession? session;
  final MarketPaymentSessionFailure? failure;
  final List<_PaymentCall> calls = <_PaymentCall>[];

  @override
  Future<MarketPaymentSession> createSession({
    required MarketCart cart,
    required MarketCheckoutCustomer customer,
    required String idempotencyKey,
  }) async {
    calls.add(
      _PaymentCall(
        cart: cart,
        customer: customer,
        idempotencyKey: idempotencyKey,
      ),
    );
    if (failure != null) {
      throw failure!;
    }
    return session!;
  }
}

final session = MarketPaymentSession(
  orderId: 'order-1',
  merchantOid: 'merchant-1',
  paymentStatus: 'awaiting_payment',
  total: Money(minorUnits: 159800, currencyCode: 'TRY'),
  iframeToken: 'token-1',
  iframeUri: Uri.parse('https://www.paytr.com/odeme/guvenli/token-1'),
  merchantOkUri: Uri.parse('https://example.com/payment/success'),
  merchantFailUri: Uri.parse('https://example.com/payment/failure'),
);

const product = MarketProduct(
  id: 'phone_tripod',
  category: MarketCategory.setup,
  price: Money(minorUnits: 79900, currencyCode: 'TRY'),
);
