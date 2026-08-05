import {createHmac, timingSafeEqual} from 'node:crypto';

import type {PaytrCurrency} from './payment_types.ts';

export interface PaytrIframeTokenInput {
  readonly merchantId: string;
  readonly userIp: string;
  readonly merchantOid: string;
  readonly email: string;
  readonly paymentAmount: number;
  readonly userBasket: string;
  readonly noInstallment: 0 | 1;
  readonly maxInstallment: number;
  readonly currency: PaytrCurrency;
  readonly testMode: 0 | 1;
}

export function createPaytrIframeToken(
  input: PaytrIframeTokenInput,
  merchantKey: string,
  merchantSalt: string,
): string {
  const hashString = [
    input.merchantId,
    input.userIp,
    input.merchantOid,
    input.email,
    input.paymentAmount.toString(),
    input.userBasket,
    input.noInstallment.toString(),
    input.maxInstallment.toString(),
    input.currency,
    input.testMode.toString(),
  ].join('');

  return createHmac('sha256', merchantKey)
    .update(hashString + merchantSalt, 'utf8')
    .digest('base64');
}

export function createPaytrCallbackHash(
  merchantOid: string,
  status: string,
  totalAmount: string,
  merchantKey: string,
  merchantSalt: string,
): string {
  return createHmac('sha256', merchantKey)
    .update(`${merchantOid}${merchantSalt}${status}${totalAmount}`, 'utf8')
    .digest('base64');
}

export function safeTokenEquals(actual: string, expected: string): boolean {
  const actualBuffer = Buffer.from(actual, 'utf8');
  const expectedBuffer = Buffer.from(expected, 'utf8');
  return (
    actualBuffer.length === expectedBuffer.length &&
    timingSafeEqual(actualBuffer, expectedBuffer)
  );
}
