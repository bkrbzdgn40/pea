import assert from 'node:assert/strict';
import test from 'node:test';

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;

async function createReadyPaymentSession(suffix: string) {
  const {initializeApp} = await import('firebase-admin/app');
  const {getFirestore} = await import('firebase-admin/firestore');
  const {FirestorePaymentSessionRepository} = await import(
    '../src/payments/paytr/payment_session_repository.ts'
  );

  const projectId = process.env.GCLOUD_PROJECT ?? 'demo-pea-payments';
  const app = initializeApp({projectId}, `callback-test-${suffix}-${Date.now()}`);
  const firestore = getFirestore(app);
  const sessionRepository = new FirestorePaymentSessionRepository(firestore);
  const userId = `callback-user-${suffix}-${Date.now()}`;
  const idempotencyHash = suffix.padEnd(64, 'a').slice(0, 64);
  const merchantOid = `PEACALLBACK${suffix.toUpperCase()}`;
  const reserved = await sessionRepository.reserve({
    userId,
    contractVersion: 1,
    idempotencyHash,
    requestFingerprint: suffix.padEnd(64, 'b').slice(0, 64),
    customer: {
      email: 'buyer@example.com',
      fullName: 'Buyer',
      phone: '05551234567',
      address: 'Address',
    },
    cart: {
      currencyCode: 'TRY',
      subtotalMinor: 79900,
      lines: [{
        productId: 'phone_tripod',
        productName: 'Telefon Tripodu',
        quantity: 1,
        unitPriceMinor: 79900,
        lineTotalMinor: 79900,
      }],
    },
    merchantOid,
    nowMilliseconds: 1_700_000_000_000,
  });
  assert.equal(reserved.kind, 'reserved');
  if (reserved.kind !== 'reserved') {
    throw new Error('Expected a reserved payment session.');
  }
  await sessionRepository.markReady({
    userId,
    orderId: reserved.orderId,
    attemptId: reserved.attemptId,
    idempotencyHash,
    merchantOid,
    iframeToken: 'emulator-token',
    iframeUrl: 'https://www.paytr.com/odeme/guvenli/emulator-token',
  });
  return {
    app,
    firestore,
    sessionRepository,
    userId,
    idempotencyHash,
    merchantOid,
    reserved,
  };
}

async function cleanupPaymentSession(context: Awaited<ReturnType<typeof createReadyPaymentSession>>) {
  const {deleteApp} = await import('firebase-admin/app');
  await context.firestore.recursiveDelete(
    context.firestore.collection('users').doc(context.userId),
  );
  await context.firestore
    .collection('_paymentSessionIdempotency')
    .doc(context.idempotencyHash)
    .delete()
    .catch(() => undefined);
  await context.firestore
    .collection('_paytrMerchantOrders')
    .doc(context.merchantOid)
    .delete()
    .catch(() => undefined);
  await deleteApp(context.app);
}

test(
  'finalizes a successful callback once and stores one immutable payment event',
  {skip: emulatorHost === undefined},
  async () => {
    const {FirestorePaytrCallbackRepository} = await import(
      '../src/payments/paytr/paytr_callback_repository.ts'
    );
    const {parsePaytrCallbackInput} = await import(
      '../src/payments/paytr/paytr_callback_contract.ts'
    );
    const context = await createReadyPaymentSession('success');
    const repository = new FirestorePaytrCallbackRepository(context.firestore);
    const callback = parsePaytrCallbackInput({
      merchant_oid: context.merchantOid,
      status: 'success',
      total_amount: '82900',
      hash: 'A'.repeat(43) + '=',
      payment_type: 'card',
      currency: 'TL',
      payment_amount: '79900',
      test_mode: '1',
    });

    try {
      const first = await repository.apply({callback});
      assert.deepEqual(first, {
        kind: 'applied',
        orderId: context.reserved.orderId,
        paymentStatus: 'paid',
      });
      const repeated = await repository.apply({callback});
      assert.deepEqual(repeated, {
        kind: 'already_finalized',
        orderId: context.reserved.orderId,
        paymentStatus: 'paid',
      });

      const orderRef = context.firestore
        .collection('users')
        .doc(context.userId)
        .collection('orders')
        .doc(context.reserved.orderId);
      const [orderSnapshot, attemptSnapshot, eventsSnapshot, idempotencySnapshot] =
        await Promise.all([
          orderRef.get(),
          orderRef.collection('paymentAttempts').doc(context.reserved.attemptId).get(),
          orderRef.collection('paymentEvents').get(),
          context.firestore
            .collection('_paymentSessionIdempotency')
            .doc(context.idempotencyHash)
            .get(),
        ]);

      assert.equal(orderSnapshot.data()?.status, 'paid');
      assert.equal(orderSnapshot.data()?.paymentStatus, 'paid');
      assert.equal(orderSnapshot.data()?.providerCollectedTotalMinor, 82900);
      assert.equal(orderSnapshot.data()?.providerPaymentAmountMinor, 79900);
      assert.equal(attemptSnapshot.data()?.status, 'paid');
      assert.equal(eventsSnapshot.size, 1);
      assert.equal(idempotencySnapshot.data()?.state, 'finalized');

      const replay = await context.sessionRepository.reserve({
        userId: context.userId,
        contractVersion: 1,
        idempotencyHash: context.idempotencyHash,
        requestFingerprint: 'success'.padEnd(64, 'b').slice(0, 64),
        customer: {
          email: 'buyer@example.com',
          fullName: 'Buyer',
          phone: '05551234567',
          address: 'Address',
        },
        cart: {currencyCode: 'TRY', subtotalMinor: 79900, lines: []},
        merchantOid: 'PEAUNUSED',
        nowMilliseconds: 1_700_000_001_000,
      });
      assert.deepEqual(replay, {kind: 'finalized'});
    } finally {
      await cleanupPaymentSession(context);
    }
  },
);

