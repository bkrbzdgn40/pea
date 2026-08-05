import {
  FieldValue,
  Timestamp,
  type Firestore,
} from 'firebase-admin/firestore';

import type {
  PaymentCustomerInput,
  PricedCart,
} from './payment_types.ts';

export interface ReservePaymentSessionInput {
  readonly userId: string;
  readonly contractVersion: number;
  readonly idempotencyHash: string;
  readonly requestFingerprint: string;
  readonly customer: PaymentCustomerInput;
  readonly cart: PricedCart;
  readonly merchantOid: string;
  readonly nowMilliseconds: number;
}

export interface ReservedPaymentSession {
  readonly kind: 'reserved';
  readonly orderId: string;
  readonly attemptId: string;
  readonly merchantOid: string;
}

export interface ReplayPaymentSession {
  readonly kind: 'replay';
  readonly response: PaymentSessionResponse;
}

export type ExistingPaymentSessionState =
  | {readonly kind: 'in_progress'}
  | {readonly kind: 'failed'}
  | {readonly kind: 'finalized'}
  | {readonly kind: 'conflict'};

export type ReservePaymentSessionResult =
  | ReservedPaymentSession
  | ReplayPaymentSession
  | ExistingPaymentSessionState;

export interface PaymentSessionResponse {
  readonly contractVersion: number;
  readonly orderId: string;
  readonly merchantOid: string;
  readonly paymentStatus: 'awaiting_payment';
  readonly currencyCode: PricedCart['currencyCode'];
  readonly totalMinor: number;
  readonly iframeToken: string;
  readonly iframeUrl: string;
}

export interface MarkPaymentSessionReadyInput {
  readonly userId: string;
  readonly orderId: string;
  readonly attemptId: string;
  readonly idempotencyHash: string;
  readonly merchantOid: string;
  readonly iframeToken: string;
  readonly iframeUrl: string;
}

export interface MarkPaymentSessionFailedInput {
  readonly userId: string;
  readonly orderId: string;
  readonly attemptId: string;
  readonly idempotencyHash: string;
  readonly merchantOid: string;
  readonly failureCode: string;
  readonly providerReason: string | null;
}

export interface PaymentSessionRepository {
  reserve(
    input: ReservePaymentSessionInput,
  ): Promise<ReservePaymentSessionResult>;
  markReady(input: MarkPaymentSessionReadyInput): Promise<void>;
  markFailed(input: MarkPaymentSessionFailedInput): Promise<void>;
}

