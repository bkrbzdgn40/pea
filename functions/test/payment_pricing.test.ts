import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';

import {PaymentContractError} from '../src/payments/paytr/payment_contract.ts';
import {
  createMerchantOid,
  encodePaytrUserBasket,
  formatMinorUnits,
  priceCart,
} from '../src/payments/paytr/payment_pricing.ts';
import {serverCatalogById} from '../src/payments/paytr/server_catalog.ts';

test('prices the cart only from the server-owned catalog', () => {
  const cart = priceCart([
    {productId: 'phone_tripod', quantity: 2},
    {productId: 'exercise_mat', quantity: 1},
  ]);

  assert.equal(cart.currencyCode, 'TRY');
  assert.equal(cart.subtotalMinor, 224700);
  assert.deepEqual(cart.lines[0], {
    productId: 'phone_tripod',
    productName: 'Telefon Tripodu',
    quantity: 2,
    unitPriceMinor: 79900,
    lineTotalMinor: 159800,
  });
});

test('rejects unknown, duplicate, and excessive cart lines', () => {
  assert.throws(
    () => priceCart([{productId: 'unknown', quantity: 1}]),
    (error) =>
      error instanceof PaymentContractError &&
      error.code === 'product_unavailable',
  );
  assert.throws(
    () =>
      priceCart([
        {productId: 'phone_tripod', quantity: 1},
        {productId: 'phone_tripod', quantity: 1},
      ]),
    (error) =>
      error instanceof PaymentContractError &&
      error.code === 'duplicate_product',
  );
  assert.throws(
    () => priceCart([{productId: 'phone_tripod', quantity: 11}]),
    (error) =>
      error instanceof PaymentContractError && error.code === 'invalid_quantity',
  );
});

test('encodes PayTR basket rows with exact two-decimal unit prices', () => {
  const cart = priceCart([{productId: 'phone_tripod', quantity: 2}]);
  const decoded = JSON.parse(
    Buffer.from(encodePaytrUserBasket(cart), 'base64').toString('utf8'),
  );

  assert.deepEqual(decoded, [['Telefon Tripodu', '799.00', 2]]);
  assert.equal(formatMinorUnits(9), '0.09');
  assert.equal(formatMinorUnits(12345), '123.45');
});

test('generates an alphanumeric merchant_oid within the PayTR limit', () => {
  const merchantOid = createMerchantOid(
    1_700_000_000_000,
    Uint8Array.from([0, 1, 2, 3, 4, 5, 6, 7]),
  );

  assert.match(merchantOid, /^[A-Z0-9]+$/);
  assert.ok(merchantOid.length <= 64);
  assert.equal(merchantOid, 'PEALOYW3V280001020304050607');
});

test('temporary server seed stays aligned with the mobile preview prices', async () => {
  const raw = await readFile('../assets/market/preview_catalog.json', 'utf8');
  const mobileCatalog = JSON.parse(raw) as {
    products: Array<{
      id: string;
      priceMinor: number;
      currencyCode: string;
    }>;
  };

  assert.equal(mobileCatalog.products.length, serverCatalogById.size);
  for (const mobileProduct of mobileCatalog.products) {
    const serverProduct = serverCatalogById.get(mobileProduct.id);
    assert.ok(serverProduct, `Missing server product: ${mobileProduct.id}`);
    assert.equal(serverProduct.unitPriceMinor, mobileProduct.priceMinor);
    assert.equal(serverProduct.currencyCode, mobileProduct.currencyCode);
  }
});
