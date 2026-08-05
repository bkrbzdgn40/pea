import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createPaytrCallbackHash,
  createPaytrIframeToken,
  safeTokenEquals,
} from '../src/payments/paytr/paytr_token.ts';

test('creates the PayTR iframe token with the documented field order', () => {
  const token = createPaytrIframeToken(
    {
      merchantId: '123456',
      userIp: '203.0.113.42',
      merchantOid: 'PEATEST001',
      email: 'buyer@example.com',
      paymentAmount: 79900,
      userBasket: 'W1siVGVsZWZvbiBUcmlwb2R1IiwiNzk5LjAwIiwxXV0=',
      noInstallment: 0,
      maxInstallment: 0,
      currency: 'TL',
      testMode: 1,
    },
    'merchant-key-test',
    'merchant-salt-test',
  );

  assert.equal(token, 'eA2sQIFrRRcdSeUOgeR5TlxVB+ZuImA8rJgWNVd1wSw=');
});

test('creates and compares the callback hash without plain equality', () => {
  const hash = createPaytrCallbackHash(
    'PEATEST001',
    'success',
    '79900',
    'merchant-key-test',
    'merchant-salt-test',
  );

  assert.equal(hash, 'BCwtjBch2oHg8AAbHF9UGUEAk9LlWn7XgaRExUSCoYM=');
  assert.equal(safeTokenEquals(hash, hash), true);
  assert.equal(safeTokenEquals(hash, `${hash}x`), false);
});
