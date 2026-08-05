import assert from 'node:assert/strict';
import test from 'node:test';

import {
  fingerprintPaymentRequest,
  hashIdempotencyKey,
  parseIdempotencyKey,
  PaymentIdempotencyError,
} from '../src/payments/paytr/payment_idempotency.ts';

test('accepts URL-safe idempotency keys and hashes them per user', () => {
  const key = parseIdempotencyKey('checkout_2026-08-04_ABC123');
  assert.equal(key, 'checkout_2026-08-04_ABC123');
  assert.notEqual(hashIdempotencyKey('user-a', key), hashIdempotencyKey('user-b', key));
  assert.equal(hashIdempotencyKey('user-a', key).length, 64);
});

test('rejects missing, short, and ambiguous idempotency headers', () => {
  for (const raw of [undefined, 'short', ['one', 'two']]) {
    assert.throws(
      () => parseIdempotencyKey(raw),
      (error) => error instanceof PaymentIdempotencyError,
    );
  }
});

test('fingerprint is stable when cart item order changes', () => {
  const customer = {
    email: 'buyer@example.com',
    fullName: 'Buyer',
    phone: '05551234567',
    address: 'Address',
  };
  const cart = {
    currencyCode: 'TRY' as const,
    subtotalMinor: 144800,
    lines: [],
  };
  const first = fingerprintPaymentRequest(
    'user-a',
    {
      contractVersion: 1,
      items: [
        {productId: 'phone_tripod', quantity: 1},
        {productId: 'exercise_mat', quantity: 1},
      ],
      customer,
    },
    cart,
  );
  const second = fingerprintPaymentRequest(
    'user-a',
    {
      contractVersion: 1,
      items: [
        {productId: 'exercise_mat', quantity: 1},
        {productId: 'phone_tripod', quantity: 1},
      ],
      customer,
    },
    cart,
  );

  assert.equal(first, second);
});
