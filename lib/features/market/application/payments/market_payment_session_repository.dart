import '../../domain/models/market_cart.dart';
import 'market_checkout_customer.dart';
import 'market_payment_session.dart';

abstract interface class MarketPaymentSessionRepository {
  Future<MarketPaymentSession> createSession({
    required MarketCart cart,
    required MarketCheckoutCustomer customer,
    required String idempotencyKey,
  });
}
