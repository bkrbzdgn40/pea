# PR-P3 — Mobile checkout form and payment-session client

## Scope

This PR turns the disabled local checkout template into a real customer and
payment-session preparation flow. It does not open the PayTR iframe yet.

The mobile application now:

1. Collects full name, email, phone, and delivery address.
2. Validates the fields before making a request.
3. Sends only product IDs, quantities, and customer data.
4. Authenticates with the current Firebase ID token.
5. Sends an `Idempotency-Key` header.
6. Accepts the server-calculated total and PayTR iframe session.
7. Keeps the cart intact after session creation.

The mobile client never sends an authoritative price, payment result, merchant
key, or merchant salt.

## Build configuration

The Cloud Function root URL must be supplied at compile time:

```text
--dart-define=PAYTR_API_BASE_URL=https://<region>-<project>.cloudfunctions.net/paytrApi/
```

For an Android emulator with the Functions emulator:

```text
--dart-define=PAYTR_API_BASE_URL=http://10.0.2.2:5001/<project>/<region>/paytrApi/
```

Remote plain HTTP URLs are rejected. HTTP is accepted only for localhost and
emulator loopback hosts. Android cleartext traffic is enabled only in the debug
manifest so release builds remain HTTPS-only.

## Request ownership

The request contract is:

```json
{
  "contractVersion": 1,
  "items": [
    {"productId": "phone_tripod", "quantity": 1}
  ],
  "customer": {
    "email": "user@example.com",
    "fullName": "Test User",
    "phone": "+90 555 000 00 00",
    "address": "Delivery address"
  }
}
```

The following values are intentionally absent:

- product price
- cart subtotal
- payment status
- PayTR merchant credentials

The backend remains the sole owner of pricing and payment state.

## Authentication

The client reads the current Firebase user's ID token and sends it as a bearer
token. A `401` response triggers exactly one forced token refresh and one retry
with the same idempotency key.

## Idempotency

A key is generated for a normalized cart and customer request. It is reused
when the outcome is uncertain, including network errors, timeouts, and server
errors. This prevents a retry from creating a second order or PayTR session.

A new key is generated only when:

- the cart or customer input changes, or
- the backend explicitly reports that the prior payment session failed and a
  new key is required.

## UI states

The checkout exposes four states:

```text
idle
submitting
ready
failed
```

A successful response displays the order reference and the backend-verified
total. It does not claim that payment succeeded. The iframe token and URL are
kept in the payment-session state for PR-P4.

## Explicit non-goals

This PR does not:

- open a WebView or PayTR iframe
- collect card information
- mark an order as paid
- clear the cart
- poll payment status
- change camera, ML Kit, or workout-analysis code

## PR-P4 handoff

PR-P4 will consume the validated `MarketPaymentSession.iframeUri`, open the
PayTR screen inside the application, and treat redirect URLs only as navigation
signals. The backend callback remains the sole source of truth for payment
completion.
