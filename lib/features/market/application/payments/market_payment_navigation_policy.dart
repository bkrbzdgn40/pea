import 'market_payment_session.dart';

enum MarketPaymentNavigationDecision {
  allow,
  block,
  successReturn,
  failureReturn,
}

class MarketPaymentNavigationPolicy {
  const MarketPaymentNavigationPolicy(this.session);

  final MarketPaymentSession session;

  MarketPaymentNavigationDecision decide(Uri uri) {
    if (_matchesReturnUri(uri, session.merchantOkUri)) {
      return MarketPaymentNavigationDecision.successReturn;
    }
    if (_matchesReturnUri(uri, session.merchantFailUri)) {
      return MarketPaymentNavigationDecision.failureReturn;
    }
    if (uri.scheme.toLowerCase() == 'https' && uri.host.isNotEmpty) {
      return MarketPaymentNavigationDecision.allow;
    }
    return MarketPaymentNavigationDecision.block;
  }

  bool _matchesReturnUri(Uri actual, Uri expected) {
    return actual.scheme.toLowerCase() == expected.scheme.toLowerCase() &&
        actual.host.toLowerCase() == expected.host.toLowerCase() &&
        _effectivePort(actual) == _effectivePort(expected) &&
        _normalizedPath(actual.path) == _normalizedPath(expected.path);
  }

  int _effectivePort(Uri uri) {
    if (uri.hasPort) {
      return uri.port;
    }
    return uri.scheme.toLowerCase() == 'https' ? 443 : 80;
  }

  String _normalizedPath(String path) {
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path.isEmpty ? '/' : path;
  }
}
