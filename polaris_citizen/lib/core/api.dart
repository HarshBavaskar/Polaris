import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'POLARIS_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static String get baseUrl {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _configuredBaseUrl;
    }

    final Uri? parsed = Uri.tryParse(_configuredBaseUrl);
    if (parsed == null) return _configuredBaseUrl;

    final bool isLoopback =
        parsed.host == '127.0.0.1' || parsed.host == 'localhost';
    if (!isLoopback) return _configuredBaseUrl;

    // Android emulator maps host loopback to 10.0.2.2.
    return parsed.replace(host: '10.0.2.2').toString();
  }
}
