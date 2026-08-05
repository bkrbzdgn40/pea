import type {IncomingHttpHeaders} from 'node:http';

import {
  PaymentRequestContextError,
  readBearerToken,
  readRequestId,
} from './payment_request_context.ts';
import type {
  PaymentStatusRepository,
} from './payment_status_repository.ts';

const orderIdPattern = /^[A-Za-z0-9_-]{1,128}$/;

export interface PaymentStatusHttpRequest {
  readonly method: string;
  readonly headers: IncomingHttpHeaders;
  readonly query: Readonly<Record<string, unknown>>;
}

export interface PaymentStatusHttpResponse {
  set(field: string, value: string): this;
  status(statusCode: number): this;
  json(body: unknown): void;
}

export interface PaymentStatusHandlerDependencies {
  readonly verifyIdToken: (token: string) => Promise<{readonly uid: string}>;
  readonly repository: PaymentStatusRepository;
  readonly logError?: (
    message: string,
    context: Readonly<Record<string, unknown>>,
  ) => void;
}

export function createPaymentStatusHandler(
  dependencies: PaymentStatusHandlerDependencies,
): (
  request: PaymentStatusHttpRequest,
  response: PaymentStatusHttpResponse,
) => Promise<void> {
  return async (request, response) => {
    const requestId = readRequestId(request.headers['x-cloud-trace-context']);
    response.set('Cache-Control', 'no-store');

    try {
      if (request.method !== 'GET') {
        response.set('Allow', 'GET');
        sendError(response, 405, 'method_not_allowed', 'Use GET.', requestId);
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

      const orderId = readOrderId(request.query.orderId);
      const status = await dependencies.repository.getForUser(
        decodedToken.uid,
        orderId,
      );
      if (status === null) {
        sendError(
          response,
          404,
          'payment_order_not_found',
          'Payment order was not found.',
          requestId,
        );
        return;
      }

      response.status(200).json(status);
    } catch (error) {
      if (error instanceof PaymentRequestContextError) {
        const statusCode = error.code === 'unauthenticated' ? 401 : 400;
        sendError(
          response,
          statusCode,
          error.code,
          error.message,
          requestId,
        );
        return;
      }

      dependencies.logError?.('Unhandled PayTR payment-status error.', {
        requestId,
        failureType: error instanceof Error ? error.name : typeof error,
      });
      sendError(
        response,
        500,
        'internal_error',
        'Payment status could not be loaded.',
        requestId,
      );
    }
  };
}

function readOrderId(raw: unknown): string {
  const value = Array.isArray(raw) ? raw[0] : raw;
  if (typeof value !== 'string' || !orderIdPattern.test(value.trim())) {
    throw new PaymentRequestContextError(
      'invalid_order_id',
      'orderId is invalid.',
    );
  }
  return value.trim();
}

function sendError(
  response: PaymentStatusHttpResponse,
  status: number,
  code: string,
  message: string,
  requestId: string,
): void {
  response.status(status).json({error: {code, message, requestId}});
}
