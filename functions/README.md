# PEA Platform Functions

This codebase is the server-owned boundary for PayTR and later dashboard
operations. Flutter code must never contain PayTR merchant secrets, calculate
the authoritative charge, or decide that an order is paid.

## Current scope

PR-P1 exposes an authenticated payment-session endpoint through the `paytrApi`
HTTP function:

```text
POST /payments/paytr/session
```

PR-P2 adds the public PayTR notification endpoint:

```text
POST /payments/paytr/callback
Content-Type: application/x-www-form-urlencoded
```

PR-P4 adds the authenticated order-status endpoint used by the in-app payment screen:

```text
GET /payments/paytr/status?orderId=<orderId>
```

The deployed URLs are:

```text
https://<region>-<project>.cloudfunctions.net/paytrApi/payments/paytr/session
https://<region>-<project>.cloudfunctions.net/paytrApi/payments/paytr/status?orderId=<orderId>
https://<region>-<project>.cloudfunctions.net/paytrApi/payments/paytr/callback
```

The session endpoint:

- verifies a Firebase ID token,
- requires an `Idempotency-Key`,
- reads the client IP from Cloud Functions proxy metadata,
- rejects client-controlled price and order fields,
- prices the cart from the server-owned seed,
- creates an order, payment attempt, idempotency record, and merchant lookup in
  one Firestore transaction,
- creates the PayTR iFrame token server-side,
- posts the documented form fields to PayTR with a bounded timeout,
- stores the opaque iframe token only in the backend-owned payment attempt,
- replays a completed session for the same idempotent request.

The status endpoint:

- verifies the Firebase ID token,
- reads only `users/{uid}/orders/{orderId}`,
- never accepts a user ID from the client,
- returns `not_started`, `paid`, or `failed`,
- prevents the WebView redirect page from becoming payment authority.

The callback endpoint:

- does not use Firebase user authentication or browser sessions,
- accepts the form fields posted by PayTR,
- verifies the documented callback HMAC before reading payment state,
- resolves the order through the backend-owned `merchant_oid` lookup,
- verifies the original successful `payment_amount` against the server order,
- records the possibly higher collected `total_amount` separately,
- atomically finalizes the order and payment attempt,
- creates one immutable payment event,
- treats later callbacks as duplicates and returns plain-text `OK`,
- never trusts success or failure redirect pages as payment authority.

## Local commands

```powershell
npm ci --prefix functions
npm run check --prefix functions
```

Run Firestore transaction integration tests while the emulator is active:

```powershell
npm run test:emulator --prefix functions
```

## Non-secret parameters

```text
PEA_FUNCTIONS_REGION
PAYTR_MERCHANT_ID
PAYTR_MERCHANT_OK_URL
PAYTR_MERCHANT_FAIL_URL
PAYTR_LANGUAGE
PAYTR_TEST_MODE
PAYTR_DEBUG_ON
PAYTR_NO_INSTALLMENT
PAYTR_MAX_INSTALLMENT
PAYTR_TIMEOUT_LIMIT_MINUTES
PAYTR_REQUEST_TIMEOUT_MS
```

The first four values have no code default. Confirm the Firestore location
before selecting the function region. Redirect URLs must use HTTPS.

## Secrets

Provision these through Firebase Secret Manager integration:

```powershell
firebase functions:secrets:set PAYTR_MERCHANT_KEY
firebase functions:secrets:set PAYTR_MERCHANT_SALT
```

Never place the values in Git, Flutter assets, Dart defines, Android resources,
logs, screenshots, test fixtures, or patch files.

For local Functions emulator work, keep any secret override in the ignored
`functions/.secret.local` file. Do not send that file with project archives.
