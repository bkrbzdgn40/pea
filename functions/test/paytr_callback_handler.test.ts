import assert from 'node:assert/strict';
import test from 'node:test';

import {createPaytrCallbackHandler} from '../src/payments/paytr/paytr_callback_handler.ts';
import type {
  ApplyPaytrCallbackInput,
  ApplyPaytrCallbackResult,
  PaytrCallbackRepository,
} from '../src/payments/paytr/paytr_callback_repository.ts';
import {createPaytrCallbackHash} from '../src/payments/paytr/paytr_token.ts';

const merchantKey = 'merchant-key-test';
const merchantSalt = 'merchant-salt-test';

class FakeRepository implements PaytrCallbackRepository {
  result: ApplyPaytrCallbackResult = {
    kind: 'applied',
    orderId: 'order-1',
    paymentStatus: 'paid',
  };
  inputs: ApplyPaytrCallbackInput[] = [];

  async apply(input: ApplyPaytrCallbackInput) {
    this.inputs.push(input);
    return this.result;
  }
}

class FakeResponse {
  readonly headers = new Map<string, string>();
  statusCode = 200;
  contentType: string | null = null;
  body: string | null = null;

  set(field: string, value: string) {
    this.headers.set(field, value);
    return this;
  }

  status(statusCode: number) {
    this.statusCode = statusCode;
    return this;
  }

  type(contentType: string) {
    this.contentType = contentType;
    return this;
  }

  send(body: string) {
    this.body = body;
  }
}

function createCallbackRequest(overrides: Readonly<Record<string, unknown>> = {}) {
  const merchantOid = String(overrides.merchant_oid ?? 'PEATEST001');
  const status = String(overrides.status ?? 'success');
  const totalAmount = String(overrides.total_amount ?? '79900');
  return {
    method: 'POST',
    headers: {
      'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
    },
    body: {
      merchant_oid: merchantOid,
      status,
      total_amount: totalAmount,
      hash: createPaytrCallbackHash(
        merchantOid,
        status,
        totalAmount,
        merchantKey,
        merchantSalt,
      ),
      payment_type: 'card',
      currency: 'TL',
      payment_amount: '79900',
      test_mode: '1',
      ...overrides,
    },
  };
}

function createHandler(repository: PaytrCallbackRepository) {
  return createPaytrCallbackHandler({
    repository,
    getMerchantSecrets: () => ({merchantKey, merchantSalt}),
  });
}

test('applies a verified callback and responds with plain-text OK', async () => {
  const repository = new FakeRepository();
  const response = new FakeResponse();

  await createHandler(repository)(createCallbackRequest(), response);

  assert.equal(response.statusCode, 200);
  assert.equal(response.contentType, 'text/plain');
  assert.equal(response.body, 'OK');
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.equal(repository.inputs.length, 1);
  assert.equal(repository.inputs[0]?.callback.paymentAmountMinor, 79900);
});

test('returns OK for a repeated callback already finalized in Firestore', async () => {
  const repository = new FakeRepository();
  repository.result = {
    kind: 'already_finalized',
    orderId: 'order-1',
    paymentStatus: 'paid',
  };
  const response = new FakeResponse();

  await createHandler(repository)(createCallbackRequest(), response);

  assert.equal(response.statusCode, 200);
  assert.equal(response.body, 'OK');
});

test('rejects a bad hash before reading payment state', async () => {
  const repository = new FakeRepository();
  const response = new FakeResponse();
  const request = createCallbackRequest({hash: 'A'.repeat(43) + '='});

  await createHandler(repository)(request, response);

  assert.equal(response.statusCode, 400);
  assert.equal(response.body, 'PAYTR notification failed.');
  assert.equal(repository.inputs.length, 0);
});

test('does not acknowledge an unknown or mismatched order', async () => {
  const repository = new FakeRepository();
  repository.result = {kind: 'unknown_order'};
  const unknownResponse = new FakeResponse();
  await createHandler(repository)(createCallbackRequest(), unknownResponse);
  assert.equal(unknownResponse.statusCode, 404);

  repository.result = {kind: 'rejected', reason: 'amount_mismatch'};
  const mismatchResponse = new FakeResponse();
  await createHandler(repository)(createCallbackRequest(), mismatchResponse);
  assert.equal(mismatchResponse.statusCode, 409);
  assert.equal(mismatchResponse.body, 'PAYTR notification failed.');
});

test('accepts failed callbacks after verifying the failed payload hash', async () => {
  const repository = new FakeRepository();
  repository.result = {
    kind: 'applied',
    orderId: 'order-1',
    paymentStatus: 'failed',
  };
  const response = new FakeResponse();
  const request = createCallbackRequest({
    status: 'failed',
    currency: undefined,
    payment_amount: undefined,
    failed_reason_code: '1',
    failed_reason_msg: 'Kart reddedildi',
  });

  await createHandler(repository)(request, response);

  assert.equal(response.statusCode, 200);
  assert.equal(response.body, 'OK');
  assert.equal(repository.inputs[0]?.callback.status, 'failed');
});
