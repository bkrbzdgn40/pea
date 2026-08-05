import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../application/payments/market_checkout_customer.dart';
import '../../application/payments/market_payment_session.dart';
import '../../application/payments/market_payment_browser.dart';
import '../../application/payments/market_payment_session_failure.dart';
import '../../application/payments/market_payment_status_repository.dart';
import '../../application/payments/market_payment_session_repository.dart';
import '../../domain/models/market_cart.dart';
import '../../infrastructure/payments/http_market_payment_session_repository.dart';
import '../../infrastructure/payments/http_market_payment_status_repository.dart';
import '../../infrastructure/payments/market_payment_api_config.dart';
import '../../infrastructure/payments/webview_market_payment_browser.dart';

final marketPaymentApiConfigProvider = Provider<MarketPaymentApiConfig?>((ref) {
  return MarketPaymentApiConfig.fromEnvironment();
});

final marketPaymentHttpClientProvider = Provider.autoDispose<http.Client>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final marketPaymentAccessTokenLoaderProvider =
    Provider<MarketPaymentAccessTokenLoader>((ref) {
      return ({required bool forceRefresh}) async {
        final firebaseAuth = ref.read(firebaseAuthProvider);
        final user = firebaseAuth.currentUser;
        if (user == null) {
          throw const MarketPaymentSessionFailure(
            code: 'unauthenticated',
            message: 'An authenticated user is required.',
            retryDisposition: MarketPaymentRetryDisposition.doNotRetry,
          );
        }
        String? token;
        try {
          token = await user.getIdToken(forceRefresh);
        } catch (error) {
          throw MarketPaymentSessionFailure(
            code: 'unauthenticated',
            message: 'Firebase ID token could not be loaded.',
            retryDisposition: MarketPaymentRetryDisposition.doNotRetry,
            cause: error,
          );
        }
        if (token == null || token.trim().isEmpty) {
          throw const MarketPaymentSessionFailure(
            code: 'unauthenticated',
            message: 'Firebase ID token could not be loaded.',
            retryDisposition: MarketPaymentRetryDisposition.doNotRetry,
          );
        }
        return token;
      };
    });

final marketPaymentSessionRepositoryProvider =
    Provider.autoDispose<MarketPaymentSessionRepository>((ref) {
      return HttpMarketPaymentSessionRepository(
        client: ref.watch(marketPaymentHttpClientProvider),
        sessionEndpoint: ref.watch(
          marketPaymentApiConfigProvider.select(
            (config) => config?.sessionEndpoint,
          ),
        ),
        loadAccessToken: ref.watch(marketPaymentAccessTokenLoaderProvider),
      );
    });

final marketPaymentStatusRepositoryProvider =
    Provider.autoDispose<MarketPaymentStatusRepository>((ref) {
      return HttpMarketPaymentStatusRepository(
        client: ref.watch(marketPaymentHttpClientProvider),
        statusEndpoint: ref.watch(
          marketPaymentApiConfigProvider.select(
            (config) => config?.statusEndpoint,
          ),
        ),
        loadAccessToken: ref.watch(marketPaymentAccessTokenLoaderProvider),
      );
    });

final marketPaymentBrowserFactoryProvider =
    Provider<MarketPaymentBrowserFactory>((ref) {
      return const WebViewMarketPaymentBrowserFactory();
    });

typedef MarketPaymentVerificationDelay =
    Future<void> Function(Duration duration);

final marketPaymentVerificationDelayProvider =
    Provider<MarketPaymentVerificationDelay>((ref) {
      return (duration) => Future<void>.delayed(duration);
    });

final marketPaymentVerificationAttemptsProvider = Provider<int>((ref) => 15);

final marketPaymentVerificationIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

typedef MarketPaymentIdempotencyKeyFactory = String Function();

