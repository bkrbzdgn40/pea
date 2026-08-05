import assert from 'node:assert/strict';
import test from 'node:test';

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;

test(
  'reserves, completes, and replays a payment session transactionally',
  {skip: emulatorHost === undefined},
  async () => {
    const {deleteApp, initializeApp} = await import('firebase-admin/app');
    const {getFirestore} = await import('firebase-admin/firestore');
    const {FirestorePaymentSessionRepository} = await import(
      '../src/payments/paytr/payment_session_repository.ts'
    );

    const projectId = process.env.GCLOUD_PROJECT ?? 'demo-pea-payments';
    const app = initializeApp({projectId}, `payments-test-${Date.now()}`);
    const firestore = getFirestore(app);
    const repository = new FirestorePaymentSessionRepository(firestore);
    const userId = `payment-user-${Date.now()}`;
    const idempotencyHash = 'a'.repeat(64);
    const requestFingerprint = 'b'.repeat(64);
    const merchantOid = 'PEAEMULATOR001';

    try {
      const reserved = await repository.reserve({
        userId,
        contractVersion: 1,
        idempotencyHash,
        requestFingerprint,
        customer: {
          email: 'buyer@example.com',
          fullName: 'Buyer',
          phone: '05551234567',
          address: 'Address',
        },
        cart: {
          currencyCode: 'TRY',
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
        merchantOid,
        nowMilliseconds: 1_700_000_000_000,
      });
      assert.equal(reserved.kind, 'reserved');
      if (reserved.kind !== 'reserved') {
        return;
      }

      await repository.markReady({
        userId,
        orderId: reserved.orderId,
        attemptId: reserved.attemptId,
        idempotencyHash,
        merchantOid,
        iframeToken: 'emulator-token',
        iframeUrl: 'https://www.paytr.com/odeme/guvenli/emulator-token',
      });

      const replay = await repository.reserve({
        userId,
        contractVersion: 1,
        idempotencyHash,
        requestFingerprint,
        customer: {
          email: 'buyer@example.com',
          fullName: 'Buyer',
          phone: '05551234567',
          address: 'Address',
        },
        cart: {
          currencyCode: 'TRY',
          subtotalMinor: 79900,
          lines: [],
        },
        merchantOid: 'PEAUNUSED002',
        nowMilliseconds: 1_700_000_001_000,
      });
      assert.deepEqual(replay, {
        kind: 'replay',
        response: {
          contractVersion: 1,
          orderId: reserved.orderId,
          merchantOid,
          paymentStatus: 'awaiting_payment',
          currencyCode: 'TRY',
          totalMinor: 79900,
          iframeToken: 'emulator-token',
          iframeUrl: 'https://www.paytr.com/odeme/guvenli/emulator-token',
        },
      });

      const conflict = await repository.reserve({
        userId,
        contractVersion: 1,
        idempotencyHash,
        requestFingerprint: 'c'.repeat(64),
        customer: {
          email: 'other@example.com',
          fullName: 'Other',
          phone: '05550000000',
          address: 'Other Address',
        },
        cart: {
          currencyCode: 'TRY',
          subtotalMinor: 1,
          lines: [],
        },
        merchantOid: 'PEAUNUSED003',
        nowMilliseconds: 1_700_000_002_000,
      });
      assert.deepEqual(conflict, {kind: 'conflict'});

      const orderSnapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('orders')
        .doc(reserved.orderId)
        .get();
      assert.equal(orderSnapshot.data()?.status, 'awaiting_payment');
      assert.equal(orderSnapshot.data()?.paymentSessionState, 'ready');

      const merchantSnapshot = await firestore
        .collection('_paytrMerchantOrders')
        .doc(merchantOid)
        .get();
      assert.equal(merchantSnapshot.data()?.orderId, reserved.orderId);
    } finally {
      await firestore.recursiveDelete(firestore.collection('users').doc(userId));
      await firestore
        .collection('_paymentSessionIdempotency')
        .doc(idempotencyHash)
        .delete()
        .catch(() => undefined);
      await firestore
        .collection('_paytrMerchantOrders')
        .doc(merchantOid)
        .delete()
        .catch(() => undefined);
      await deleteApp(app);
    }
  },
);
