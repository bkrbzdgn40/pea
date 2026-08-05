import 'market_payment_status.dart';

abstract interface class MarketPaymentStatusRepository {
  Future<MarketPaymentStatus> getStatus({required String orderId});
}
