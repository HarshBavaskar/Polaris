import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'POLARIS_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const Duration requestTimeout = Duration(seconds: 8);

  static String get baseUrl {
    return candidateBaseUrls.first;
  }

  static List<String> get candidateBaseUrls {
    final Uri? parsed = Uri.tryParse(_configuredBaseUrl);
    if (parsed == null || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return <String>[_configuredBaseUrl];
    }

    final bool isLoopback =
        parsed.host == '127.0.0.1' || parsed.host == 'localhost';
    if (!isLoopback) {
      return <String>[_configuredBaseUrl];
    }

    final List<String> candidates = <String>[
      parsed.replace(host: '10.0.2.2').toString(),
      parsed.replace(host: '10.0.3.2').toString(),
      _configuredBaseUrl,
    ];
    return candidates.toSet().toList(growable: false);
  }

  static String get connectionHint {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final Uri? parsed = Uri.tryParse(_configuredBaseUrl);
      final bool isLoopback =
          parsed != null &&
          (parsed.host == '127.0.0.1' || parsed.host == 'localhost');
      if (isLoopback) {
        return 'Android emulator uses 10.0.2.2/10.0.3.2 automatically. '
            'For a physical device, run with '
            '--dart-define=POLARIS_API_BASE_URL=http://<YOUR_LAN_IP>:8000 '
            'or use adb reverse tcp:8000 tcp:8000.';
      }
    }
    return 'Verify the backend is running and reachable at $_configuredBaseUrl.';
  }
}
