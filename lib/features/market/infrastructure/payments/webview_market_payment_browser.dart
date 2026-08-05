import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../application/payments/market_payment_browser.dart';
import '../../application/payments/market_payment_navigation_policy.dart';

class WebViewMarketPaymentBrowserFactory
    implements MarketPaymentBrowserFactory {
  const WebViewMarketPaymentBrowserFactory();

  @override
  MarketPaymentBrowser create({
    required Uri initialUri,
    required MarketPaymentBrowserNavigationCallback onNavigation,
    required MarketPaymentBrowserUriCallback onPageStarted,
    required MarketPaymentBrowserUriCallback onPageFinished,
    required MarketPaymentBrowserErrorCallback onMainFrameError,
  }) {
    return _WebViewMarketPaymentBrowser(
      initialUri: initialUri,
      onNavigation: onNavigation,
      onPageStarted: onPageStarted,
      onPageFinished: onPageFinished,
      onMainFrameError: onMainFrameError,
    );
  }
}

class _WebViewMarketPaymentBrowser implements MarketPaymentBrowser {
  _WebViewMarketPaymentBrowser({
    required Uri initialUri,
    required MarketPaymentBrowserNavigationCallback onNavigation,
    required MarketPaymentBrowserUriCallback onPageStarted,
    required MarketPaymentBrowserUriCallback onPageFinished,
    required MarketPaymentBrowserErrorCallback onMainFrameError,
  }) : _controller = WebViewController() {
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) {
              return NavigationDecision.prevent;
            }
            return onNavigation(uri) == MarketPaymentNavigationDecision.allow
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            final uri = Uri.tryParse(url);
            if (uri != null) {
              onPageStarted(uri);
            }
          },
          onPageFinished: (url) {
            final uri = Uri.tryParse(url);
            if (uri != null) {
              onPageFinished(uri);
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              onMainFrameError(error.description);
            }
          },
        ),
      )
      ..loadRequest(initialUri);
  }

  final WebViewController _controller;

  @override
  Widget build({Key? key}) => WebViewWidget(key: key, controller: _controller);

  @override
  Future<void> reload() => _controller.reload();
}
