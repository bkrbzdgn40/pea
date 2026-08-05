import assert from 'node:assert/strict';
import test from 'node:test';

import {createPaymentStatusHandler} from '../src/payments/paytr/payment_status_handler.ts';
import type {
  PaymentStatusRepository,
  PaymentStatusSnapshot,
} from '../src/payments/paytr/payment_status_repository.ts';

class FakeRepository implements PaymentStatusRepository {
  result: PaymentStatusSnapshot | null = {
    contractVersion: 1,
    orderId: 'order-1',
    merchantOid: 'merchant-1',
    orderStatus: 'paid',
    paymentStatus: 'paid',
    currencyCode: 'TRY',
    totalMinor: 79900,
  };
  calls: Array<{userId: string; orderId: string}> = [];

  async getForUser(userId: string, orderId: string) {
    this.calls.push({userId, orderId});
    return this.result;
  }
}

class FakeResponse {
  readonly headers = new Map<string, string>();
  statusCode = 200;
  body: unknown;

  set(field: string, value: string) {
    this.headers.set(field, value);
    return this;
  }

  status(statusCode: number) {
    this.statusCode = statusCode;
    return this;
  }

  json(body: unknown) {
    this.body = body;
  }
}

function request(orderId: unknown = 'order-1') {
  return {
    method: 'GET',
    headers: {
      authorization: 'Bearer firebase-token',
      'x-cloud-trace-context': '65011637f09e0a5179677a7429456db7/123;o=1',
    },
    query: {orderId},
  };
}

test('returns only the authenticated user payment status', async () => {
  const repository = new FakeRepository();
  const handler = createPaymentStatusHandler({
    verifyIdToken: async () => ({uid: 'user-1'}),
    repository,
  });
  const response = new FakeResponse();

  await handler(request(), response);

  assert.equal(response.statusCode, 200);
  assert.deepEqual(repository.calls, [{userId: 'user-1', orderId: 'order-1'}]);
  assert.deepEqual(response.body, repository.result);
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
});

test('rejects invalid tokens before reading an order', async () => {
  const repository = new FakeRepository();
  const handler = createPaymentStatusHandler({
    verifyIdToken: async () => {
      throw new Error('invalid');
    },
    repository,
  });
  const response = new FakeResponse();

  await handler(request(), response);

  assert.equal(response.statusCode, 401);
  assert.equal(repository.calls.length, 0);
});

test('returns not found without leaking another user order', async () => {
  const repository = new FakeRepository();
  repository.result = null;
  const handler = createPaymentStatusHandler({
    verifyIdToken: async () => ({uid: 'user-1'}),
    repository,
  });
  const response = new FakeResponse();

  await handler(request(), response);

  assert.equal(response.statusCode, 404);
  assert.deepEqual(response.body, {
    error: {
      code: 'payment_order_not_found',
      message: 'Payment order was not found.',
      requestId: '65011637f09e0a5179677a7429456db7',
    },
  });
});

test('rejects malformed order IDs', async () => {
  const repository = new FakeRepository();
  const handler = createPaymentStatusHandler({
    verifyIdToken: async () => ({uid: 'user-1'}),
    repository,
  });
  const response = new FakeResponse();

  await handler(request('../other-user'), response);

  assert.equal(response.statusCode, 400);
  assert.equal(repository.calls.length, 0);
});
