import assert from 'node:assert/strict';
import test from 'node:test';

import {
  PaytrCallbackContractError,
  parsePaytrCallbackInput,
} from '../src/payments/paytr/paytr_callback_contract.ts';

const callbackHash = 'BCwtjBch2oHg8AAbHF9UGUEAk9LlWn7XgaRExUSCoYM=';

test('parses a successful PayTR callback without equating collected and base amounts', () => {
  const parsed = parsePaytrCallbackInput({
    merchant_oid: 'PEATEST001',
    status: 'success',
    total_amount: '82900',
    hash: callbackHash,
    payment_type: 'card',
    currency: 'TL',
    payment_amount: '79900',
    test_mode: '1',
  });

  assert.equal(parsed.merchantOid, 'PEATEST001');
  assert.equal(parsed.status, 'success');
  assert.equal(parsed.totalAmountMinor, 82900);
  assert.equal(parsed.paymentAmountMinor, 79900);
  assert.equal(parsed.currency, 'TL');
  assert.equal(parsed.testMode, 1);
  assert.match(parsed.eventId, /^[a-f0-9]{64}$/);
});

test('parses a failed PayTR callback with provider failure details', () => {
  const parsed = parsePaytrCallbackInput({
    merchant_oid: 'PEATEST001',
    status: 'failed',
    total_amount: '79900',
    hash: callbackHash,
    payment_type: 'card',
    failed_reason_code: '1',
    failed_reason_msg: 'Kart reddedildi',
  });

  assert.equal(parsed.status, 'failed');
  assert.equal(parsed.paymentAmountMinor, null);
  assert.equal(parsed.failedReasonCode, '1');
  assert.equal(parsed.failedReasonMessage, 'Kart reddedildi');
});

test('rejects missing success-only fields and malformed money', () => {
  assert.throws(
    () => parsePaytrCallbackInput({
      merchant_oid: 'PEATEST001',
      status: 'success',
      total_amount: '799.00',
      hash: callbackHash,
      payment_type: 'card',
      currency: 'TL',
      payment_amount: '79900',
    }),
    (error) => error instanceof PaytrCallbackContractError &&
      error.code === 'invalid_money',
  );

  assert.throws(
    () => parsePaytrCallbackInput({
      merchant_oid: 'PEATEST001',
      status: 'success',
      total_amount: '79900',
      hash: callbackHash,
      payment_type: 'card',
      payment_amount: '79900',
    }),
    (error) => error instanceof PaytrCallbackContractError &&
      error.code === 'invalid_currency',
  );
});
