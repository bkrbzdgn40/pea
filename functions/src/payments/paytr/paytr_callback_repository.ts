import {
  FieldValue,
  type Firestore,
} from 'firebase-admin/firestore';

import type {
  InternalCurrencyCode,
} from './payment_types.ts';
import type {
  PaytrCallbackCurrency,
  PaytrCallbackInput,
} from './paytr_callback_contract.ts';

export interface ApplyPaytrCallbackInput {
  readonly callback: PaytrCallbackInput;
}

export type PaytrCallbackRejectionReason =
  | 'amount_mismatch'
  | 'currency_mismatch'
  | 'invalid_payment_amount';

export type ApplyPaytrCallbackResult =
  | {
      readonly kind: 'applied';
      readonly orderId: string;
      readonly paymentStatus: 'paid' | 'failed';
    }
  | {
      readonly kind: 'already_finalized';
      readonly orderId: string;
      readonly paymentStatus: 'paid' | 'failed';
    }
  | {readonly kind: 'unknown_order'}
  | {
      readonly kind: 'rejected';
      readonly reason: PaytrCallbackRejectionReason;
    };

export interface PaytrCallbackRepository {
  apply(input: ApplyPaytrCallbackInput): Promise<ApplyPaytrCallbackResult>;
}

export class FirestorePaytrCallbackRepository
implements PaytrCallbackRepository {
  private readonly firestore: Firestore;

  constructor(firestore: Firestore) {
    this.firestore = firestore;
  }

  async apply(
    input: ApplyPaytrCallbackInput,
  ): Promise<ApplyPaytrCallbackResult> {
    const {callback} = input;
    const merchantRef = this.firestore
      .collection('_paytrMerchantOrders')
      .doc(callback.merchantOid);

    return this.firestore.runTransaction(async (transaction) => {
      const merchantSnapshot = await transaction.get(merchantRef);
      if (!merchantSnapshot.exists) {
        return {kind: 'unknown_order'};
      }

      const merchant = merchantSnapshot.data();
      const orderPath = readRequiredString(merchant, 'orderPath');
      const attemptPath = readRequiredString(merchant, 'attemptPath');
      const orderRef = this.firestore.doc(orderPath);
      const attemptRef = this.firestore.doc(attemptPath);
      const [orderSnapshot, attemptSnapshot] = await Promise.all([
        transaction.get(orderRef),
        transaction.get(attemptRef),
      ]);
      if (!orderSnapshot.exists || !attemptSnapshot.exists) {
        throw new Error('PayTR merchant lookup references are inconsistent.');
      }

      const order = orderSnapshot.data();
      const attempt = attemptSnapshot.data();
      const orderId = readRequiredString(order, 'id');
      assertLookupOwnership(merchant, order, attempt, callback.merchantOid);

      const currentPaymentStatus = order?.paymentStatus;
      if (currentPaymentStatus === 'paid' || currentPaymentStatus === 'failed') {
        return {
          kind: 'already_finalized',
          orderId,
          paymentStatus: currentPaymentStatus,
        };
      }

      const totalMinor = readRequiredMoney(order, 'totalMinor');
      const currencyCode = readCurrencyCode(order, 'currencyCode');
      const validationFailure = validateCallbackAgainstOrder(
        callback,
        totalMinor,
        currencyCode,
      );
      if (validationFailure !== null) {
        return {kind: 'rejected', reason: validationFailure};
      }

      const idempotencyHash = readRequiredString(order, 'idempotencyHash');
      const idempotencyRef = this.firestore
        .collection('_paymentSessionIdempotency')
        .doc(idempotencyHash);
      const eventRef = orderRef
        .collection('paymentEvents')
        .doc(callback.eventId);
      const serverTimestamp = FieldValue.serverTimestamp();
      const finalPaymentStatus = callback.status === 'success'
        ? 'paid'
        : 'failed';
      const finalOrderStatus = callback.status === 'success'
        ? 'paid'
        : 'payment_failed';

      transaction.create(eventRef, createEventData(callback, attemptRef.id));
      transaction.update(orderRef, {
        status: finalOrderStatus,
        paymentStatus: finalPaymentStatus,
        paymentSessionState: 'completed',
        providerPaymentType: callback.paymentType,
        providerCollectedTotalMinor: callback.totalAmountMinor,
        providerPaymentAmountMinor: callback.paymentAmountMinor,
        providerCurrency: callback.currency,
        providerTestMode: callback.testMode,
        paymentFailureCode: callback.failedReasonCode,
        paymentFailureMessage: callback.failedReasonMessage,
        paymentFinalizedAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });
      transaction.update(attemptRef, {
        status: finalPaymentStatus,
        providerPaymentType: callback.paymentType,
        providerCollectedTotalMinor: callback.totalAmountMinor,
        providerPaymentAmountMinor: callback.paymentAmountMinor,
        providerCurrency: callback.currency,
        providerTestMode: callback.testMode,
        failureCode: callback.failedReasonCode,
        providerReason: callback.failedReasonMessage,
        callbackEventId: callback.eventId,
        callbackReceivedAt: serverTimestamp,
        completedAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });
      transaction.update(merchantRef, {
        finalPaymentStatus,
        callbackEventId: callback.eventId,
        finalizedAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });
      transaction.update(idempotencyRef, {
        state: 'finalized',
        finalPaymentStatus,
        updatedAt: serverTimestamp,
      });

      return {
        kind: 'applied',
        orderId,
        paymentStatus: finalPaymentStatus,
      };
    });
  }
}

