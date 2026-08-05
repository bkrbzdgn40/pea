class MarketPaymentApiConfig {
  const MarketPaymentApiConfig({
    required this.sessionEndpoint,
    required this.statusEndpoint,
  });

  static const String _rawBaseUrl = String.fromEnvironment(
    'PAYTR_API_BASE_URL',
  );

  final Uri sessionEndpoint;
  final Uri statusEndpoint;

  static MarketPaymentApiConfig? fromEnvironment() {
    return tryParse(_rawBaseUrl);
  }

  static MarketPaymentApiConfig? tryParse(String rawBaseUrl) {
    final value = rawBaseUrl.trim();
    if (value.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(value);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return null;
    }
    if (parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment ||
        !_isAllowedScheme(parsed)) {
      return null;
    }

    final normalizedPath = parsed.path.endsWith('/')
        ? parsed.path
        : '${parsed.path}/';
    final normalizedBase = parsed.replace(path: normalizedPath);
    return MarketPaymentApiConfig(
      sessionEndpoint: normalizedBase.resolve('payments/paytr/session'),
      statusEndpoint: normalizedBase.resolve('payments/paytr/status'),
    );
  }

  static bool _isAllowedScheme(Uri uri) {
    if (uri.scheme == 'https') {
      return true;
    }
    if (uri.scheme != 'http') {
      return false;
    }

    return switch (uri.host.toLowerCase()) {
      'localhost' || '127.0.0.1' || '::1' || '10.0.2.2' => true,
      _ => false,
    };
  }
}
