import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/payments/market_checkout_customer.dart';
import '../../application/payments/market_payment_session.dart';
import '../../application/payments/market_payment_session_failure.dart';
import '../../application/payments/market_payment_session_repository.dart';
import '../../domain/models/market_cart.dart';
import '../../domain/models/money.dart';

typedef MarketPaymentAccessTokenLoader =
    Future<String> Function({required bool forceRefresh});

class HttpMarketPaymentSessionRepository
    implements MarketPaymentSessionRepository {
  const HttpMarketPaymentSessionRepository({
    required http.Client client,
    required Uri? sessionEndpoint,
    required MarketPaymentAccessTokenLoader loadAccessToken,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _client = client,
       _sessionEndpoint = sessionEndpoint,
       _loadAccessToken = loadAccessToken;

  final http.Client _client;
  final Uri? _sessionEndpoint;
  final MarketPaymentAccessTokenLoader _loadAccessToken;
  final Duration requestTimeout;

  @override
  Future<MarketPaymentSession> createSession({
    required MarketCart cart,
    required MarketCheckoutCustomer customer,
    required String idempotencyKey,
  }) async {
    final endpoint = _sessionEndpoint;
    if (endpoint == null) {
      throw const MarketPaymentSessionFailure(
        code: 'payment_not_configured',
        message: 'PAYTR_API_BASE_URL is not configured.',
        retryDisposition: MarketPaymentRetryDisposition.doNotRetry,
      );
    }

    final body = jsonEncode(<String, Object>{
      'contractVersion': marketPaymentContractVersion,
      'items': <Map<String, Object>>[
        for (final line in cart.lines)
          <String, Object>{
            'productId': line.product.id,
            'quantity': line.quantity,
          },
      ],
      'customer': customer.toJson(),
    });

    try {
      var token = await _loadAccessToken(forceRefresh: false);
      var response = await _post(
        endpoint: endpoint,
        token: token,
        idempotencyKey: idempotencyKey,
        body: body,
      );

      if (response.statusCode == 401) {
        token = await _loadAccessToken(forceRefresh: true);
        response = await _post(
          endpoint: endpoint,
          token: token,
          idempotencyKey: idempotencyKey,
          body: body,
        );
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw _failureFromResponse(response);
      }
      return _parseSession(response);
    } on MarketPaymentSessionFailure {
      rethrow;
    } on TimeoutException catch (error) {
      throw MarketPaymentSessionFailure(
        code: 'payment_session_timeout',
        message: 'Payment session request timed out.',
        retryDisposition: MarketPaymentRetryDisposition.reuseIdempotencyKey,
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw MarketPaymentSessionFailure(
        code: 'payment_session_network_error',
        message: 'Payment service could not be reached.',
        retryDisposition: MarketPaymentRetryDisposition.reuseIdempotencyKey,
        cause: error,
      );
    } on FormatException catch (error) {
      throw MarketPaymentSessionFailure(
        code: 'invalid_payment_response',
        message: 'Payment service returned an invalid response.',
        retryDisposition: MarketPaymentRetryDisposition.reuseIdempotencyKey,
        cause: error,
      );
    } catch (error) {
      throw MarketPaymentSessionFailure(
        code: 'payment_session_unavailable',
        message: 'Payment session could not be created.',
        retryDisposition: MarketPaymentRetryDisposition.reuseIdempotencyKey,
        cause: error,
      );
    }
  }

  Future<http.Response> _post({
    required Uri endpoint,
    required String token,
    required String idempotencyKey,
    required String body,
  }) {
    return _client
        .post(
          endpoint,
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Idempotency-Key': idempotencyKey,
          },
          body: body,
        )
        .timeout(requestTimeout);
  }

  MarketPaymentSession _parseSession(http.Response response) {
    final object = _readJsonObject(response);
    if (object['contractVersion'] != marketPaymentContractVersion) {
      throw const FormatException('Unsupported payment contract version.');
    }

    final currencyCode = _readString(object, 'currencyCode');
    if (currencyCode != 'TRY') {
      throw const FormatException('Unsupported payment currency.');
    }
    final paymentStatus = _readString(object, 'paymentStatus');
    if (paymentStatus != 'awaiting_payment') {
      throw const FormatException('Unexpected payment status.');
    }
    final totalMinor = object['totalMinor'];
    if (totalMinor is! int || totalMinor < 0) {
      throw const FormatException('Invalid totalMinor.');
    }

    final iframeUri = Uri.tryParse(_readString(object, 'iframeUrl'));
    if (iframeUri == null ||
        iframeUri.scheme != 'https' ||
        iframeUri.host.toLowerCase() != 'www.paytr.com' ||
        !iframeUri.path.startsWith('/odeme/guvenli/')) {
      throw const FormatException('Invalid PayTR iframe URL.');
    }
    final merchantOkUri = _readReturnUri(object, 'merchantOkUrl');
    final merchantFailUri = _readReturnUri(object, 'merchantFailUrl');

    return MarketPaymentSession(
      orderId: _readString(object, 'orderId'),
      merchantOid: _readString(object, 'merchantOid'),
      paymentStatus: paymentStatus,
      total: Money(minorUnits: totalMinor, currencyCode: currencyCode),
      iframeToken: _readString(object, 'iframeToken'),
      iframeUri: iframeUri,
      merchantOkUri: merchantOkUri,
      merchantFailUri: merchantFailUri,
    );
  }

  Uri _readReturnUri(Map<String, dynamic> object, String key) {
    final uri = Uri.tryParse(_readString(object, key));
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw FormatException('$key must be a secure absolute URL.');
    }
    return uri;
  }

  MarketPaymentSessionFailure _failureFromResponse(http.Response response) {
    String code = 'payment_session_unavailable';
    String message = 'Payment session could not be created.';
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
      // Preserve the generic public failure for malformed error responses.
    }

    return MarketPaymentSessionFailure(
      code: code,
      message: message,
      requestId: requestId,
      retryDisposition: _retryDisposition(response.statusCode, code),
    );
  }

  MarketPaymentRetryDisposition _retryDisposition(int statusCode, String code) {
    if (code == 'payment_session_previously_failed' ||
        code == 'payment_session_failed' ||
        code == 'idempotency_conflict') {
      return MarketPaymentRetryDisposition.requireNewIdempotencyKey;
    }
    if (code == 'payment_already_finalized' ||
        code == 'product_unavailable' ||
        code == 'mixed_currency' ||
        code == 'unauthenticated' ||
        statusCode == 400) {
      return MarketPaymentRetryDisposition.doNotRetry;
    }
    return MarketPaymentRetryDisposition.reuseIdempotencyKey;
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
