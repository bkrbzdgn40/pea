import 'package:flutter/foundation.dart';

import '../../domain/models/money.dart';

enum MarketPaymentStatusValue { pending, paid, failed }

@immutable
class MarketPaymentStatus {
  const MarketPaymentStatus({
    required this.orderId,
    required this.merchantOid,
    required this.orderStatus,
    required this.value,
    required this.total,
  });

  final String orderId;
  final String merchantOid;
  final String orderStatus;
  final MarketPaymentStatusValue value;
  final Money total;

  bool get isFinal => value != MarketPaymentStatusValue.pending;
}
