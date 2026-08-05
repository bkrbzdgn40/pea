import type {IncomingHttpHeaders} from 'node:http';

import {PaymentContractError, parseCreatePaymentSessionInput} from './payment_contract.ts';
import {
  fingerprintPaymentRequest,
  hashIdempotencyKey,
  parseIdempotencyKey,
  PaymentIdempotencyError,
} from './payment_idempotency.ts';
import {createMerchantOid, encodePaytrUserBasket, priceCart} from './payment_pricing.ts';
import {
  PaymentRequestContextError,
  readBearerToken,
  readClientIp,
  readRequestId,
} from './payment_request_context.ts';
import {
  PaytrGatewayError,
  type PaytrGatewayConfig,
  type PaytrSessionResult,
} from './paytr_client.ts';
import type {
  PaymentSessionRepository,
  PaymentSessionResponse,
} from './payment_session_repository.ts';

export interface PaymentHttpRequest {
  readonly method: string;
  readonly headers: IncomingHttpHeaders;
  readonly body: unknown;
  readonly ip: string | undefined;
}

export interface PaymentHttpResponse {
  set(field: string, value: string): this;
  status(statusCode: number): this;
  json(body: unknown): void;
}

export interface PaymentSessionHandlerDependencies {
  readonly verifyIdToken: (token: string) => Promise<{readonly uid: string}>;
  readonly repository: PaymentSessionRepository;
  readonly getGatewayConfig: () => PaytrGatewayConfig;
  readonly requestPaytrSession: (
    input: {
      readonly userIp: string;
      readonly merchantOid: string;
      readonly customer: ReturnType<typeof parseCreatePaymentSessionInput>['customer'];
      readonly cart: ReturnType<typeof priceCart>;
      readonly userBasket: string;
    },
    config: PaytrGatewayConfig,
  ) => Promise<PaytrSessionResult>;
  readonly nowMilliseconds?: () => number;
  readonly createMerchantOid?: () => string;
  readonly logError?: (
    message: string,
    context: Readonly<Record<string, unknown>>,
  ) => void;
}

export function createPaymentSessionHandler(
  dependencies: PaymentSessionHandlerDependencies,
): (request: PaymentHttpRequest, response: PaymentHttpResponse) => Promise<void> {
  return async (request, response) => {
    const requestId = readRequestId(request.headers['x-cloud-trace-context']);
    response.set('Cache-Control', 'no-store');

    try {
      if (request.method !== 'POST') {
        response.set('Allow', 'POST');
        sendError(response, 405, 'method_not_allowed', 'Use POST.', requestId);
        return;
      }
      if (!isJsonContentType(request.headers['content-type'])) {
        sendError(
          response,
          415,
          'unsupported_media_type',
          'Content-Type must be application/json.',
          requestId,
        );
        return;
      }

      const idToken = readBearerToken(request.headers.authorization);
      let decodedToken: {readonly uid: string};
      try {
        decodedToken = await dependencies.verifyIdToken(idToken);
      } catch {
        throw new PaymentRequestContextError(
          'unauthenticated',
          'Firebase ID token is invalid or expired.',
        );
      }
      if (decodedToken.uid.trim().length === 0) {
        throw new PaymentRequestContextError(
          'unauthenticated',
          'Verified Firebase token did not contain a user ID.',
        );
      }

      const input = parseCreatePaymentSessionInput(request.body);
      const idempotencyKey = parseIdempotencyKey(
        request.headers['idempotency-key'],
      );
      const userIp = readClientIp(
        request.headers['x-forwarded-for'],
        request.ip,
      );
      const cart = priceCart(input.items);
      const idempotencyHash = hashIdempotencyKey(
        decodedToken.uid,
        idempotencyKey,
      );
      const requestFingerprint = fingerprintPaymentRequest(
        decodedToken.uid,
        input,
        cart,
      );
      const merchantOid = dependencies.createMerchantOid?.() ?? createMerchantOid();
      const nowMilliseconds = dependencies.nowMilliseconds?.() ?? Date.now();

      const reservation = await dependencies.repository.reserve({
        userId: decodedToken.uid,
        contractVersion: input.contractVersion,
        idempotencyHash,
        requestFingerprint,
        customer: input.customer,
        cart,
        merchantOid,
        nowMilliseconds,
      });

      const gatewayConfig = dependencies.getGatewayConfig();
      if (reservation.kind === 'replay') {
        response.status(200).json(
          publicSessionResponse(reservation.response, gatewayConfig),
        );
        return;
      }
      if (reservation.kind === 'conflict') {
        sendError(
          response,
          409,
          'idempotency_conflict',
          'Idempotency-Key was already used with a different request.',
          requestId,
        );
        return;
      }
      if (reservation.kind === 'in_progress') {
        sendError(
          response,
          409,
          'payment_session_in_progress',
          'Payment session creation is already in progress.',
          requestId,
        );
        return;
      }
      if (reservation.kind === 'failed') {
        sendError(
          response,
          409,
          'payment_session_previously_failed',
          'Use a new Idempotency-Key to start another payment session.',
          requestId,
        );
        return;
      }
      if (reservation.kind === 'finalized') {
        sendError(
          response,
          409,
          'payment_already_finalized',
          'This payment session has already been finalized.',
          requestId,
        );
        return;
      }

      let paytrSession: PaytrSessionResult;
      try {
        paytrSession = await dependencies.requestPaytrSession(
          {
            userIp,
            merchantOid: reservation.merchantOid,
            customer: input.customer,
            cart,
            userBasket: encodePaytrUserBasket(cart),
          },
          gatewayConfig,
        );
      } catch (error) {
        const gatewayError = error instanceof PaytrGatewayError
          ? error
          : new PaytrGatewayError(
            'paytr_unavailable',
            'PayTR payment session could not be created.',
          );
        try {
          await dependencies.repository.markFailed({
            userId: decodedToken.uid,
            orderId: reservation.orderId,
            attemptId: reservation.attemptId,
            idempotencyHash,
            merchantOid: reservation.merchantOid,
            failureCode: gatewayError.code,
            providerReason: gatewayError.providerReason,
          });
        } catch (markError) {
          dependencies.logError?.('Failed to persist PayTR session failure.', {
            requestId,
            orderId: reservation.orderId,
            failureType: errorName(markError),
          });
        }
        throw gatewayError;
      }

      await dependencies.repository.markReady({
        userId: decodedToken.uid,
        orderId: reservation.orderId,
        attemptId: reservation.attemptId,
        idempotencyHash,
        merchantOid: reservation.merchantOid,
        iframeToken: paytrSession.iframeToken,
        iframeUrl: paytrSession.iframeUrl,
      });

      const payload: PaymentSessionResponse = {
        contractVersion: input.contractVersion,
        orderId: reservation.orderId,
        merchantOid: reservation.merchantOid,
        paymentStatus: 'awaiting_payment',
        currencyCode: cart.currencyCode,
        totalMinor: cart.subtotalMinor,
        iframeToken: paytrSession.iframeToken,
        iframeUrl: paytrSession.iframeUrl,
      };
      response.status(201).json(publicSessionResponse(payload, gatewayConfig));
    } catch (error) {
      handleError(error, response, requestId, dependencies.logError);
    }
  };
}


