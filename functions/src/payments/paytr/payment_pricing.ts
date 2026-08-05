import {randomBytes} from 'node:crypto';

import {PaymentContractError} from './payment_contract.ts';
import {serverCatalogById} from './server_catalog.ts';
import type {
  PaymentCartItemInput,
  PricedCart,
  PricedOrderLine,
  ServerCatalogProduct,
} from './payment_types.ts';

export function priceCart(
  items: readonly PaymentCartItemInput[],
  catalog: ReadonlyMap<string, ServerCatalogProduct> = serverCatalogById,
): PricedCart {
  if (items.length === 0) {
    throw new PaymentContractError('empty_cart', 'Cart cannot be empty.');
  }

  const seenProductIds = new Set<string>();
  const lines: PricedOrderLine[] = [];
  let currencyCode: ServerCatalogProduct['currencyCode'] | null = null;
  let subtotalMinor = 0;

  for (const item of items) {
    if (seenProductIds.has(item.productId)) {
      throw new PaymentContractError(
        'duplicate_product',
        `Cart contains duplicate product: ${item.productId}.`,
      );
    }
    seenProductIds.add(item.productId);
    if (
      !Number.isInteger(item.quantity) ||
      item.quantity < 1 ||
      item.quantity > 10
    ) {
      throw new PaymentContractError(
        'invalid_quantity',
        `Quantity for ${item.productId} must be between 1 and 10.`,
      );
    }

    const product = catalog.get(item.productId);
    if (product === undefined || !product.isActive) {
      throw new PaymentContractError(
        'product_unavailable',
        `Product is unavailable: ${item.productId}.`,
      );
    }
    if (currencyCode !== null && currencyCode !== product.currencyCode) {
      throw new PaymentContractError(
        'mixed_currency',
        'All cart lines must use the same currency.',
      );
    }
    currencyCode ??= product.currencyCode;

    const lineTotalMinor = product.unitPriceMinor * item.quantity;
    if (!Number.isSafeInteger(lineTotalMinor)) {
      throw new PaymentContractError(
        'unsafe_total',
        `Line total exceeds the supported integer range: ${item.productId}.`,
      );
    }
    subtotalMinor += lineTotalMinor;
    if (!Number.isSafeInteger(subtotalMinor)) {
      throw new PaymentContractError(
        'unsafe_total',
        'Cart subtotal exceeds the supported integer range.',
      );
    }

    lines.push({
      productId: product.id,
      productName: product.displayName,
      quantity: item.quantity,
      unitPriceMinor: product.unitPriceMinor,
      lineTotalMinor,
    });
  }

  if (currencyCode === null) {
    throw new PaymentContractError('empty_cart', 'Cart cannot be empty.');
  }

  return {currencyCode, subtotalMinor, lines};
}

export function encodePaytrUserBasket(cart: PricedCart): string {
  const basket = cart.lines.map((line) => [
    line.productName,
    formatMinorUnits(line.unitPriceMinor),
    line.quantity,
  ]);
  return Buffer.from(JSON.stringify(basket), 'utf8').toString('base64');
}

export function formatMinorUnits(minorUnits: number): string {
  if (!Number.isSafeInteger(minorUnits) || minorUnits < 0) {
    throw new PaymentContractError(
      'invalid_money',
      'Money must be a non-negative safe integer in minor units.',
    );
  }
  const major = Math.floor(minorUnits / 100);
  const minor = minorUnits % 100;
  return `${major}.${minor.toString().padStart(2, '0')}`;
}

export function createMerchantOid(
  nowMilliseconds: number = Date.now(),
  entropy: Uint8Array = randomBytes(8),
): string {
  if (!Number.isSafeInteger(nowMilliseconds) || nowMilliseconds < 0) {
    throw new PaymentContractError(
      'invalid_timestamp',
      'Merchant order timestamp must be a non-negative safe integer.',
    );
  }
  const timestampPart = nowMilliseconds.toString(36).toUpperCase();
  const entropyPart = Buffer.from(entropy).toString('hex').toUpperCase();
  const merchantOid = `PEA${timestampPart}${entropyPart}`;
  if (!/^[A-Z0-9]+$/.test(merchantOid) || merchantOid.length > 64) {
    throw new PaymentContractError(
      'invalid_merchant_oid',
      'Generated merchant_oid does not satisfy the PayTR contract.',
    );
  }
  return merchantOid;
}
