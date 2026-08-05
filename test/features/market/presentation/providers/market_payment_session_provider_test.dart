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
import 'package:pose_estimation_app/features/market/presentation/providers/market_payment_session_provider.dart';

void main() {
  const cart = MarketCart(
    lines: <MarketCartLine>[MarketCartLine(product: product, quantity: 1)],
  );
  const customer = MarketCheckoutCustomer(
    email: 'user@example.com',
    fullName: 'Test User',
    phone: '05550000000',
    address: 'Test Mahallesi Test Sokak No 1',
  );

  test('reuses the idempotency key after a transient failure', () async {
    final repository = _RecordingRepository(
      outcomes: <Object>[
        const MarketPaymentSessionFailure(
          code: 'payment_session_network_error',
          message: 'Network failed.',
          retryDisposition: MarketPaymentRetryDisposition.reuseIdempotencyKey,
        ),
        session,
      ],
    );
    var keyCount = 0;
    final controller = MarketPaymentSessionController(
      repository: repository,
      createIdempotencyKey: () => 'checkout_key_${++keyCount}_abcdef',
    );

    await controller.createSession(cart: cart, customer: customer);
    expect(controller.state.phase, MarketPaymentSessionPhase.failed);

    await controller.createSession(cart: cart, customer: customer);
    expect(controller.state.phase, MarketPaymentSessionPhase.ready);
    expect(repository.idempotencyKeys, <String>[
      'checkout_key_1_abcdef',
      'checkout_key_1_abcdef',
    ]);
    expect(keyCount, 1);
  });

  test(
    'creates a new key when the backend rejects the previous session',
    () async {
      final repository = _RecordingRepository(
        outcomes: <Object>[
          const MarketPaymentSessionFailure(
            code: 'payment_session_previously_failed',
            message: 'Use a new key.',
            retryDisposition:
                MarketPaymentRetryDisposition.requireNewIdempotencyKey,
          ),
          session,
        ],
      );
      var keyCount = 0;
      final controller = MarketPaymentSessionController(
        repository: repository,
        createIdempotencyKey: () => 'checkout_key_${++keyCount}_abcdef',
      );

      await controller.createSession(cart: cart, customer: customer);
      await controller.createSession(cart: cart, customer: customer);

      expect(repository.idempotencyKeys, <String>[
        'checkout_key_1_abcdef',
        'checkout_key_2_abcdef',
      ]);
    },
  );

  test('changed customer input creates a new request identity', () async {
    final repository = _RecordingRepository(
      outcomes: <Object>[
        const MarketPaymentSessionFailure(
          code: 'payment_session_network_error',
          message: 'Network failed.',
          retryDisposition: MarketPaymentRetryDisposition.reuseIdempotencyKey,
        ),
        session,
      ],
    );
    var keyCount = 0;
    final controller = MarketPaymentSessionController(
      repository: repository,
      createIdempotencyKey: () => 'checkout_key_${++keyCount}_abcdef',
    );

    await controller.createSession(cart: cart, customer: customer);
    await controller.createSession(
      cart: cart,
      customer: const MarketCheckoutCustomer(
        email: 'other@example.com',
        fullName: 'Test User',
        phone: '05550000000',
        address: 'Test Mahallesi Test Sokak No 1',
      ),
    );

    expect(repository.idempotencyKeys, <String>[
      'checkout_key_1_abcdef',
      'checkout_key_2_abcdef',
    ]);
  });
}

class _RecordingRepository implements MarketPaymentSessionRepository {
  _RecordingRepository({required List<Object> outcomes})
    : _outcomes = List<Object>.of(outcomes);

  final List<Object> _outcomes;
  final List<String> idempotencyKeys = <String>[];

  @override
  Future<MarketPaymentSession> createSession({
    required MarketCart cart,
    required MarketCheckoutCustomer customer,
    required String idempotencyKey,
  }) async {
    idempotencyKeys.add(idempotencyKey);
    final outcome = _outcomes.removeAt(0);
    if (outcome is MarketPaymentSessionFailure) {
      throw outcome;
    }
    return outcome as MarketPaymentSession;
  }
}

final session = MarketPaymentSession(
  orderId: 'order-1',
  merchantOid: 'merchant-1',
  paymentStatus: 'awaiting_payment',
  total: Money(minorUnits: 79900, currencyCode: 'TRY'),
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
