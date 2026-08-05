import type {IncomingHttpHeaders} from 'node:http';

import {
  PaytrCallbackContractError,
  parsePaytrCallbackInput,
} from './paytr_callback_contract.ts';
import type {
  PaytrCallbackRepository,
} from './paytr_callback_repository.ts';
import {
  createPaytrCallbackHash,
  safeTokenEquals,
} from './paytr_token.ts';

export interface PaytrCallbackHttpRequest {
  readonly method: string;
  readonly headers: IncomingHttpHeaders;
  readonly body: unknown;
}

export interface PaytrCallbackHttpResponse {
  set(field: string, value: string): this;
  status(statusCode: number): this;
  type(contentType: string): this;
  send(body: string): void;
}

export interface PaytrCallbackHandlerDependencies {
  readonly repository: PaytrCallbackRepository;
  readonly getMerchantSecrets: () => {
    readonly merchantKey: string;
    readonly merchantSalt: string;
  };
  readonly logWarning?: (
    message: string,
    context: Readonly<Record<string, unknown>>,
  ) => void;
  readonly logError?: (
    message: string,
    context: Readonly<Record<string, unknown>>,
  ) => void;
}

export function createPaytrCallbackHandler(
  dependencies: PaytrCallbackHandlerDependencies,
): (
  request: PaytrCallbackHttpRequest,
  response: PaytrCallbackHttpResponse,
) => Promise<void> {
  return async (request, response) => {
    response.set('Cache-Control', 'no-store');
    response.type('text/plain');

    try {
      if (request.method !== 'POST') {
        response.set('Allow', 'POST').status(405).send('Use POST.');
        return;
      }
      if (!isFormContentType(request.headers['content-type'])) {
        response.status(415).send('Unsupported media type.');
        return;
      }

      const callback = parsePaytrCallbackInput(request.body);
      const {merchantKey, merchantSalt} = dependencies.getMerchantSecrets();
      const expectedHash = createPaytrCallbackHash(
        callback.merchantOid,
        callback.status,
        callback.totalAmountRaw,
        merchantKey,
        merchantSalt,
      );
      if (!safeTokenEquals(callback.hash, expectedHash)) {
        dependencies.logWarning?.('Rejected PayTR callback with invalid hash.', {
          merchantOid: callback.merchantOid,
        });
        response.status(400).send('PAYTR notification failed.');
        return;
      }

      const result = await dependencies.repository.apply({callback});
      if (result.kind === 'applied' || result.kind === 'already_finalized') {
        response.status(200).send('OK');
        return;
      }
      if (result.kind === 'unknown_order') {
        dependencies.logWarning?.('PayTR callback order was not found.', {
          merchantOid: callback.merchantOid,
        });
        response.status(404).send('PAYTR notification failed.');
        return;
      }

      dependencies.logWarning?.('PayTR callback did not match the order.', {
        merchantOid: callback.merchantOid,
        reason: result.reason,
      });
      response.status(409).send('PAYTR notification failed.');
    } catch (error) {
      if (error instanceof PaytrCallbackContractError) {
        response.status(400).send('PAYTR notification failed.');
        return;
      }

      dependencies.logError?.('Unhandled PayTR callback error.', {
        failureType: error instanceof Error ? error.name : typeof error,
      });
      response.status(500).send('PAYTR notification failed.');
    }
  };
}

function isFormContentType(raw: string | string[] | undefined): boolean {
  const value = Array.isArray(raw) ? raw[0] : raw;
  return value?.split(';')[0]?.trim().toLowerCase() ===
    'application/x-www-form-urlencoded';
}
