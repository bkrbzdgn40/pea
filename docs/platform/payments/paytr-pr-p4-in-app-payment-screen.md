# PayTR PR-P4: In-app payment screen

## Scope

PR-P4 connects the server-created PayTR iFrame session to a Flutter WebView and
adds an authenticated payment-status endpoint. The redirect page remains a UI
signal only. The mobile app displays `paid` or `failed` only after reading the
order state finalized by the PR-P2 callback.

## Mobile flow

```text
Checkout form
  -> POST /payments/paytr/session
  -> open validated PayTR iframe URL in WebView
  -> allow HTTPS PayTR / bank 3D Secure navigation
  -> intercept configured merchant success or failure return endpoint
  -> GET /payments/paytr/status?orderId=...
  -> poll boundedly until paid, failed, or unknown
```

## Security rules

- The initial iframe URL must be HTTPS `www.paytr.com/odeme/guvenli/...`.
- HTTP, file, data, javascript, intent, and other non-HTTPS navigation is blocked.
- HTTPS navigation is allowed because 3D Secure may use bank domains.
- Only the exact configured merchant return origin, port, and path is intercepted.
- A success return does not clear the cart.
- The cart is cleared only after the authenticated status endpoint returns
  `paymentStatus=paid` for the same order, merchant order ID, currency, and total.
- Failed, unknown, timeout, and closed-screen states preserve the cart.
- The status endpoint derives the user ID from the verified Firebase token and
  never accepts `userId` from query or body data.

## Dependency pin

The mobile app pins `webview_flutter` to `4.9.0`. This version supports the
existing Android API floor and provides `WebViewController`, `WebViewWidget`,
`NavigationDelegate`, main-frame error filtering, and HTTPS navigation control.
The dependency must not be upgraded casually because newer Android
implementations may raise the minimum supported Android SDK.

## Acceptance gates

- Flutter analyzer and market tests pass.
- Functions build and core tests pass.
- Firestore emulator status ownership test passes.
- A physical-device PayTR test-mode smoke completes the full token, WebView,
  callback, status verification, and cart-clearing path.
- Closing the payment screen before finalization preserves the cart.
- Market to Live Analysis transition remains responsive after closing WebView.
