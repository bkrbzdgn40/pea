import {PaymentContractError} from './payment_contract.ts';
import {createPaytrIframeToken} from './paytr_token.ts';
import type {PaytrCurrency, PaymentCustomerInput, PricedCart} from './payment_types.ts';

export const paytrTokenEndpoint = 'https://www.paytr.com/odeme/api/get-token';
export const paytrIframeBaseUrl = 'https://www.paytr.com/odeme/guvenli/';

export interface PaytrGatewayConfig {
  readonly merchantId: string;
  readonly merchantKey: string;
  readonly merchantSalt: string;
  readonly merchantOkUrl: string;
  readonly merchantFailUrl: string;
  readonly testMode: 0 | 1;
  readonly debugOn: 0 | 1;
  readonly noInstallment: 0 | 1;
  readonly maxInstallment: number;
  readonly timeoutLimitMinutes: number;
  readonly requestTimeoutMilliseconds: number;
  readonly language: 'tr' | 'en';
}

export interface PaytrSessionRequest {
  readonly userIp: string;
  readonly merchantOid: string;
  readonly customer: PaymentCustomerInput;
  readonly cart: PricedCart;
  readonly userBasket: string;
}

export interface PaytrSessionResult {
  readonly iframeToken: string;
  readonly iframeUrl: string;
}

export class PaytrGatewayError extends Error {
  readonly code: string;
  readonly providerReason: string | null;

  constructor(code: string, message: string, providerReason: string | null = null) {
    super(message);
    this.name = 'PaytrGatewayError';
    this.code = code;
    this.providerReason = providerReason;
  }
}

export async function requestPaytrIframeToken(
  request: PaytrSessionRequest,
  config: PaytrGatewayConfig,
  fetchImplementation: typeof fetch = fetch,
): Promise<PaytrSessionResult> {
  validateConfig(config);
  const currency = toPaytrCurrency(request.cart.currencyCode);
  const tokenInput = {
    merchantId: config.merchantId,
    userIp: request.userIp,
    merchantOid: request.merchantOid,
    email: request.customer.email,
    paymentAmount: request.cart.subtotalMinor,
    userBasket: request.userBasket,
    noInstallment: config.noInstallment,
    maxInstallment: config.maxInstallment,
    currency,
    testMode: config.testMode,
  } as const;
  const paytrToken = createPaytrIframeToken(
    tokenInput,
    config.merchantKey,
    config.merchantSalt,
  );

  const form = new URLSearchParams({
    merchant_id: config.merchantId,
    user_ip: request.userIp,
    merchant_oid: request.merchantOid,
    email: request.customer.email,
    payment_amount: request.cart.subtotalMinor.toString(),
    paytr_token: paytrToken,
    user_basket: request.userBasket,
    debug_on: config.debugOn.toString(),
    no_installment: config.noInstallment.toString(),
    max_installment: config.maxInstallment.toString(),
    user_name: request.customer.fullName,
    user_address: request.customer.address,
    user_phone: request.customer.phone,
    merchant_ok_url: config.merchantOkUrl,
    merchant_fail_url: config.merchantFailUrl,
    timeout_limit: config.timeoutLimitMinutes.toString(),
    currency,
    test_mode: config.testMode.toString(),
    lang: config.language,
  });

  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort(),
    config.requestTimeoutMilliseconds,
  );

  try {
    const response = await fetchImplementation(paytrTokenEndpoint, {
      method: 'POST',
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: form,
      signal: controller.signal,
    });
    const rawBody = await response.text();
    if (!response.ok) {
      throw new PaytrGatewayError(
        'paytr_unavailable',
        `PayTR token endpoint returned HTTP ${response.status}.`,
      );
    }
    if (rawBody.length > 16_384) {
      throw new PaytrGatewayError(
        'paytr_invalid_response',
        'PayTR token response exceeded the supported size.',
      );
    }

    const parsed = parsePaytrResponse(rawBody);
    if (parsed.status === 'failed') {
      throw new PaytrGatewayError(
        'paytr_rejected',
        'PayTR rejected the payment-session request.',
        parsed.reason,
      );
    }

    return {
      iframeToken: parsed.token,
      iframeUrl: `${paytrIframeBaseUrl}${encodeURIComponent(parsed.token)}`,
    };
  } catch (error) {
    if (error instanceof PaytrGatewayError) {
      throw error;
    }
    if (controller.signal.aborted) {
      throw new PaytrGatewayError(
        'paytr_timeout',
        'PayTR token request timed out.',
      );
    }
    throw new PaytrGatewayError(
      'paytr_unavailable',
      'PayTR token endpoint could not be reached.',
    );
  } finally {
    clearTimeout(timeout);
  }
}

