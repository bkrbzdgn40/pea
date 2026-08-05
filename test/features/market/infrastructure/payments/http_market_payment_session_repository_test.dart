import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_checkout_customer.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_session_failure.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_cart.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_cart_line.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_category.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_product.dart';
import 'package:pose_estimation_app/features/market/domain/models/money.dart';
import 'package:pose_estimation_app/features/market/infrastructure/payments/http_market_payment_session_repository.dart';

void main() {
  const endpoint = 'https://example.com/paytrApi/payments/paytr/session';
  const customer = MarketCheckoutCustomer(
    email: 'user@example.com',
    fullName: 'Test User',
    phone: '+90 555 000 00 00',
    address: 'Test Mahallesi Test Sokak No 1',
  );
  const cart = MarketCart(
    lines: <MarketCartLine>[MarketCartLine(product: product, quantity: 2)],
  );

  test(
    'posts the server-owned payment contract and parses a session',
    () async {
      late http.Request recordedRequest;
      final client = MockClient((request) async {
        recordedRequest = request;
        return http.Response(
          jsonEncode(<String, Object>{
            'contractVersion': 1,
            'orderId': 'order-1',
            'merchantOid': 'merchant-1',
            'paymentStatus': 'awaiting_payment',
            'currencyCode': 'TRY',
            'totalMinor': 159800,
            'iframeToken': 'opaque-token',
            'iframeUrl': 'https://www.paytr.com/odeme/guvenli/opaque-token',
            'merchantOkUrl': 'https://example.com/payment/success',
            'merchantFailUrl': 'https://example.com/payment/failure',
          }),
          201,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      });
      final repository = HttpMarketPaymentSessionRepository(
        client: client,
        sessionEndpoint: Uri.parse(endpoint),
        loadAccessToken: ({required forceRefresh}) async => 'firebase-token',
      );

      final session = await repository.createSession(
        cart: cart,
        customer: customer,
        idempotencyKey: 'checkout_1234567890abcdef',
      );

      expect(recordedRequest.url.toString(), endpoint);
      expect(recordedRequest.headers['authorization'], 'Bearer firebase-token');
      expect(
        recordedRequest.headers['idempotency-key'],
        'checkout_1234567890abcdef',
      );
      final requestBody =
          jsonDecode(recordedRequest.body) as Map<String, dynamic>;
      expect(requestBody.keys, <String>[
        'contractVersion',
        'items',
        'customer',
      ]);
      expect(requestBody.containsKey('totalMinor'), isFalse);
      expect(requestBody.containsKey('price'), isFalse);
      expect(requestBody['items'], <Map<String, Object>>[
        <String, Object>{'productId': 'phone_tripod', 'quantity': 2},
      ]);
      expect(session.orderId, 'order-1');
      expect(
        session.total,
        const Money(minorUnits: 159800, currencyCode: 'TRY'),
      );
      expect(session.iframeUri.host, 'www.paytr.com');
      expect(session.merchantOkUri.path, '/payment/success');
      expect(session.merchantFailUri.path, '/payment/failure');
    },
  );

  test('refreshes the Firebase token once after a 401 response', () async {
    final forceRefreshCalls = <bool>[];
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount += 1;
      if (requestCount == 1) {
        expect(request.headers['authorization'], 'Bearer stale-token');
        return http.Response(
          jsonEncode(<String, Object>{
            'error': <String, Object>{
              'code': 'unauthenticated',
              'message': 'Token expired.',
            },
          }),
          401,
        );
      }
      expect(request.headers['authorization'], 'Bearer fresh-token');
      return http.Response(
        jsonEncode(<String, Object>{
          'contractVersion': 1,
          'orderId': 'order-2',
          'merchantOid': 'merchant-2',
          'paymentStatus': 'awaiting_payment',
          'currencyCode': 'TRY',
          'totalMinor': 79900,
          'iframeToken': 'token-2',
          'iframeUrl': 'https://www.paytr.com/odeme/guvenli/token-2',
          'merchantOkUrl': 'https://example.com/payment/success',
          'merchantFailUrl': 'https://example.com/payment/failure',
        }),
        200,
      );
    });
    final repository = HttpMarketPaymentSessionRepository(
      client: client,
      sessionEndpoint: Uri.parse(endpoint),
      loadAccessToken: ({required forceRefresh}) async {
        forceRefreshCalls.add(forceRefresh);
        return forceRefresh ? 'fresh-token' : 'stale-token';
      },
    );

    final session = await repository.createSession(
      cart: cart,
      customer: customer,
      idempotencyKey: 'checkout_1234567890abcdef',
    );

    expect(session.orderId, 'order-2');
    expect(forceRefreshCalls, <bool>[false, true]);
    expect(requestCount, 2);
  });

  test('maps transient backend failures to idempotent retry', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(<String, Object>{
          'error': <String, Object>{
            'code': 'payment_session_in_progress',
            'message': 'Still processing.',
            'requestId': 'request-1',
          },
        }),
        409,
      );
    });
    final repository = HttpMarketPaymentSessionRepository(
      client: client,
      sessionEndpoint: Uri.parse(endpoint),
      loadAccessToken: ({required forceRefresh}) async => 'token',
    );

    await expectLater(
      repository.createSession(
        cart: cart,
        customer: customer,
        idempotencyKey: 'checkout_1234567890abcdef',
      ),
      throwsA(
        isA<MarketPaymentSessionFailure>()
            .having(
              (failure) => failure.code,
              'code',
              'payment_session_in_progress',
            )
            .having(
              (failure) => failure.retryDisposition,
              'retryDisposition',
              MarketPaymentRetryDisposition.reuseIdempotencyKey,
            )
            .having((failure) => failure.requestId, 'requestId', 'request-1'),
      ),
    );
  });

  test(
    'requires a new key after a previously failed provider session',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object>{
            'error': <String, Object>{
              'code': 'payment_session_previously_failed',
              'message': 'Use a new key.',
            },
          }),
          409,
        );
      });
      final repository = HttpMarketPaymentSessionRepository(
        client: client,
        sessionEndpoint: Uri.parse(endpoint),
        loadAccessToken: ({required forceRefresh}) async => 'token',
      );

      await expectLater(
        repository.createSession(
          cart: cart,
          customer: customer,
          idempotencyKey: 'checkout_1234567890abcdef',
        ),
        throwsA(
          isA<MarketPaymentSessionFailure>().having(
            (failure) => failure.retryDisposition,
            'retryDisposition',
            MarketPaymentRetryDisposition.requireNewIdempotencyKey,
          ),
        ),
      );
    },
  );

  test('blocks retry when the backend reports a stale cart', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(<String, Object>{
          'error': <String, Object>{
            'code': 'product_unavailable',
            'message': 'Product is no longer available.',
          },
        }),
        409,
      );
    });
    final repository = HttpMarketPaymentSessionRepository(
      client: client,
      sessionEndpoint: Uri.parse(endpoint),
      loadAccessToken: ({required forceRefresh}) async => 'token',
    );

    await expectLater(
      repository.createSession(
        cart: cart,
        customer: customer,
        idempotencyKey: 'checkout_1234567890abcdef',
      ),
      throwsA(
        isA<MarketPaymentSessionFailure>()
            .having((failure) => failure.code, 'code', 'product_unavailable')
            .having(
              (failure) => failure.retryDisposition,
              'retryDisposition',
              MarketPaymentRetryDisposition.doNotRetry,
            ),
      ),
    );
  });

  test('fails closed when the endpoint or iframe URL is invalid', () async {
    final unconfigured = HttpMarketPaymentSessionRepository(
      client: MockClient((request) async => http.Response('{}', 500)),
      sessionEndpoint: null,
      loadAccessToken: ({required forceRefresh}) async => 'token',
    );

    await expectLater(
      unconfigured.createSession(
        cart: cart,
        customer: customer,
        idempotencyKey: 'checkout_1234567890abcdef',
      ),
      throwsA(
        isA<MarketPaymentSessionFailure>().having(
          (failure) => failure.code,
          'code',
          'payment_not_configured',
        ),
      ),
    );

    final invalidIframe = HttpMarketPaymentSessionRepository(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object>{
            'contractVersion': 1,
            'orderId': 'order-3',
            'merchantOid': 'merchant-3',
            'paymentStatus': 'awaiting_payment',
            'currencyCode': 'TRY',
            'totalMinor': 79900,
            'iframeToken': 'token-3',
            'iframeUrl': 'https://evil.example/payment/token-3',
            'merchantOkUrl': 'https://example.com/payment/success',
            'merchantFailUrl': 'https://example.com/payment/failure',
          }),
          201,
        );
      }),
      sessionEndpoint: Uri.parse(endpoint),
      loadAccessToken: ({required forceRefresh}) async => 'token',
    );

    await expectLater(
      invalidIframe.createSession(
        cart: cart,
        customer: customer,
        idempotencyKey: 'checkout_1234567890abcdef',
      ),
      throwsA(
        isA<MarketPaymentSessionFailure>().having(
          (failure) => failure.code,
          'code',
          'invalid_payment_response',
        ),
      ),
    );
  });
}

const product = MarketProduct(
  id: 'phone_tripod',
  category: MarketCategory.setup,
  price: Money(minorUnits: 79900, currencyCode: 'TRY'),
);
