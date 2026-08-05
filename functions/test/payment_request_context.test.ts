import assert from 'node:assert/strict';
import test from 'node:test';

import {
  PaymentRequestContextError,
  readBearerToken,
  readClientIp,
  readRequestId,
} from '../src/payments/paytr/payment_request_context.ts';

test('reads Firebase bearer tokens without accepting other schemes', () => {
  assert.equal(readBearerToken('Bearer firebase-token'), 'firebase-token');
  assert.throws(
    () => readBearerToken('Basic abc'),
    (error) =>
      error instanceof PaymentRequestContextError &&
      error.code === 'unauthenticated',
  );
});

test('uses the first Cloud Functions forwarded client IP', () => {
  assert.equal(
    readClientIp('203.0.113.10, 10.0.0.1', '127.0.0.1'),
    '203.0.113.10',
  );
  assert.equal(readClientIp(undefined, '::ffff:192.0.2.44'), '192.0.2.44');
});

test('uses a valid Cloud Trace ID or creates a fallback request ID', () => {
  assert.equal(
    readRequestId('65011637f09e0a5179677a7429456db7/123;o=1'),
    '65011637f09e0a5179677a7429456db7',
  );
  assert.match(readRequestId(undefined), /^[0-9a-f-]{36}$/);
});
