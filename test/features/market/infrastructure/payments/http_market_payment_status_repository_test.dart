import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_session_failure.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_status.dart';
import 'package:pose_estimation_app/features/market/domain/models/money.dart';
import 'package:pose_estimation_app/features/market/infrastructure/payments/http_market_payment_status_repository.dart';

void main() {
  final endpoint = Uri.parse(
    'https://example.com/paytrApi/payments/paytr/status',
  );

  test('loads an authenticated verified payment status', () async {
    late http.Request recordedRequest;
    final repository = HttpMarketPaymentStatusRepository(
      client: MockClient((request) async {
        recordedRequest = request;
        return http.Response(
          jsonEncode(<String, Object>{
            'contractVersion': 1,
            'orderId': 'order-1',
            'merchantOid': 'merchant-1',
            'orderStatus': 'paid',
            'paymentStatus': 'paid',
            'currencyCode': 'TRY',
            'totalMinor': 79900,
          }),
          200,
        );
      }),
      statusEndpoint: endpoint,
      loadAccessToken: ({required forceRefresh}) async => 'firebase-token',
    );

    final status = await repository.getStatus(orderId: 'order-1');

    expect(recordedRequest.method, 'GET');
    expect(recordedRequest.url.queryParameters['orderId'], 'order-1');
    expect(recordedRequest.headers['authorization'], 'Bearer firebase-token');
    expect(status.value, MarketPaymentStatusValue.paid);
    expect(status.total, const Money(minorUnits: 79900, currencyCode: 'TRY'));
  });

  test('refreshes the Firebase token once after 401', () async {
    final refreshCalls = <bool>[];
    var calls = 0;
    final repository = HttpMarketPaymentStatusRepository(
      client: MockClient((request) async {
        calls += 1;
        if (calls == 1) {
          return http.Response(
            jsonEncode(<String, Object>{
              'error': <String, Object>{
                'code': 'unauthenticated',
                'message': 'Expired.',
              },
            }),
            401,
          );
        }
        return http.Response(
          jsonEncode(<String, Object>{
            'contractVersion': 1,
            'orderId': 'order-1',
            'merchantOid': 'merchant-1',
            'orderStatus': 'awaiting_payment',
            'paymentStatus': 'not_started',
            'currencyCode': 'TRY',
            'totalMinor': 79900,
          }),
          200,
        );
      }),
      statusEndpoint: endpoint,
      loadAccessToken: ({required forceRefresh}) async {
        refreshCalls.add(forceRefresh);
        return forceRefresh ? 'fresh' : 'stale';
      },
    );

    final status = await repository.getStatus(orderId: 'order-1');

    expect(status.value, MarketPaymentStatusValue.pending);
    expect(refreshCalls, <bool>[false, true]);
  });

  test('fails closed on mismatched order IDs', () async {
    final repository = HttpMarketPaymentStatusRepository(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object>{
            'contractVersion': 1,
            'orderId': 'different-order',
            'merchantOid': 'merchant-1',
            'orderStatus': 'paid',
            'paymentStatus': 'paid',
            'currencyCode': 'TRY',
            'totalMinor': 79900,
          }),
          200,
        );
      }),
      statusEndpoint: endpoint,
      loadAccessToken: ({required forceRefresh}) async => 'token',
    );

    await expectLater(
      repository.getStatus(orderId: 'order-1'),
      throwsA(
        isA<MarketPaymentSessionFailure>().having(
          (failure) => failure.code,
          'code',
          'invalid_payment_status_response',
        ),
      ),
    );
  });
}
