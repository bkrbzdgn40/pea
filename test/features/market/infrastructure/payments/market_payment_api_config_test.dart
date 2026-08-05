import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/market/infrastructure/payments/market_payment_api_config.dart';

void main() {
  test('builds the session endpoint from a secure function base URL', () {
    final config = MarketPaymentApiConfig.tryParse(
      'https://europe-west1-example.cloudfunctions.net/paytrApi',
    );

    expect(
      config?.sessionEndpoint.toString(),
      'https://europe-west1-example.cloudfunctions.net/'
      'paytrApi/payments/paytr/session',
    );
    expect(
      config?.statusEndpoint.toString(),
      'https://europe-west1-example.cloudfunctions.net/'
      'paytrApi/payments/paytr/status',
    );
  });

  test('allows local HTTP emulator hosts', () {
    final config = MarketPaymentApiConfig.tryParse(
      'http://10.0.2.2:5001/example/europe-west1/paytrApi/',
    );

    expect(
      config?.sessionEndpoint.toString(),
      'http://10.0.2.2:5001/example/europe-west1/'
      'paytrApi/payments/paytr/session',
    );
    expect(
      config?.statusEndpoint.toString(),
      'http://10.0.2.2:5001/example/europe-west1/'
      'paytrApi/payments/paytr/status',
    );
  });

  test('rejects insecure remote, credentialed, and malformed URLs', () {
    expect(
      MarketPaymentApiConfig.tryParse('http://example.com/paytrApi'),
      isNull,
    );
    expect(
      MarketPaymentApiConfig.tryParse('https://user@example.com/paytrApi'),
      isNull,
    );
    expect(MarketPaymentApiConfig.tryParse('not a URL'), isNull);
    expect(MarketPaymentApiConfig.tryParse(''), isNull);
  });
}
