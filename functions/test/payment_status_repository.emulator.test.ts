import assert from 'node:assert/strict';
import test from 'node:test';

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;

test(
  'reads payment status only from the supplied user order path',
  {skip: emulatorHost === undefined},
  async () => {
    const {deleteApp, initializeApp} = await import('firebase-admin/app');
    const {getFirestore} = await import('firebase-admin/firestore');
    const {FirestorePaymentStatusRepository} = await import(
      '../src/payments/paytr/payment_status_repository.ts'
    );

    const projectId = process.env.GCLOUD_PROJECT ?? 'demo-pea-payments';
    const app = initializeApp({projectId}, `status-test-${Date.now()}`);
    const firestore = getFirestore(app);
    const repository = new FirestorePaymentStatusRepository(firestore);
    const userId = `status-user-${Date.now()}`;
    const otherUserId = `${userId}-other`;
    const orderId = 'order-1';

    try {
      await firestore
        .collection('users')
        .doc(userId)
        .collection('orders')
        .doc(orderId)
        .set({
          id: orderId,
          ownerId: userId,
          contractVersion: 1,
          merchantOid: 'merchant-1',
          status: 'paid',
          paymentStatus: 'paid',
          currencyCode: 'TRY',
          totalMinor: 79900,
        });

      const ownStatus = await repository.getForUser(userId, orderId);
      assert.deepEqual(ownStatus, {
        contractVersion: 1,
        orderId,
        merchantOid: 'merchant-1',
        orderStatus: 'paid',
        paymentStatus: 'paid',
        currencyCode: 'TRY',
        totalMinor: 79900,
      });
      assert.equal(await repository.getForUser(otherUserId, orderId), null);
    } finally {
      await firestore.recursiveDelete(firestore.collection('users').doc(userId));
      await deleteApp(app);
    }
  },
);