function publicSessionResponse(
  response: PaymentSessionResponse,
  gatewayConfig: PaytrGatewayConfig,
): Readonly<Record<string, unknown>> {
  return {
    ...response,
    merchantOkUrl: gatewayConfig.merchantOkUrl,
    merchantFailUrl: gatewayConfig.merchantFailUrl,
  };
}

function handleError(
  error: unknown,
  response: PaymentHttpResponse,
  requestId: string,
  logError: PaymentSessionHandlerDependencies['logError'],
): void {
  if (error instanceof PaymentRequestContextError) {
    const status = error.code === 'unauthenticated' ? 401 : 400;
    sendError(response, status, error.code, error.message, requestId);
    return;
  }
  if (error instanceof PaymentIdempotencyError) {
    sendError(response, 400, error.code, error.message, requestId);
    return;
  }
  if (error instanceof PaymentContractError) {
    const status = ['product_unavailable', 'mixed_currency'].includes(error.code)
      ? 409
      : 400;
    sendError(response, status, error.code, error.message, requestId);
    return;
  }
  if (error instanceof PaytrGatewayError) {
    const status = error.code === 'paytr_timeout'
      ? 504
      : error.code === 'paytr_configuration_error'
        ? 500
        : 502;
    sendError(
      response,
      status,
      'payment_session_unavailable',
      'Payment session could not be created.',
      requestId,
    );
    return;
  }

  logError?.('Unhandled PayTR payment-session error.', {
    requestId,
    failureType: errorName(error),
  });
  sendError(
    response,
    500,
    'internal_error',
    'An internal payment error occurred.',
    requestId,
  );
}

function sendError(
  response: PaymentHttpResponse,
  status: number,
  code: string,
  message: string,
  requestId: string,
): void {
  response.status(status).json({error: {code, message, requestId}});
}

function isJsonContentType(raw: string | string[] | undefined): boolean {
  const value = Array.isArray(raw) ? raw[0] : raw;
  return value?.split(';')[0]?.trim().toLowerCase() === 'application/json';
}

function errorName(error: unknown): string {
  return error instanceof Error ? error.name : typeof error;
}