function validateCallbackAgainstOrder(
  callback: PaytrCallbackInput,
  expectedTotalMinor: number,
  expectedCurrency: InternalCurrencyCode,
): PaytrCallbackRejectionReason | null {
  if (callback.status !== 'success') {
    return null;
  }
  if (callback.paymentAmountMinor === null) {
    return 'invalid_payment_amount';
  }
  if (callback.paymentAmountMinor !== expectedTotalMinor) {
    return 'amount_mismatch';
  }
  if (callback.totalAmountMinor < callback.paymentAmountMinor) {
    return 'invalid_payment_amount';
  }
  if (toInternalCurrency(callback.currency) !== expectedCurrency) {
    return 'currency_mismatch';
  }
  return null;
}

function toInternalCurrency(
  currency: PaytrCallbackCurrency | null,
): InternalCurrencyCode | null {
  return currency === 'TL' ? 'TRY' : null;
}

function createEventData(
  callback: PaytrCallbackInput,
  attemptId: string,
): Readonly<Record<string, unknown>> {
  return {
    id: callback.eventId,
    provider: 'paytr',
    attemptId,
    merchantOid: callback.merchantOid,
    status: callback.status,
    totalAmountMinor: callback.totalAmountMinor,
    paymentAmountMinor: callback.paymentAmountMinor,
    currency: callback.currency,
    paymentType: callback.paymentType,
    testMode: callback.testMode,
    failedReasonCode: callback.failedReasonCode,
    failedReasonMessage: callback.failedReasonMessage,
    createdAt: FieldValue.serverTimestamp(),
  };
}

function assertLookupOwnership(
  merchant: FirebaseFirestore.DocumentData | undefined,
  order: FirebaseFirestore.DocumentData | undefined,
  attempt: FirebaseFirestore.DocumentData | undefined,
  merchantOid: string,
): void {
  if (
    merchant?.merchantOid !== merchantOid ||
    order?.merchantOid !== merchantOid ||
    attempt?.merchantOid !== merchantOid ||
    merchant?.orderId !== order?.id ||
    merchant?.attemptId !== attempt?.id ||
    order?.activePaymentAttemptId !== attempt?.id
  ) {
    throw new Error('PayTR callback does not own the active payment attempt.');
  }
}

function readRequiredString(
  data: FirebaseFirestore.DocumentData | undefined,
  field: string,
): string {
  const value = data?.[field];
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Stored payment field is invalid: ${field}.`);
  }
  return value;
}

function readRequiredMoney(
  data: FirebaseFirestore.DocumentData | undefined,
  field: string,
): number {
  const value = data?.[field];
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`Stored payment field is invalid: ${field}.`);
  }
  return value;
}

function readCurrencyCode(
  data: FirebaseFirestore.DocumentData | undefined,
  field: string,
): InternalCurrencyCode {
  const value = data?.[field];
  if (value !== 'TRY') {
    throw new Error(`Stored payment field is invalid: ${field}.`);
  }
  return value;
}
