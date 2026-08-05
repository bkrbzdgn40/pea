# PR-P1 Real PayTR Payment Session Endpoint

**Baseline:** tar274

## Scope

This PR implements the server-side iFrame token creation step. It does not add
the PayTR callback or enable the Flutter checkout screen.

## Request lifecycle

```text
Firebase bearer token
  -> request and idempotency validation
  -> server-owned catalog pricing
  -> atomic Firestore reservation
  -> PayTR server-side token request
  -> Firestore ready/failed transition
  -> opaque mobile response
```

## Authentication

The endpoint accepts only a Firebase ID token in the `Authorization: Bearer`
header. Anonymous Firebase users are valid callers because the current PEA app
uses anonymous authentication. A missing, expired, or invalid token receives
`401`.

## Idempotency

`Idempotency-Key` is required. The raw key is never stored. A SHA-256 digest
scoped to the Firebase user is used for the internal idempotency document.

- Same key and same request after success: replay existing session.
- Same key and different request: conflict.
- Same key while creation is running: in progress.
- Same key after provider failure: caller must generate a new key.

## Firestore transaction

The initial transaction creates:

- the user order snapshot,
- one payment attempt,
- an idempotency pointer,
- a `merchant_oid` lookup for the future callback.

The order stores immutable product-name and price snapshots. The mobile price is
never persisted as authority.

## PayTR request

The backend posts form-encoded fields to the PayTR token endpoint. The HMAC
includes the documented ordered values and the secret salt. Merchant key and
salt are never included as form fields.

The outbound request has a configurable timeout capped at 30 seconds. PayTR
rejection details may be stored in the backend attempt for operations, but the
mobile receives only a generic payment-session error.

## Configuration

Required non-secret values:

```text
PEA_FUNCTIONS_REGION
PAYTR_MERCHANT_ID
PAYTR_MERCHANT_OK_URL
PAYTR_MERCHANT_FAIL_URL
```

Defaults intended for the first test demo:

```text
PAYTR_LANGUAGE=tr
PAYTR_TEST_MODE=1
PAYTR_DEBUG_ON=1
PAYTR_NO_INSTALLMENT=1
PAYTR_MAX_INSTALLMENT=0
PAYTR_TIMEOUT_LIMIT_MINUTES=30
PAYTR_REQUEST_TIMEOUT_MS=15000
```

Secrets:

```text
PAYTR_MERCHANT_KEY
PAYTR_MERCHANT_SALT
```

## Deployment checklist

1. Confirm the Firebase project and Firestore location.
2. Choose the matching Functions region.
3. Confirm PayTR iFrame API is enabled.
4. Create HTTPS success and failure pages.
5. Set the two Firebase secrets.
6. Configure non-secret function parameters during deployment.
7. Deploy only the `payments` Functions codebase.
8. Call the health function.
9. Obtain a current Firebase ID token from the staging app.
10. Call the session endpoint with a fresh idempotency key.
11. Confirm the order and payment-attempt documents are created.
12. Confirm the returned iframe URL opens the PayTR test form.

## Acceptance gate

- Functions build and core tests pass.
- Firestore emulator transaction test passes.
- Invalid Firebase token returns `401`.
- Client price fields are rejected.
- PayTR secrets never appear in request bodies or logs.
- Same successful idempotency request does not call PayTR twice.
- PayTR failure marks the attempt and order as failed.
- No Flutter production file changes.
- Checkout remains disabled until PR-P3/P4.

## Deferred to PR-P2

- public PayTR notification callback,
- callback hash validation,
- callback idempotency,
- `paid` and `payment_failed` transitions,
- comparison of callback amount with the order,
- plain-text `OK` response.
