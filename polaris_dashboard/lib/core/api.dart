class ApiConfig {
  // Override with:
  // --dart-define=POLARIS_API_BASE_URL=http://<YOUR_LAN_IP>:8000
  static const String baseUrl = String.fromEnvironment(
    'POLARIS_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const String authUsername = String.fromEnvironment(
    'POLARIS_AUTH_USERNAME',
    defaultValue: '',
  );

  static const String authPassword = String.fromEnvironment(
    'POLARIS_AUTH_PASSWORD',
    defaultValue: '',
  );

  static bool get hasAuthorityCredentials =>
      authUsername.trim().isNotEmpty && authPassword.trim().isNotEmpty;

  static String get authorityCredentialHint =>
      'Add --dart-define=POLARIS_AUTH_USERNAME=... and '
      '--dart-define=POLARIS_AUTH_PASSWORD=... to use protected authority APIs.';
}