test(
  'rejects a success callback whose original payment amount does not match the order',
  {skip: emulatorHost === undefined},
  async () => {
    const {FirestorePaytrCallbackRepository} = await import(
      '../src/payments/paytr/paytr_callback_repository.ts'
    );
    const {parsePaytrCallbackInput} = await import(
      '../src/payments/paytr/paytr_callback_contract.ts'
    );
    const context = await createReadyPaymentSession('mismatch');
    const repository = new FirestorePaytrCallbackRepository(context.firestore);
    const callback = parsePaytrCallbackInput({
      merchant_oid: context.merchantOid,
      status: 'success',
      total_amount: '100',
      hash: 'A'.repeat(43) + '=',
      payment_type: 'card',
      currency: 'TL',
      payment_amount: '100',
    });

    try {
      assert.deepEqual(await repository.apply({callback}), {
        kind: 'rejected',
        reason: 'amount_mismatch',
      });
      const orderSnapshot = await context.firestore
        .collection('users')
        .doc(context.userId)
        .collection('orders')
        .doc(context.reserved.orderId)
        .get();
      assert.equal(orderSnapshot.data()?.paymentStatus, 'not_started');
    } finally {
      await cleanupPaymentSession(context);
    }
  },
);

test(
  'finalizes a failed callback once and ignores a contradictory later success',
  {skip: emulatorHost === undefined},
  async () => {
    const {FirestorePaytrCallbackRepository} = await import(
      '../src/payments/paytr/paytr_callback_repository.ts'
    );
    const {parsePaytrCallbackInput} = await import(
      '../src/payments/paytr/paytr_callback_contract.ts'
    );
    const context = await createReadyPaymentSession('failed');
    const repository = new FirestorePaytrCallbackRepository(context.firestore);
    const failedCallback = parsePaytrCallbackInput({
      merchant_oid: context.merchantOid,
      status: 'failed',
      total_amount: '79900',
      hash: 'A'.repeat(43) + '=',
      payment_type: 'card',
      failed_reason_code: '1',
      failed_reason_msg: 'Kart reddedildi',
      test_mode: '1',
    });
    const laterSuccess = parsePaytrCallbackInput({
      merchant_oid: context.merchantOid,
      status: 'success',
      total_amount: '79900',
      hash: 'B'.repeat(43) + '=',
      payment_type: 'card',
      currency: 'TL',
      payment_amount: '79900',
      test_mode: '1',
    });

    try {
      assert.deepEqual(await repository.apply({callback: failedCallback}), {
        kind: 'applied',
        orderId: context.reserved.orderId,
        paymentStatus: 'failed',
      });
      assert.deepEqual(await repository.apply({callback: laterSuccess}), {
        kind: 'already_finalized',
        orderId: context.reserved.orderId,
        paymentStatus: 'failed',
      });

      const orderRef = context.firestore
        .collection('users')
        .doc(context.userId)
        .collection('orders')
        .doc(context.reserved.orderId);
      const [orderSnapshot, eventsSnapshot] = await Promise.all([
        orderRef.get(),
        orderRef.collection('paymentEvents').get(),
      ]);
      assert.equal(orderSnapshot.data()?.status, 'payment_failed');
      assert.equal(orderSnapshot.data()?.paymentStatus, 'failed');
      assert.equal(orderSnapshot.data()?.paymentFailureCode, '1');
      assert.equal(eventsSnapshot.size, 1);
    } finally {
      await cleanupPaymentSession(context);
    }
  },
);