final marketPaymentIdempotencyKeyFactoryProvider =
    Provider<MarketPaymentIdempotencyKeyFactory>((ref) {
      final random = Random.secure();
      return () {
        final randomPart = List<int>.generate(
          12,
          (_) => random.nextInt(256),
          growable: false,
        ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
        return 'checkout_${DateTime.now().microsecondsSinceEpoch}_$randomPart';
      };
    });

final marketPaymentSessionControllerProvider =
    StateNotifierProvider.autoDispose<
      MarketPaymentSessionController,
      MarketPaymentSessionState
    >((ref) {
      return MarketPaymentSessionController(
        repository: ref.watch(marketPaymentSessionRepositoryProvider),
        createIdempotencyKey: ref.watch(
          marketPaymentIdempotencyKeyFactoryProvider,
        ),
      );
    });

enum MarketPaymentSessionPhase { idle, submitting, ready, failed }

class MarketPaymentSessionState {
  const MarketPaymentSessionState._({
    required this.phase,
    this.session,
    this.failure,
  });

  const MarketPaymentSessionState.idle()
    : this._(phase: MarketPaymentSessionPhase.idle);

  const MarketPaymentSessionState.submitting()
    : this._(phase: MarketPaymentSessionPhase.submitting);

  const MarketPaymentSessionState.ready(MarketPaymentSession session)
    : this._(phase: MarketPaymentSessionPhase.ready, session: session);

  const MarketPaymentSessionState.failed(MarketPaymentSessionFailure failure)
    : this._(phase: MarketPaymentSessionPhase.failed, failure: failure);

  final MarketPaymentSessionPhase phase;
  final MarketPaymentSession? session;
  final MarketPaymentSessionFailure? failure;

  bool get isSubmitting => phase == MarketPaymentSessionPhase.submitting;

  bool get canSubmit =>
      !isSubmitting &&
      phase != MarketPaymentSessionPhase.ready &&
      failure?.retryDisposition != MarketPaymentRetryDisposition.doNotRetry;
}

class MarketPaymentSessionController
    extends StateNotifier<MarketPaymentSessionState> {
  MarketPaymentSessionController({
    required MarketPaymentSessionRepository repository,
    required MarketPaymentIdempotencyKeyFactory createIdempotencyKey,
  }) : _repository = repository,
       _createIdempotencyKey = createIdempotencyKey,
       super(const MarketPaymentSessionState.idle());

  final MarketPaymentSessionRepository _repository;
  final MarketPaymentIdempotencyKeyFactory _createIdempotencyKey;

  String? _requestFingerprint;
  String? _idempotencyKey;

  Future<void> createSession({
    required MarketCart cart,
    required MarketCheckoutCustomer customer,
  }) async {
    if (state.isSubmitting) {
      return;
    }

    final normalizedCustomer = customer.normalized();
    final requestFingerprint = _fingerprint(cart, normalizedCustomer);
    if (_requestFingerprint != requestFingerprint || _idempotencyKey == null) {
      _requestFingerprint = requestFingerprint;
      _idempotencyKey = _createIdempotencyKey();
    }

    state = const MarketPaymentSessionState.submitting();
    try {
      final session = await _repository.createSession(
        cart: cart,
        customer: normalizedCustomer,
        idempotencyKey: _idempotencyKey!,
      );
      state = MarketPaymentSessionState.ready(session);
    } on MarketPaymentSessionFailure catch (failure) {
      if (failure.retryDisposition ==
          MarketPaymentRetryDisposition.requireNewIdempotencyKey) {
        _idempotencyKey = null;
      }
      state = MarketPaymentSessionState.failed(failure);
    } catch (error) {
      state = MarketPaymentSessionState.failed(
        MarketPaymentSessionFailure(
          code: 'payment_session_unavailable',
          message: 'Payment session could not be created.',
          retryDisposition: MarketPaymentRetryDisposition.reuseIdempotencyKey,
          cause: error,
        ),
      );
    }
  }

  void markInputChanged() {
    if (state.phase == MarketPaymentSessionPhase.ready ||
        state.phase == MarketPaymentSessionPhase.failed) {
      state = const MarketPaymentSessionState.idle();
    }
  }

  String _fingerprint(MarketCart cart, MarketCheckoutCustomer customer) {
    final lines = <String>[
      for (final line in cart.lines) '${line.product.id}:${line.quantity}',
    ]..sort();
    return '${lines.join('|')}\u0001${customer.fingerprint}';
  }
}
