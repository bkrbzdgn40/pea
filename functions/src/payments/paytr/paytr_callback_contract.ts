import {createHash} from 'node:crypto';

export type PaytrCallbackStatus = 'success' | 'failed';
export type PaytrPaymentType = 'card' | 'eft';
export type PaytrCallbackCurrency = 'TL' | 'USD' | 'EUR' | 'GBP' | 'RUB';

export interface PaytrCallbackInput {
  readonly merchantOid: string;
  readonly status: PaytrCallbackStatus;
  readonly totalAmountMinor: number;
  readonly totalAmountRaw: string;
  readonly hash: string;
  readonly paymentType: PaytrPaymentType;
  readonly testMode: 0 | 1 | null;
  readonly currency: PaytrCallbackCurrency | null;
  readonly paymentAmountMinor: number | null;
  readonly paymentAmountRaw: string | null;
  readonly failedReasonCode: string | null;
  readonly failedReasonMessage: string | null;
  readonly eventId: string;
}

export class PaytrCallbackContractError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = 'PaytrCallbackContractError';
    this.code = code;
  }
}

export function parsePaytrCallbackInput(raw: unknown): PaytrCallbackInput {
  const object = readObject(raw);
  const merchantOid = readString(object.merchant_oid, 'merchant_oid', 64);
  if (!/^[A-Za-z0-9]+$/.test(merchantOid)) {
    throw new PaytrCallbackContractError(
      'invalid_merchant_oid',
      'merchant_oid must be alphanumeric.',
    );
  }

  const status = readStatus(object.status);
  const totalAmountRaw = readMoneyString(object.total_amount, 'total_amount');
  const hash = readString(object.hash, 'hash', 128);
  if (!/^[A-Za-z0-9+/]{43}=$/.test(hash)) {
    throw new PaytrCallbackContractError(
      'invalid_hash',
      'hash must be a SHA-256 HMAC Base64 value.',
    );
  }

  const paymentType = readPaymentType(object.payment_type);
  const testMode = readOptionalBinary(object.test_mode, 'test_mode');

  let currency: PaytrCallbackCurrency | null = null;
  let paymentAmountRaw: string | null = null;
  let failedReasonCode: string | null = null;
  let failedReasonMessage: string | null = null;

  if (status === 'success') {
    currency = readCurrency(object.currency);
    paymentAmountRaw = readMoneyString(
      object.payment_amount,
      'payment_amount',
    );
  } else {
    failedReasonCode = readString(
      object.failed_reason_code,
      'failed_reason_code',
      64,
    );
    failedReasonMessage = readString(
      object.failed_reason_msg,
      'failed_reason_msg',
      500,
    );
  }

  const eventId = createHash('sha256')
    .update(
      JSON.stringify({
        merchantOid,
        status,
        totalAmountRaw,
        hash,
        paymentType,
        testMode,
        currency,
        paymentAmountRaw,
        failedReasonCode,
        failedReasonMessage,
      }),
      'utf8',
    )
    .digest('hex');

  return {
    merchantOid,
    status,
    totalAmountMinor: parseMoney(totalAmountRaw, 'total_amount'),
    totalAmountRaw,
    hash,
    paymentType,
    testMode,
    currency,
    paymentAmountMinor: paymentAmountRaw === null
      ? null
      : parseMoney(paymentAmountRaw, 'payment_amount'),
    paymentAmountRaw,
    failedReasonCode,
    failedReasonMessage,
    eventId,
  };
}

function readObject(raw: unknown): Record<string, unknown> {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new PaytrCallbackContractError(
      'invalid_callback_body',
      'Callback body must be form fields.',
    );
  }
  return raw as Record<string, unknown>;
}

function readStatus(raw: unknown): PaytrCallbackStatus {
  if (raw !== 'success' && raw !== 'failed') {
    throw new PaytrCallbackContractError(
      'invalid_status',
      'status must be success or failed.',
    );
  }
  return raw;
}

function readPaymentType(raw: unknown): PaytrPaymentType {
  if (raw !== 'card' && raw !== 'eft') {
    throw new PaytrCallbackContractError(
      'invalid_payment_type',
      'payment_type must be card or eft.',
    );
  }
  return raw;
}

function readCurrency(raw: unknown): PaytrCallbackCurrency {
  if (!['TL', 'USD', 'EUR', 'GBP', 'RUB'].includes(String(raw))) {
    throw new PaytrCallbackContractError(
      'invalid_currency',
      'currency is not supported.',
    );
  }
  return raw as PaytrCallbackCurrency;
}

function readOptionalBinary(
  raw: unknown,
  fieldName: string,
): 0 | 1 | null {
  if (raw === undefined || raw === null || raw === '') {
    return null;
  }
  if (raw === '0' || raw === 0) {
    return 0;
  }
  if (raw === '1' || raw === 1) {
    return 1;
  }
  throw new PaytrCallbackContractError(
    'invalid_binary_field',
    `${fieldName} must be 0 or 1 when present.`,
  );
}

function readMoneyString(raw: unknown, fieldName: string): string {
  const value = readString(raw, fieldName, 16);
  if (!/^[0-9]+$/.test(value)) {
    throw new PaytrCallbackContractError(
      'invalid_money',
      `${fieldName} must be an integer minor-unit string.`,
    );
  }
  return value;
}

function parseMoney(raw: string, fieldName: string): number {
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new PaytrCallbackContractError(
      'invalid_money',
      `${fieldName} must be a positive safe integer.`,
    );
  }
  return value;
}

function readString(
  raw: unknown,
  fieldName: string,
  maxLength: number,
): string {
  if (typeof raw !== 'string') {
    throw new PaytrCallbackContractError(
      'invalid_string',
      `${fieldName} must be a string.`,
    );
  }
  const value = raw.trim();
  if (value.length === 0 || value.length > maxLength) {
    throw new PaytrCallbackContractError(
      'invalid_string_length',
      `${fieldName} must contain between 1 and ${maxLength} characters.`,
    );
  }
  return value;
}
