import {createHash} from 'node:crypto';

import type {CreatePaymentSessionInput, PricedCart} from './payment_types.ts';

const idempotencyKeyPattern = /^[A-Za-z0-9._~-]{16,80}$/;

export class PaymentIdempotencyError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = 'PaymentIdempotencyError';
    this.code = code;
  }
}

export function parseIdempotencyKey(raw: string | string[] | undefined): string {
  if (Array.isArray(raw) || typeof raw !== 'string') {
    throw new PaymentIdempotencyError(
      'missing_idempotency_key',
      'Idempotency-Key header is required.',
    );
  }

  const value = raw.trim();
  if (!idempotencyKeyPattern.test(value)) {
    throw new PaymentIdempotencyError(
      'invalid_idempotency_key',
      'Idempotency-Key must contain 16-80 URL-safe characters.',
    );
  }
  return value;
}

export function hashIdempotencyKey(userId: string, key: string): string {
  return createHash('sha256').update(`${userId}\u0000${key}`, 'utf8').digest('hex');
}

export function fingerprintPaymentRequest(
  userId: string,
  input: CreatePaymentSessionInput,
  cart: PricedCart,
): string {
  const normalizedItems = [...input.items]
    .map((item) => ({productId: item.productId, quantity: item.quantity}))
    .sort((left, right) => left.productId.localeCompare(right.productId));

  const canonical = JSON.stringify({
    userId,
    contractVersion: input.contractVersion,
    items: normalizedItems,
    customer: input.customer,
    currencyCode: cart.currencyCode,
    subtotalMinor: cart.subtotalMinor,
  });

  return createHash('sha256').update(canonical, 'utf8').digest('hex');
}
