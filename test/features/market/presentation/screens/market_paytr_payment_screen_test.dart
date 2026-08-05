import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_browser.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_navigation_policy.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_session.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_status.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_status_repository.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_cart.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_cart_line.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_category.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_product.dart';
import 'package:pose_estimation_app/features/market/domain/models/money.dart';
import 'package:pose_estimation_app/features/market/presentation/providers/market_cart_provider.dart';
import 'package:pose_estimation_app/features/market/presentation/providers/market_payment_session_provider.dart';
import 'package:pose_estimation_app/features/market/presentation/screens/market_paytr_payment_screen.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('opens the PayTR iframe in an isolated in-app browser', (
    tester,
  ) async {
    final browserFactory = _FakeBrowserFactory();
    await _pumpPaymentScreen(
      tester,
      browserFactory: browserFactory,
      statusRepository: _FakeStatusRepository(<MarketPaymentStatus>[]),
    );

    expect(browserFactory.initialUri, session.iframeUri);
    expect(find.byKey(const Key('market-paytr-webview')), findsOneWidget);

    browserFactory.browser.finish(session.iframeUri);
    await tester.pump();
    expect(find.byKey(const Key('market-paytr-page-loading')), findsNothing);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('verified success clears the cart exactly once', (tester) async {
    final browserFactory = _FakeBrowserFactory();
    final repository = _FakeStatusRepository(<MarketPaymentStatus>[
      pendingStatus,
      paidStatus,
    ]);
    await _pumpPaymentScreen(
      tester,
      browserFactory: browserFactory,
      statusRepository: repository,
    );

    final decision = browserFactory.browser.navigate(session.merchantOkUri);
    expect(decision, MarketPaymentNavigationDecision.successReturn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('market-paytr-payment-paid')), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MarketPaytrPaymentScreen)),
    );
    expect(container.read(marketCartProvider).isEmpty, isTrue);
    expect(repository.calls, 2);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('verified failure preserves the cart', (tester) async {
    final browserFactory = _FakeBrowserFactory();
    final repository = _FakeStatusRepository(<MarketPaymentStatus>[
      failedStatus,
    ]);
    await _pumpPaymentScreen(
      tester,
      browserFactory: browserFactory,
      statusRepository: repository,
    );

    browserFactory.browser.navigate(session.merchantFailUri);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('market-paytr-payment-failed')),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MarketPaytrPaymentScreen)),
    );
    expect(container.read(marketCartProvider).quantityFor(product.id), 1);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('blocks insecure navigation and confirms early exit', (
    tester,
  ) async {
    final browserFactory = _FakeBrowserFactory();
    await _pumpPaymentScreen(
      tester,
      browserFactory: browserFactory,
      statusRepository: _FakeStatusRepository(<MarketPaymentStatus>[]),
    );

    browserFactory.browser.finish(session.iframeUri);
    await tester.pump();

    expect(
      browserFactory.browser.navigate(Uri.parse('http://evil.example/pay')),
      MarketPaymentNavigationDecision.block,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Ödeme ekranından çıkılsın mı?'), findsOneWidget);
    expect(find.byKey(const Key('market-paytr-confirm-exit')), findsOneWidget);
    expectNoPresentationExceptions(tester);
  });
}

Future<void> _pumpPaymentScreen(
  WidgetTester tester, {
  required _FakeBrowserFactory browserFactory,
  required MarketPaymentStatusRepository statusRepository,
}) async {
  final cart = MarketCart(
    lines: const <MarketCartLine>[
      MarketCartLine(product: product, quantity: 1),
    ],
  );

  await pumpTestApp(
    tester,
    locale: const Locale('tr'),
    overrides: <Override>[
      marketCartProvider.overrideWith(
        (ref) => MarketCartController(initialState: cart),
      ),
      marketPaymentBrowserFactoryProvider.overrideWithValue(browserFactory),
      marketPaymentStatusRepositoryProvider.overrideWithValue(statusRepository),
      marketPaymentVerificationAttemptsProvider.overrideWithValue(3),
      marketPaymentVerificationIntervalProvider.overrideWithValue(
        Duration.zero,
      ),
      marketPaymentVerificationDelayProvider.overrideWithValue(
        (duration) async {},
      ),
    ],
    home: MarketPaytrPaymentScreen(session: session),
  );
  await tester.pump();
}

