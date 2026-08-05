import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_navigation_policy.dart';
import 'package:pose_estimation_app/features/market/application/payments/market_payment_session.dart';
import 'package:pose_estimation_app/features/market/domain/models/money.dart';

void main() {
  final policy = MarketPaymentNavigationPolicy(session);

  test('intercepts configured success and failure return endpoints', () {
    expect(
      policy.decide(Uri.parse('https://merchant.example/payment/success?x=1')),
      MarketPaymentNavigationDecision.successReturn,
    );
    expect(
      policy.decide(Uri.parse('https://merchant.example/payment/failure')),
      MarketPaymentNavigationDecision.failureReturn,
    );
  });

  test('allows secure PayTR and 3D secure navigation hosts', () {
    expect(
      policy.decide(Uri.parse('https://www.paytr.com/odeme/guvenli/token')),
      MarketPaymentNavigationDecision.allow,
    );
    expect(
      policy.decide(Uri.parse('https://bank.example/3d-secure')),
      MarketPaymentNavigationDecision.allow,
    );
  });

  test('blocks insecure or local navigation schemes', () {
    expect(
      policy.decide(Uri.parse('http://bank.example/unsafe')),
      MarketPaymentNavigationDecision.block,
    );
    expect(
      policy.decide(Uri.parse('javascript:alert(1)')),
      MarketPaymentNavigationDecision.block,
    );
    expect(
      policy.decide(Uri.parse('file:///tmp/payment.html')),
      MarketPaymentNavigationDecision.block,
    );
  });
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