export class FirestorePaymentSessionRepository
implements PaymentSessionRepository {
  private readonly firestore: Firestore;

  constructor(firestore: Firestore) {
    this.firestore = firestore;
  }

  async reserve(
    input: ReservePaymentSessionInput,
  ): Promise<ReservePaymentSessionResult> {
    const idempotencyRef = this.firestore
      .collection('_paymentSessionIdempotency')
      .doc(input.idempotencyHash);

    const orderRef = this.firestore
      .collection('users')
      .doc(input.userId)
      .collection('orders')
      .doc();
    const attemptRef = orderRef.collection('paymentAttempts').doc();
    const merchantRef = this.firestore
      .collection('_paytrMerchantOrders')
      .doc(input.merchantOid);

    return this.firestore.runTransaction(async (transaction) => {
      const idempotencySnapshot = await transaction.get(idempotencyRef);
      if (idempotencySnapshot.exists) {
        const data = idempotencySnapshot.data();
        if (data?.requestFingerprint !== input.requestFingerprint) {
          return {kind: 'conflict'};
        }

        const existingOrderPath = readRequiredString(data, 'orderPath');
        const existingAttemptPath = readRequiredString(data, 'attemptPath');
        const existingOrderRef = this.firestore.doc(existingOrderPath);
        const existingAttemptRef = this.firestore.doc(existingAttemptPath);
        const [orderSnapshot, attemptSnapshot] = await Promise.all([
          transaction.get(existingOrderRef),
          transaction.get(existingAttemptRef),
        ]);

        if (!orderSnapshot.exists || !attemptSnapshot.exists) {
          throw new Error('Payment idempotency references are inconsistent.');
        }

        const state = data.state;
        if (state === 'ready') {
          const order = orderSnapshot.data();
          const attempt = attemptSnapshot.data();
          return {
            kind: 'replay',
            response: {
              contractVersion: readRequiredNumber(order, 'contractVersion'),
              orderId: readRequiredString(order, 'id'),
              merchantOid: readRequiredString(order, 'merchantOid'),
              paymentStatus: 'awaiting_payment',
              currencyCode: readCurrencyCode(order, 'currencyCode'),
              totalMinor: readRequiredNumber(order, 'totalMinor'),
              iframeToken: readRequiredString(attempt, 'iframeToken'),
              iframeUrl: readRequiredString(attempt, 'iframeUrl'),
            },
          };
        }

        if (state === 'failed') {
          return {kind: 'failed'};
        }
        if (state === 'finalized') {
          return {kind: 'finalized'};
        }
        return {kind: 'in_progress'};
      }

      const now = Timestamp.fromMillis(input.nowMilliseconds);
      const orderPath = orderRef.path;
      const attemptPath = attemptRef.path;
      const serverTimestamp = FieldValue.serverTimestamp();

      transaction.create(idempotencyRef, {
        ownerId: input.userId,
        requestFingerprint: input.requestFingerprint,
        orderPath,
        attemptPath,
        state: 'requesting',
        createdAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });
      transaction.create(orderRef, {
        id: orderRef.id,
        ownerId: input.userId,
        contractVersion: input.contractVersion,
        merchantOid: input.merchantOid,
        status: 'payment_processing',
        paymentStatus: 'not_started',
        currencyCode: input.cart.currencyCode,
        subtotalMinor: input.cart.subtotalMinor,
        totalMinor: input.cart.subtotalMinor,
        items: input.cart.lines.map((line) => ({...line})),
        customer: {...input.customer},
        requestFingerprint: input.requestFingerprint,
        idempotencyHash: input.idempotencyHash,
        activePaymentAttemptId: attemptRef.id,
        paymentSessionState: 'requesting',
        requestedAt: now,
        createdAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });
      transaction.create(attemptRef, {
        id: attemptRef.id,
        provider: 'paytr',
        merchantOid: input.merchantOid,
        status: 'requesting',
        currencyCode: input.cart.currencyCode,
        totalMinor: input.cart.subtotalMinor,
        requestedAt: now,
        createdAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });
      transaction.create(merchantRef, {
        provider: 'paytr',
        merchantOid: input.merchantOid,
        ownerId: input.userId,
        orderId: orderRef.id,
        orderPath,
        attemptId: attemptRef.id,
        attemptPath,
        createdAt: serverTimestamp,
      });

      return {
        kind: 'reserved',
        orderId: orderRef.id,
        attemptId: attemptRef.id,
        merchantOid: input.merchantOid,
      };
    });
  }

  async markReady(input: MarkPaymentSessionReadyInput): Promise<void> {
    const orderRef = this.orderRef(input.userId, input.orderId);
    const attemptRef = orderRef
      .collection('paymentAttempts')
      .doc(input.attemptId);
    const idempotencyRef = this.firestore
      .collection('_paymentSessionIdempotency')
      .doc(input.idempotencyHash);

    await this.firestore.runTransaction(async (transaction) => {
      const orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists) {
        throw new Error('Payment order does not exist.');
      }
      const order = orderSnapshot.data();
      assertActiveAttempt(order, input.attemptId, input.merchantOid);

      const serverTimestamp = FieldValue.serverTimestamp();
      transaction.update(orderRef, {
        status: 'awaiting_payment',
        paymentStatus: 'not_started',
        paymentSessionState: 'ready',
        updatedAt: serverTimestamp,
      });
      transaction.update(attemptRef, {
        status: 'ready',
        iframeToken: input.iframeToken,
        iframeUrl: input.iframeUrl,
        completedAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });
      transaction.update(idempotencyRef, {
        state: 'ready',
        updatedAt: serverTimestamp,
      });
    });
  }

  async markFailed(input: MarkPaymentSessionFailedInput): Promise<void> {
    const orderRef = this.orderRef(input.userId, input.orderId);
    const attemptRef = orderRef
      .collection('paymentAttempts')
      .doc(input.attemptId);
    const idempotencyRef = this.firestore
      .collection('_paymentSessionIdempotency')
      .doc(input.idempotencyHash);

    await this.firestore.runTransaction(async (transaction) => {
      const orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists) {
        throw new Error('Payment order does not exist.');
      }
      const order = orderSnapshot.data();
      assertActiveAttempt(order, input.attemptId, input.merchantOid);

      const serverTimestamp = FieldValue.serverTimestamp();
      transaction.update(orderRef, {
        status: 'payment_session_failed',
        paymentSessionState: 'failed',
        updatedAt: serverTimestamp,
      });
      transaction.update(attemptRef, {
        status: 'failed',
        failureCode: input.failureCode,
        providerReason: input.providerReason,
        completedAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });
      transaction.update(idempotencyRef, {
        state: 'failed',
        failureCode: input.failureCode,
        updatedAt: serverTimestamp,
      });
    });
  }

  private orderRef(userId: string, orderId: string) {
    return this.firestore
      .collection('users')
      .doc(userId)
      .collection('orders')
      .doc(orderId);
  }
}

function assertActiveAttempt(
  data: FirebaseFirestore.DocumentData | undefined,
  attemptId: string,
  merchantOid: string,
): void {
  if (
    data?.activePaymentAttemptId !== attemptId ||
    data?.merchantOid !== merchantOid
  ) {
    throw new Error('Payment attempt no longer owns the order session.');
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

function readRequiredNumber(
  data: FirebaseFirestore.DocumentData | undefined,
  field: string,
): number {
  const value = data?.[field];
  if (typeof value !== 'number' || !Number.isSafeInteger(value)) {
    throw new Error(`Stored payment field is invalid: ${field}.`);
  }
  return value;
}

function readCurrencyCode(
  data: FirebaseFirestore.DocumentData | undefined,
  field: string,
): PricedCart['currencyCode'] {
  const value = data?.[field];
  if (value !== 'TRY') {
    throw new Error(`Stored payment field is invalid: ${field}.`);
  }
  return value;
}
