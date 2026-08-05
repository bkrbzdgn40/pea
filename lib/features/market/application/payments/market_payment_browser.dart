import 'package:flutter/widgets.dart';

import 'market_payment_navigation_policy.dart';

typedef MarketPaymentBrowserNavigationCallback =
    MarketPaymentNavigationDecision Function(Uri uri);

typedef MarketPaymentBrowserUriCallback = void Function(Uri uri);
typedef MarketPaymentBrowserErrorCallback = void Function(String message);

abstract interface class MarketPaymentBrowser {
  Widget build({Key? key});
  Future<void> reload();
}

abstract interface class MarketPaymentBrowserFactory {
  MarketPaymentBrowser create({
    required Uri initialUri,
    required MarketPaymentBrowserNavigationCallback onNavigation,
    required MarketPaymentBrowserUriCallback onPageStarted,
    required MarketPaymentBrowserUriCallback onPageFinished,
    required MarketPaymentBrowserErrorCallback onMainFrameError,
  });
}