function parsePaytrResponse(
  rawBody: string,
): {readonly status: 'success'; readonly token: string} |
  {readonly status: 'failed'; readonly reason: string} {
  let value: unknown;
  try {
    value = JSON.parse(rawBody);
  } catch {
    throw new PaytrGatewayError(
      'paytr_invalid_response',
      'PayTR returned invalid JSON.',
    );
  }

  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new PaytrGatewayError(
      'paytr_invalid_response',
      'PayTR returned an invalid response object.',
    );
  }

  const object = value as Record<string, unknown>;
  if (object.status === 'success') {
    if (
      typeof object.token !== 'string' ||
      object.token.length < 1 ||
      object.token.length > 1024 ||
      /\s/.test(object.token)
    ) {
      throw new PaytrGatewayError(
        'paytr_invalid_response',
        'PayTR returned an invalid iframe token.',
      );
    }
    return {status: 'success', token: object.token};
  }

  if (object.status === 'failed') {
    const reason = typeof object.reason === 'string'
      ? object.reason.slice(0, 500)
      : 'Unspecified PayTR rejection.';
    return {status: 'failed', reason};
  }

  throw new PaytrGatewayError(
    'paytr_invalid_response',
    'PayTR returned an unknown status.',
  );
}

function toPaytrCurrency(currencyCode: PricedCart['currencyCode']): PaytrCurrency {
  if (currencyCode === 'TRY') {
    return 'TL';
  }
  throw new PaymentContractError(
    'unsupported_currency',
    `Unsupported PayTR currency: ${currencyCode}.`,
  );
}

function validateConfig(config: PaytrGatewayConfig): void {
  const requiredStrings = [
    config.merchantId,
    config.merchantKey,
    config.merchantSalt,
    config.merchantOkUrl,
    config.merchantFailUrl,
  ];
  if (requiredStrings.some((value) => value.trim().length === 0)) {
    throw new PaytrGatewayError(
      'paytr_configuration_error',
      'PayTR configuration is incomplete.',
    );
  }
  for (const url of [config.merchantOkUrl, config.merchantFailUrl]) {
    let parsed: URL;
    try {
      parsed = new URL(url);
    } catch {
      throw new PaytrGatewayError(
        'paytr_configuration_error',
        'PayTR redirect URL is invalid.',
      );
    }
    if (parsed.protocol !== 'https:') {
      throw new PaytrGatewayError(
        'paytr_configuration_error',
        'PayTR redirect URLs must use HTTPS.',
      );
    }
  }
  if (
    !Number.isInteger(config.maxInstallment) ||
    config.maxInstallment < 0 ||
    config.maxInstallment > 12
  ) {
    throw new PaytrGatewayError(
      'paytr_configuration_error',
      'PAYTR_MAX_INSTALLMENT must be an integer between 0 and 12.',
    );
  }
  if (
    !Number.isInteger(config.timeoutLimitMinutes) ||
    config.timeoutLimitMinutes < 1 ||
    config.timeoutLimitMinutes > 60
  ) {
    throw new PaytrGatewayError(
      'paytr_configuration_error',
      'PAYTR_TIMEOUT_LIMIT_MINUTES must be between 1 and 60.',
    );
  }
  if (
    !Number.isInteger(config.requestTimeoutMilliseconds) ||
    config.requestTimeoutMilliseconds < 1000 ||
    config.requestTimeoutMilliseconds > 30_000
  ) {
    throw new PaytrGatewayError(
      'paytr_configuration_error',
      'PAYTR_REQUEST_TIMEOUT_MS must be between 1000 and 30000.',
    );
  }
}
