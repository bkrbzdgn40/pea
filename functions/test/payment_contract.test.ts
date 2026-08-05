import assert from 'node:assert/strict';
import test from 'node:test';

import {
  PaymentContractError,
  parseCreatePaymentSessionInput,
} from '../src/payments/paytr/payment_contract.ts';

test('parses the v1 payment-session request without a client price', () => {
  const parsed = parseCreatePaymentSessionInput({
    contractVersion: 1,
    items: [{productId: 'phone_tripod', quantity: 2}],
    customer: {
      email: 'buyer@example.com',
      fullName: 'Bekir Bozdoğan',
      phone: '05551234567',
      address: 'Konya',
    },
  });

  assert.deepEqual(parsed, {
    contractVersion: 1,
    items: [{productId: 'phone_tripod', quantity: 2}],
    customer: {
      email: 'buyer@example.com',
      fullName: 'Bekir Bozdoğan',
      phone: '05551234567',
      address: 'Konya',
    },
  });
});

test('rejects client-controlled price and status fields', () => {
  assert.throws(
    () =>
      parseCreatePaymentSessionInput({
        contractVersion: 1,
        items: [{productId: 'phone_tripod', quantity: 1}],
        customer: {
          email: 'buyer@example.com',
          fullName: 'Buyer',
          phone: '555',
          address: 'Address',
        },
        totalMinor: 1,
        paymentStatus: 'paid',
      }),
    (error) =>
      error instanceof PaymentContractError &&
      error.code === 'unexpected_field',
  );
});

test('rejects unsupported contracts and invalid PayTR customer fields', () => {
  assert.throws(
    () =>
      parseCreatePaymentSessionInput({
        contractVersion: 2,
        items: [{productId: 'phone_tripod', quantity: 1}],
        customer: {
          email: 'buyer@example.com',
          fullName: 'Buyer',
          phone: '555',
          address: 'Address',
        },
      }),
    (error) =>
      error instanceof PaymentContractError &&
      error.code === 'unsupported_contract_version',
  );

  assert.throws(
    () =>
      parseCreatePaymentSessionInput({
        contractVersion: 1,
        items: [{productId: 'phone_tripod', quantity: 1}],
        customer: {
          email: 'bekir@örnek.com',
          fullName: 'Buyer',
          phone: '555',
          address: 'Address',
        },
      }),
    (error) =>
      error instanceof PaymentContractError && error.code === 'invalid_email',
  );
});
