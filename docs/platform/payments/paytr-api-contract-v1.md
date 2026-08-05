# PayTR Payment Session API Contract v1

## Endpoint

```text
POST /payments/paytr/session
Authorization: Bearer <Firebase ID token>
Idempotency-Key: <16-80 URL-safe characters>
Content-Type: application/json
```

When deployed through the `paytrApi` Cloud Function, the full path is:

```text
https://<region>-<project>.cloudfunctions.net/paytrApi/payments/paytr/session
```

## Request

```json
{
  "contractVersion": 1,
  "items": [
    {
      "productId": "phone_tripod",
      "quantity": 1
    }
  ],
  "customer": {
    "email": "buyer@example.com",
    "fullName": "Example Buyer",
    "phone": "05551234567",
    "address": "Delivery address"
  }
}
```

The request intentionally has no price, currency, total, order status,
`merchant_oid`, PayTR token, merchant key, or merchant salt field.

## Created response

Status: `201 Created`

```json
{
  "contractVersion": 1,
  "orderId": "internal-order-id",
  "merchantOid": "PEA...",
  "paymentStatus": "awaiting_payment",
  "currencyCode": "TRY",
  "totalMinor": 79900,
  "iframeToken": "opaque-paytr-token",
  "iframeUrl": "https://www.paytr.com/odeme/guvenli/<token>",
  "merchantOkUrl": "https://merchant.example/payment/success",
  "merchantFailUrl": "https://merchant.example/payment/failure"
}
```

A repeated request with the same Firebase user, idempotency key, and request
payload returns the same response with `200 OK` without another PayTR call.

Reusing the same idempotency key with different data returns `409`.

`iframeToken` is not a merchant secret. It is still payment-session material and
must not be logged or exposed outside the authenticated mobile flow.

## Error envelope

```json
{
  "error": {
    "code": "product_unavailable",
    "message": "Product is unavailable: phone_tripod.",
    "requestId": "request-id"
  }
}
```

Initial error codes include:

```text
method_not_allowed
unsupported_media_type
unauthenticated
missing_idempotency_key
invalid_idempotency_key
idempotency_conflict
payment_session_in_progress
payment_session_previously_failed
unsupported_contract_version
invalid_object
invalid_string
invalid_string_length
invalid_email
invalid_items
too_many_items
invalid_quantity
duplicate_product
product_unavailable
mixed_currency
invalid_client_ip
payment_session_unavailable
internal_error
```

## Firestore ownership

Backend-created documents:

```text
users/{userId}/orders/{orderId}
users/{userId}/orders/{orderId}/paymentAttempts/{attemptId}
_paymentSessionIdempotency/{hash}
_paytrMerchantOrders/{merchantOid}
```

The two underscore-prefixed collections are internal lookup structures. Client
Firestore rules must not expose them.

## Trust boundary

The mobile app owns user intent. The backend owns identity verification,
product availability, prices, totals, order creation, PayTR token generation,
and payment status.

The `awaiting_payment` response means only that a PayTR form can be opened. It
does not mean the order was paid. Only the future verified PayTR callback may
set `paid`.

---

# PayTR Notification Callback

## Endpoint

```text
POST /payments/paytr/callback
Content-Type: application/x-www-form-urlencoded
```

The callback is called by PayTR, not by the signed-in mobile user. It therefore
uses no Firebase bearer token and no browser session.

## Required fields

Both outcomes:

```text
merchant_oid
status
                      success | failed
total_amount
hash
payment_type          card | eft
```

Successful result additionally requires:

```text
currency              TL | USD | EUR | GBP | RUB
payment_amount
```

Failed result additionally requires:

```text
failed_reason_code
failed_reason_msg
```

`test_mode` is accepted when PayTR sends it.

## Hash verification

The backend calculates:

```text
HMAC-SHA256(
  merchant_oid + merchant_salt + status + total_amount,
  merchant_key
)
```

and compares its Base64 output with the received `hash` using a constant-time
comparison. No Firestore payment state is read before this check passes.

## Amount validation

For successful callbacks:

- `payment_amount` must equal the authoritative order total sent in step 1.
- `total_amount` is the amount collected by PayTR and may be higher in cases
  such as installments.
- `total_amount` must not be lower than `payment_amount`.
- PayTR currency `TL` must match the internal order currency `TRY`.

Failed callbacks do not finalize an order as paid.

## Idempotency

`merchant_oid` resolves exactly one backend-created order and active payment
attempt. The first valid notification finalizes the payment transactionally.
Later notifications for the same order do not create another payment event or
change the result. They receive:

```text
HTTP 200
Content-Type: text/plain

OK
```

Unknown orders, invalid hashes, malformed payloads, and amount/currency
mismatches are not acknowledged with `OK`.

---

# Authenticated Payment Status

## Endpoint

```text
GET /payments/paytr/status?orderId=<orderId>
Authorization: Bearer <Firebase ID token>
```

## Response

```json
{
  "contractVersion": 1,
  "orderId": "internal-order-id",
  "merchantOid": "PEA...",
  "orderStatus": "paid",
  "paymentStatus": "paid",
  "currencyCode": "TRY",
  "totalMinor": 79900
}
```

`paymentStatus` is one of `not_started`, `paid`, or `failed`. The endpoint
derives the user ID from the verified Firebase token and reads only
`users/{uid}/orders/{orderId}`. A caller cannot supply another user ID.

The mobile WebView success or failure return is only a signal to query this
endpoint. It never becomes payment authority.
