enum MarketPaymentRetryDisposition {
  reuseIdempotencyKey,
  requireNewIdempotencyKey,
  doNotRetry,
}

class MarketPaymentSessionFailure implements Exception {
  const MarketPaymentSessionFailure({
    required this.code,
    required this.message,
    required this.retryDisposition,
    this.requestId,
    this.cause,
  });

  final String code;
  final String message;
  final MarketPaymentRetryDisposition retryDisposition;
  final String? requestId;
  final Object? cause;

  @override
  String toString() => 'MarketPaymentSessionFailure($code): $message';
}
