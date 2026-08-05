# PR-P2 PayTR Callback and Idempotent Payment Verification

**Baseline:** tar277

## Scope

This PR implements the PayTR iFrame API notification step. It does not enable
the Flutter checkout screen or add a payment WebView.

## Endpoint

```text
POST /payments/paytr/callback
Content-Type: application/x-www-form-urlencoded
```

The callback is public because PayTR calls it server-to-server. It does not use
Firebase Authentication. Authenticity is established with the callback HMAC.

## Processing order

```text
form contract validation
  -> callback HMAC verification
  -> merchant_oid lookup
  -> order and active attempt validation
  -> successful payment amount/currency comparison
  -> atomic final state transition
  -> immutable payment event
  -> plain-text OK
```

The database is not consulted before the HMAC is verified.

## Successful callback rules

- `payment_amount` must equal the backend-owned order total from step 1.
- `total_amount` is stored as the provider-collected amount.
- `total_amount` may exceed `payment_amount`, for example because of
  installment-related collection differences.
- `total_amount` may not be lower than `payment_amount`.
- PayTR `TL` maps to internal `TRY`.
- The order becomes `status=paid` and `paymentStatus=paid`.

## Failed callback rules

- Failure code and message are stored for operations.
- The order becomes `status=payment_failed` and `paymentStatus=failed`.
- A later contradictory success callback cannot overwrite the first final
  result.

## Idempotency

The first accepted callback:

- updates the order,
- updates the active payment attempt,
- updates the merchant lookup,
- finalizes the payment-session idempotency record,
- creates one immutable payment event.

Repeated callbacks find an already-finalized order, perform no write, and
return only `OK`.

## Firestore additions

```text
users/{userId}/orders/{orderId}/paymentEvents/{eventId}
```

The event ID is a deterministic SHA-256 digest of the normalized callback. The
existing backend-only lookup collections remain:

```text
_paymentSessionIdempotency/{hash}
_paytrMerchantOrders/{merchantOid}
```

## Security behavior

- Invalid callback hash: no payment lookup, no state change, no `OK`.
- Unknown `merchant_oid`: no state change, no `OK`.
- Successful callback amount mismatch: no state change, no `OK`.
- Successful callback currency mismatch: no state change, no `OK`.
- Internal transaction failure: no partial state, no `OK`.
- Accepted or duplicate callback: plain-text `OK` only.

## Acceptance gate

- TypeScript build passes.
- Core callback contract and handler tests pass.
- Firestore emulator success, failure, duplicate, and amount-mismatch tests
  pass.
- Invalid hash is rejected before repository access.
- Successful callback uses `payment_amount` for order comparison.
- Duplicate callback creates no second event.
- Contradictory later callback cannot overwrite the first final result.
- Existing session endpoint returns `payment_already_finalized` for the same
  finalized idempotency record.
- No Flutter production file changes.
- Camera, ML Kit, and workout-analysis code remain untouched.
