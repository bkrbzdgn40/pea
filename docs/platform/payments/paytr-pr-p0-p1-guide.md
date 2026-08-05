# PayTR PR-P0 + PR-P1 Preparation Guide

**Baseline:** tar274

**Contract version:** 1
**Priority:** PayTR mobile payment vertical slice

## 1. Verified current project state

- Firebase Auth and Cloud Firestore are already used by the Flutter app.
- The current Firebase emulator configuration contains Auth and Firestore only.
- No Cloud Functions codebase or Functions emulator is present.
- Market prices use integer minor units.
- Checkout is still an intentionally disabled template.
- The mobile user is authenticated anonymously before protected user data is
  written.
- tar272 and tar273 contain the same 897 regular project files after generated
  and log artifacts are excluded.

## 2. Locked integration decision

The first integration uses the PayTR iFrame API.

The mobile app does not create the PayTR token. A backend function will:

1. verify the Firebase user,
2. validate product IDs and quantities,
3. calculate the amount from a server-owned catalog,
4. create a unique alphanumeric `merchant_oid`,
5. persist an `awaiting_payment` order,
6. request the iFrame token from PayTR,
7. return only the payment-session result required by the mobile app.

Payment completion will later be decided only by the PayTR notification
callback. The success/failure redirect pages are presentation signals, not
payment authority.

## 3. PR-P0 scope

This preparation patch establishes:

- the versioned mobile-to-backend input contract,
- the PayTR field and secret ownership rules,
- the initial order status vocabulary,
- Functions source and emulator wiring,
- a deployable health endpoint,
- server-side pricing and token primitives,
- core tests.

It does not enable the checkout button or contact PayTR.

## 4. PR-P1 implementation scope (implemented)

PR-P1 adds one authenticated HTTP endpoint:

```text
POST /payments/paytr/session
```

Required behavior:

1. Accept only a Firebase ID token through `Authorization: Bearer`.
2. Read the caller IP from trusted proxy metadata, not from the JSON body.
3. Parse `contractVersion`, `items`, and `customer`.
4. Ignore and reject any client attempt to set prices or order status.
5. Price every product from the server-owned catalog.
6. Create an order and a payment-attempt record transactionally.
7. Generate the PayTR token from Secret Manager values.
8. POST form-encoded fields to PayTR with a bounded timeout.
9. Persist the token-request outcome without storing the merchant key or salt.
10. Return an opaque payment-session response to the mobile app.

## 5. Initial statuses

```text
draft
awaiting_payment
payment_session_failed
payment_processing
paid
payment_failed
expired
```

Only the backend may change payment status. `paid` is reserved for a verified
PayTR callback.

## 6. Initial Firestore shape

```text
users/{userId}/orders/{orderId}
users/{userId}/orders/{orderId}/paymentAttempts/{attemptId}
```

The user will eventually read only their own orders. Creation and all payment
state transitions remain backend-owned.

The order snapshot must include:

- user ID,
- internal order ID,
- `merchant_oid`,
- status,
- currency,
- subtotal and total in minor units,
- immutable product name/price snapshots,
- customer delivery snapshot,
- created/updated server timestamps.

## 7. Secret and environment ownership

Non-secret parameter:

```text
PAYTR_MERCHANT_ID
```

Secret Manager values:

```text
PAYTR_MERCHANT_KEY
PAYTR_MERCHANT_SALT
```

Environment parameters:

```text
PEA_FUNCTIONS_REGION
PAYTR_TEST_MODE
PAYTR_MERCHANT_OK_URL
PAYTR_MERCHANT_FAIL_URL
```

No real value belongs in Git, Flutter assets, Dart defines, Android resources,
web JavaScript, logs, test fixtures, screenshots, or patch files.

## 8. Required information before PR-P1 can be deployed

- PayTR `merchant_id`
- PayTR `merchant_key`
- PayTR `merchant_salt`
- confirmation that iFrame API is enabled
- staging success URL
- staging failure URL
- public HTTPS callback URL plan
- current Firestore location
- chosen Functions region
- legal customer fields required by the organization
- installment policy for the first demo

The code can be developed with fake values, but no live token request should be
attempted until these items are confirmed.

## 9. Acceptance gate for this preparation patch

- Existing Flutter production code is unchanged.
- Checkout remains disabled.
- Camera, ML Kit, and workout-analysis files are untouched.
- Functions codebase is declared separately.
- Server catalog prices match the current mobile preview catalog.
- Client request contains no price field.
- Token primitives follow the documented PayTR concatenation order.
- Core Node tests pass.
- Full backend build passes after dependencies are installed.

## 10. Explicit non-goals

- PayTR callback endpoint
- mobile WebView
- enabled checkout
- persistent mobile cart
- dashboard
- remote product management
- refunds
- stock reservation
- production deployment
