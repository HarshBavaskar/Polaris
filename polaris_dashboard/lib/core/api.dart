class ApiConfig {
  // Override with:
  // --dart-define=POLARIS_API_BASE_URL=http://<YOUR_LAN_IP>:8000
  static const String baseUrl = String.fromEnvironment(
    'POLARIS_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
