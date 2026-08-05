import assert from 'node:assert/strict';
import test from 'node:test';

import {
  PaytrGatewayError,
  paytrTokenEndpoint,
  requestPaytrIframeToken,
  type PaytrGatewayConfig,
} from '../src/payments/paytr/paytr_client.ts';

const config: PaytrGatewayConfig = {
  merchantId: '123456',
  merchantKey: 'merchant-key-test',
  merchantSalt: 'merchant-salt-test',
  merchantOkUrl: 'https://staging.example.com/paytr/success',
  merchantFailUrl: 'https://staging.example.com/paytr/failure',
  testMode: 1,
  debugOn: 1,
  noInstallment: 1,
  maxInstallment: 0,
  timeoutLimitMinutes: 30,
  requestTimeoutMilliseconds: 5000,
  language: 'tr',
};

const request = {
  userIp: '203.0.113.42',
  merchantOid: 'PEATEST001',
  customer: {
    email: 'buyer@example.com',
    fullName: 'Buyer Name',
    phone: '05551234567',
    address: 'Delivery Address',
  },
  cart: {
    currencyCode: 'TRY' as const,
    subtotalMinor: 79900,
    lines: [
      {
        productId: 'phone_tripod',
        productName: 'Telefon Tripodu',
        quantity: 1,
        unitPriceMinor: 79900,
        lineTotalMinor: 79900,
      },
    ],
  },
  userBasket: 'W1siVGVsZWZvbiBUcmlwb2R1IiwiNzk5LjAwIiwxXV0=',
};

test('posts the documented form fields and returns an iframe session', async () => {
  const capture = {
    calledUrl: '',
    postedForm: new URLSearchParams(),
  };
  const result = await requestPaytrIframeToken(
    request,
    config,
    async (input, init) => {
      capture.calledUrl = input.toString();
      capture.postedForm = new URLSearchParams(init?.body?.toString());
      return new Response(
        JSON.stringify({status: 'success', token: 'opaque_token_123'}),
        {status: 200},
      );
    },
  );

  assert.equal(capture.calledUrl, paytrTokenEndpoint);
  assert.equal(capture.postedForm.get('merchant_oid'), 'PEATEST001');
  assert.equal(capture.postedForm.get('payment_amount'), '79900');
  assert.equal(capture.postedForm.get('currency'), 'TL');
  assert.equal(capture.postedForm.get('test_mode'), '1');
  assert.equal(capture.postedForm.get('no_installment'), '1');
  assert.ok(capture.postedForm.get('paytr_token'));
  assert.equal(capture.postedForm.has('merchant_key'), false);
  assert.equal(capture.postedForm.has('merchant_salt'), false);
  assert.deepEqual(result, {
    iframeToken: 'opaque_token_123',
    iframeUrl: 'https://www.paytr.com/odeme/guvenli/opaque_token_123',
  });
});

test('maps PayTR rejection to a provider error without exposing secrets', async () => {
  await assert.rejects(
    requestPaytrIframeToken(
      request,
      config,
      async () => new Response(
        JSON.stringify({status: 'failed', reason: 'Invalid merchant value'}),
        {status: 200},
      ),
    ),
    (error) =>
      error instanceof PaytrGatewayError &&
      error.code === 'paytr_rejected' &&
      error.providerReason === 'Invalid merchant value',
  );
});

test('rejects non-HTTPS PayTR redirect configuration', async () => {
  await assert.rejects(
    requestPaytrIframeToken(
      request,
      {...config, merchantOkUrl: 'http://example.com/success'},
      async () => new Response('{}', {status: 200}),
    ),
    (error) =>
      error instanceof PaytrGatewayError &&
      error.code === 'paytr_configuration_error',
  );
});
