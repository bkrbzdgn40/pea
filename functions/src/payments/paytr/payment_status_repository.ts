import type {Firestore} from 'firebase-admin/firestore';

import type {InternalCurrencyCode} from './payment_types.ts';

export type PaymentStatusValue = 'not_started' | 'paid' | 'failed';

export interface PaymentStatusSnapshot {
  readonly contractVersion: number;
  readonly orderId: string;
  readonly merchantOid: string;
  readonly orderStatus: string;
  readonly paymentStatus: PaymentStatusValue;
  readonly currencyCode: InternalCurrencyCode;
  readonly totalMinor: number;
}

export interface PaymentStatusRepository {
  getForUser(
    userId: string,
    orderId: string,
  ): Promise<PaymentStatusSnapshot | null>;
}

export class FirestorePaymentStatusRepository
implements PaymentStatusRepository {
  private readonly firestore: Firestore;

  constructor(firestore: Firestore) {
    this.firestore = firestore;
  }

  async getForUser(
    userId: string,
    orderId: string,
  ): Promise<PaymentStatusSnapshot | null> {
    const snapshot = await this.firestore
      .collection('users')
      .doc(userId)
      .collection('orders')
      .doc(orderId)
      .get();
    if (!snapshot.exists) {
      return null;
    }

    const data = snapshot.data();
    return {
      contractVersion: readRequiredInteger(data, 'contractVersion'),
      orderId: readRequiredString(data, 'id'),
      merchantOid: readRequiredString(data, 'merchantOid'),
      orderStatus: readRequiredString(data, 'status'),
      paymentStatus: readPaymentStatus(data, 'paymentStatus'),
      currencyCode: readCurrencyCode(data, 'currencyCode'),
      totalMinor: readRequiredMoney(data, 'totalMinor'),
    };
  }
}

function readRequiredString(
  data: FirebaseFirestore.DocumentData | undefined,
  field: string,
): string {
  const value = data?.[field];
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`Stored payment field is invalid: ${field}.`);
  }
  return value.trim();
}

function readRequiredInteger(
  data: FirebaseFirestore.DocumentData | undefined,
  field: string,
): number {
  const value = data?.[field];
  if (typeof value !== 'number' || !Number.isSafeInteger(value)) {
    throw new Error(`Stored payment field is invalid: ${field}.`);
  }
  return value;
}

function readRequiredMoney(
  data: FirebaseFirestore.DocumentData | undefined,
  field: string,
): number {
  const value = readRequiredInteger(data, field);
  if (value <= 0) {
    throw new Error(`Stored payment field is invalid: ${field}.`);
  }
  return value;
}

function readPaymentStatus(
  data: FirebaseFirestore.DocumentData | undefined,
  field: string,
): PaymentStatusValue {
  const value = data?.[field];
  if (value !== 'not_started' && value !== 'paid' && value !== 'failed') {
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
