import assert from 'node:assert/strict';
import test from 'node:test';

import {PaytrGatewayError} from '../src/payments/paytr/paytr_client.ts';
import {createPaymentSessionHandler} from '../src/payments/paytr/payment_session_handler.ts';
import type {
  MarkPaymentSessionFailedInput,
  MarkPaymentSessionReadyInput,
  PaymentSessionRepository,
  ReservePaymentSessionInput,
  ReservePaymentSessionResult,
} from '../src/payments/paytr/payment_session_repository.ts';

class FakeRepository implements PaymentSessionRepository {
  reserveResult: ReservePaymentSessionResult = {
    kind: 'reserved',
    orderId: 'order-1',
    attemptId: 'attempt-1',
    merchantOid: 'PEATEST001',
  };
  reserveInputs: ReservePaymentSessionInput[] = [];
  readyInputs: MarkPaymentSessionReadyInput[] = [];
  failedInputs: MarkPaymentSessionFailedInput[] = [];

  async reserve(input: ReservePaymentSessionInput) {
    this.reserveInputs.push(input);
    return this.reserveResult;
  }

  async markReady(input: MarkPaymentSessionReadyInput) {
    this.readyInputs.push(input);
  }

  async markFailed(input: MarkPaymentSessionFailedInput) {
    this.failedInputs.push(input);
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

function createRequest() {
  return {
    method: 'POST',
    headers: {
      authorization: 'Bearer firebase-token',
      'content-type': 'application/json',
      'idempotency-key': 'checkout_2026-08-04_ABC123',
      'x-forwarded-for': '203.0.113.42, 10.0.0.1',
      'x-cloud-trace-context': '65011637f09e0a5179677a7429456db7/123;o=1',
    },
    body: {
      contractVersion: 1,
      items: [{productId: 'phone_tripod', quantity: 1}],
      customer: {
        email: 'buyer@example.com',
        fullName: 'Buyer Name',
        phone: '05551234567',
        address: 'Delivery Address',
      },
    },
    ip: '127.0.0.1',
  };
}

function gatewayConfig() {
  return {
    merchantId: '123456',
    merchantKey: 'key',
    merchantSalt: 'salt',
    merchantOkUrl: 'https://example.com/success',
    merchantFailUrl: 'https://example.com/failure',
    testMode: 1 as const,
    debugOn: 1 as const,
    noInstallment: 1 as const,
    maxInstallment: 0,
    timeoutLimitMinutes: 30,
    requestTimeoutMilliseconds: 5000,
    language: 'tr' as const,
  };
}

test('creates an authenticated server-priced PayTR payment session', async () => {
  const repository = new FakeRepository();
  let gatewayCalls = 0;
  const handler = createPaymentSessionHandler({
    verifyIdToken: async () => ({uid: 'user-1'}),
    repository,
    getGatewayConfig: gatewayConfig,
    requestPaytrSession: async (input) => {
      gatewayCalls += 1;
      assert.equal(input.userIp, '203.0.113.42');
      assert.equal(input.cart.subtotalMinor, 79900);
      assert.equal(input.merchantOid, 'PEATEST001');
      return {
        iframeToken: 'token-1',
        iframeUrl: 'https://www.paytr.com/odeme/guvenli/token-1',
      };
    },
    createMerchantOid: () => 'PEATEST001',
    nowMilliseconds: () => 1_700_000_000_000,
  });
  const response = new FakeResponse();

  await handler(createRequest(), response);

  assert.equal(response.statusCode, 201);
  assert.equal(gatewayCalls, 1);
  assert.equal(repository.reserveInputs.length, 1);
  assert.equal(repository.reserveInputs[0]?.cart.subtotalMinor, 79900);
  assert.equal(repository.readyInputs.length, 1);
  assert.equal(repository.failedInputs.length, 0);
  assert.deepEqual(response.body, {
    contractVersion: 1,
    orderId: 'order-1',
    merchantOid: 'PEATEST001',
    paymentStatus: 'awaiting_payment',
    currencyCode: 'TRY',
    totalMinor: 79900,
    iframeToken: 'token-1',
    iframeUrl: 'https://www.paytr.com/odeme/guvenli/token-1',
    merchantOkUrl: 'https://example.com/success',
    merchantFailUrl: 'https://example.com/failure',
  });
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
});

test('rejects invalid Firebase tokens as unauthenticated', async () => {
  const handler = createPaymentSessionHandler({
    verifyIdToken: async () => {
      throw new Error('invalid token');
    },
    repository: new FakeRepository(),
    getGatewayConfig: gatewayConfig,
    requestPaytrSession: async () => {
      throw new Error('must not be called');
    },
  });
  const response = new FakeResponse();

  await handler(createRequest(), response);

  assert.equal(response.statusCode, 401);
  assert.deepEqual(response.body, {
    error: {
      code: 'unauthenticated',
      message: 'Firebase ID token is invalid or expired.',
      requestId: '65011637f09e0a5179677a7429456db7',
    },
  });
});

test('replays an existing successful idempotent session without PayTR', async () => {
  const repository = new FakeRepository();
  repository.reserveResult = {
    kind: 'replay',
    response: {
      contractVersion: 1,
      orderId: 'order-existing',
      merchantOid: 'PEAEXISTING',
      paymentStatus: 'awaiting_payment',
      currencyCode: 'TRY',
      totalMinor: 79900,
      iframeToken: 'existing-token',
      iframeUrl: 'https://www.paytr.com/odeme/guvenli/existing-token',
    },
  };
  let gatewayCalls = 0;
  const handler = createPaymentSessionHandler({
    verifyIdToken: async () => ({uid: 'user-1'}),
    repository,
    getGatewayConfig: gatewayConfig,
    requestPaytrSession: async () => {
      gatewayCalls += 1;
      throw new Error('must not be called');
    },
  });
  const response = new FakeResponse();

  await handler(createRequest(), response);

  assert.equal(response.statusCode, 200);
  assert.equal(gatewayCalls, 0);
  assert.equal(repository.readyInputs.length, 0);
  assert.deepEqual(response.body, {
    ...repository.reserveResult.response,
    merchantOkUrl: 'https://example.com/success',
    merchantFailUrl: 'https://example.com/failure',
  });
});

test('persists PayTR token-request failure and returns a generic gateway error', async () => {
  const repository = new FakeRepository();
  const handler = createPaymentSessionHandler({
    verifyIdToken: async () => ({uid: 'user-1'}),
    repository,
    getGatewayConfig: gatewayConfig,
    requestPaytrSession: async () => {
      throw new PaytrGatewayError(
        'paytr_rejected',
        'Rejected.',
        'Provider-only diagnostic',
      );
    },
    createMerchantOid: () => 'PEATEST001',
  });
  const response = new FakeResponse();

  await handler(createRequest(), response);

  assert.equal(response.statusCode, 502);
  assert.equal(repository.failedInputs.length, 1);
  assert.equal(
    repository.failedInputs[0]?.providerReason,
    'Provider-only diagnostic',
  );
  assert.deepEqual(response.body, {
    error: {
      code: 'payment_session_unavailable',
      message: 'Payment session could not be created.',
      requestId: '65011637f09e0a5179677a7429456db7',
    },
  });
});

test('rejects replay after the callback finalized the payment', async () => {
  const repository = new FakeRepository();
  repository.reserveResult = {kind: 'finalized'};
  const handler = createPaymentSessionHandler({
    verifyIdToken: async () => ({uid: 'user-1'}),
    repository,
    getGatewayConfig: gatewayConfig,
    requestPaytrSession: async () => {
      throw new Error('must not be called');
    },
  });
  const response = new FakeResponse();

  await handler(createRequest(), response);

  assert.equal(response.statusCode, 409);
  assert.deepEqual(response.body, {
    error: {
      code: 'payment_already_finalized',
      message: 'This payment session has already been finalized.',
      requestId: '65011637f09e0a5179677a7429456db7',
    },
  });
});
