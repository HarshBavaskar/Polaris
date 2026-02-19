class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'POLARIS_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
