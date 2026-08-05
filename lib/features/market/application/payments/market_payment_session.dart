import 'package:flutter/foundation.dart';

import '../../domain/models/money.dart';

const int marketPaymentContractVersion = 1;

@immutable
class MarketPaymentSession {
  const MarketPaymentSession({
    required this.orderId,
    required this.merchantOid,
    required this.paymentStatus,
    required this.total,
    required this.iframeToken,
    required this.iframeUri,
    required this.merchantOkUri,
    required this.merchantFailUri,
  });

  final String orderId;
  final String merchantOid;
  final String paymentStatus;
  final Money total;
  final String iframeToken;
  final Uri iframeUri;
  final Uri merchantOkUri;
  final Uri merchantFailUri;
}
