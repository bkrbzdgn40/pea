import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/payments/market_payment_session.dart';
import '../../application/payments/market_payment_session_failure.dart';
import '../../application/payments/market_payment_status.dart';
import '../../application/payments/market_payment_status_repository.dart';
import '../../domain/models/money.dart';
import 'http_market_payment_session_repository.dart';

class HttpMarketPaymentStatusRepository
    implements MarketPaymentStatusRepository {
  const HttpMarketPaymentStatusRepository({
    required http.Client client,
    required Uri? statusEndpoint,
    required MarketPaymentAccessTokenLoader loadAccessToken,
    this.requestTimeout = const Duration(seconds: 12),
  }) : _client = client,
       _statusEndpoint = statusEndpoint,
       _loadAccessToken = loadAccessToken;

  final http.Client _client;
  final Uri? _statusEndpoint;
  final MarketPaymentAccessTokenLoader _loadAccessToken;
  final Duration requestTimeout;

  @override
  Future<MarketPaymentStatus> getStatus({required String orderId}) async {
    final endpoint = _statusEndpoint;
    if (endpoint == null) {
      throw const MarketPaymentSessionFailure(
        code: 'payment_not_configured',
        message: 'PAYTR_API_BASE_URL is not configured.',
        retryDisposition: MarketPaymentRetryDisposition.doNotRetry,
      );
    }
    final normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) {
      throw const MarketPaymentSessionFailure(
        code: 'invalid_order_id',
        message: 'Payment order ID is missing.',
        retryDisposition: MarketPaymentRetryDisposition.doNotRetry,
      );
    }

    final uri = endpoint.replace(
      queryParameters: <String, String>{'orderId': normalizedOrderId},
    );

    try {
      var token = await _loadAccessToken(forceRefresh: false);
      var response = await _get(uri, token);
      if (response.statusCode == 401) {
        token = await _loadAccessToken(forceRefresh: true);
        response = await _get(uri, token);
      }
      if (response.statusCode != 200) {
        throw _failureFromResponse(response);
      }
      return _parseStatus(response, normalizedOrderId);
    } on MarketPaymentSessionFailure {
      rethrow;
    } on TimeoutException catch (error) {
      throw MarketPaymentSessionFailure(
        code: 'payment_status_timeout',
        message: 'Payment status request timed out.',
        retryDisposition: MarketPaymentRetryDisposition.reuseIdempotencyKey,
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw MarketPaymentSessionFailure(
        code: 'payment_status_network_error',
        message: 'Payment status service could not be reached.',
        retryDisposition: MarketPaymentRetryDisposition.reuseIdempotencyKey,
        cause: error,
      );
    } on FormatException catch (error) {
      throw MarketPaymentSessionFailure(
        code: 'invalid_payment_status_response',
        message: 'Payment status service returned an invalid response.',
        retryDisposition: MarketPaymentRetryDisposition.reuseIdempotencyKey,
        cause: error,
      );
    }
  }

  Future<http.Response> _get(Uri uri, String token) {
    return _client
        .get(
          uri,
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(requestTimeout);
  }

  MarketPaymentStatus _parseStatus(http.Response response, String orderId) {
    final object = _readJsonObject(response);
    if (object['contractVersion'] != marketPaymentContractVersion) {
      throw const FormatException('Unsupported payment contract version.');
    }
    if (_readString(object, 'orderId') != orderId) {
      throw const FormatException('Payment order ID does not match.');
    }
    final currencyCode = _readString(object, 'currencyCode');
    if (currencyCode != 'TRY') {
      throw const FormatException('Unsupported payment currency.');
    }
    final totalMinor = object['totalMinor'];
    if (totalMinor is! int || totalMinor <= 0) {
      throw const FormatException('Invalid totalMinor.');
    }

    final rawStatus = _readString(object, 'paymentStatus');
    final value = switch (rawStatus) {
      'not_started' => MarketPaymentStatusValue.pending,
      'paid' => MarketPaymentStatusValue.paid,
      'failed' => MarketPaymentStatusValue.failed,
      _ => throw const FormatException('Unexpected payment status.'),
    };

    return MarketPaymentStatus(
      orderId: orderId,
      merchantOid: _readString(object, 'merchantOid'),
      orderStatus: _readString(object, 'orderStatus'),
      value: value,
      total: Money(minorUnits: totalMinor, currencyCode: currencyCode),
    );
  }

  MarketPaymentSessionFailure _failureFromResponse(http.Response response) {
    String code = 'payment_status_unavailable';
    String message = 'Payment status could not be loaded.';
    String? requestId;
    try {
      final object = _readJsonObject(response);
      final error = object['error'];
      if (error is Map<String, dynamic>) {
        code = _readOptionalString(error, 'code') ?? code;
        message = _readOptionalString(error, 'message') ?? message;
        requestId = _readOptionalString(error, 'requestId');
      }
    } on FormatException {
      // Keep the generic public failure.
    }
    return MarketPaymentSessionFailure(
      code: code,
      message: message,
      requestId: requestId,
      retryDisposition:
          code == 'unauthenticated' ||
              code == 'payment_order_not_found' ||
              response.statusCode == 400
          ? MarketPaymentRetryDisposition.doNotRetry
          : MarketPaymentRetryDisposition.reuseIdempotencyKey,
    );
  }

  Map<String, dynamic> _readJsonObject(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Response must be a JSON object.');
    }
    return decoded;
  }

  String _readString(Map<String, dynamic> object, String key) {
    final value = object[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value.trim();
  }

  String? _readOptionalString(Map<String, dynamic> object, String key) {
    final value = object[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }
}