class _FakeBrowserFactory implements MarketPaymentBrowserFactory {
  late Uri initialUri;
  late _FakeBrowser browser;

  @override
  MarketPaymentBrowser create({
    required Uri initialUri,
    required MarketPaymentBrowserNavigationCallback onNavigation,
    required MarketPaymentBrowserUriCallback onPageStarted,
    required MarketPaymentBrowserUriCallback onPageFinished,
    required MarketPaymentBrowserErrorCallback onMainFrameError,
  }) {
    this.initialUri = initialUri;
    browser = _FakeBrowser(
      onNavigation: onNavigation,
      onPageStarted: onPageStarted,
      onPageFinished: onPageFinished,
      onMainFrameError: onMainFrameError,
    );
    return browser;
  }
}

class _FakeBrowser implements MarketPaymentBrowser {
  _FakeBrowser({
    required this.onNavigation,
    required this.onPageStarted,
    required this.onPageFinished,
    required this.onMainFrameError,
  });

  final MarketPaymentBrowserNavigationCallback onNavigation;
  final MarketPaymentBrowserUriCallback onPageStarted;
  final MarketPaymentBrowserUriCallback onPageFinished;
  final MarketPaymentBrowserErrorCallback onMainFrameError;
  int reloadCalls = 0;

  @override
  Widget build({Key? key}) => ColoredBox(key: key, color: Colors.white);

  MarketPaymentNavigationDecision navigate(Uri uri) => onNavigation(uri);

  void finish(Uri uri) => onPageFinished(uri);

  @override
  Future<void> reload() async {
    reloadCalls += 1;
  }
}

class _FakeStatusRepository implements MarketPaymentStatusRepository {
  _FakeStatusRepository(List<MarketPaymentStatus> statuses)
    : _statuses = List<MarketPaymentStatus>.of(statuses);

  final List<MarketPaymentStatus> _statuses;
  int calls = 0;

  @override
  Future<MarketPaymentStatus> getStatus({required String orderId}) async {
    calls += 1;
    return _statuses.removeAt(0);
  }
}

final session = MarketPaymentSession(
  orderId: 'order-1',
  merchantOid: 'merchant-1',
  paymentStatus: 'awaiting_payment',
  total: Money(minorUnits: 79900, currencyCode: 'TRY'),
  iframeToken: 'token-1',
  iframeUri: Uri.parse('https://www.paytr.com/odeme/guvenli/token-1'),
  merchantOkUri: Uri.parse('https://merchant.example/payment/success'),
  merchantFailUri: Uri.parse('https://merchant.example/payment/failure'),
);

const pendingStatus = MarketPaymentStatus(
  orderId: 'order-1',
  merchantOid: 'merchant-1',
  orderStatus: 'awaiting_payment',
  value: MarketPaymentStatusValue.pending,
  total: Money(minorUnits: 79900, currencyCode: 'TRY'),
);

const paidStatus = MarketPaymentStatus(
  orderId: 'order-1',
  merchantOid: 'merchant-1',
  orderStatus: 'paid',
  value: MarketPaymentStatusValue.paid,
  total: Money(minorUnits: 79900, currencyCode: 'TRY'),
);

const failedStatus = MarketPaymentStatus(
  orderId: 'order-1',
  merchantOid: 'merchant-1',
  orderStatus: 'payment_failed',
  value: MarketPaymentStatusValue.failed,
  total: Money(minorUnits: 79900, currencyCode: 'TRY'),
);

const product = MarketProduct(
  id: 'phone_tripod',
  category: MarketCategory.setup,
  price: Money(minorUnits: 79900, currencyCode: 'TRY'),
);
