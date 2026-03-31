import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api.dart';

class AuthHttp {
  static final http.Client _client = http.Client();
  static String? _bearerToken;
  static String? _username;
  static String? _password;

  static bool get isAuthenticated =>
      _bearerToken != null && _bearerToken!.trim().isNotEmpty;

  static void configureCredentials({
    required String username,
    required String password,
  }) {
    _username = username.trim();
    _password = password.trim();
  }

  static Future<void> login({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedPassword = password.trim();
    if (normalizedUsername.isEmpty || normalizedPassword.isEmpty) {
      throw StateError('Username and password are required.');
    }

    configureCredentials(
      username: normalizedUsername,
      password: normalizedPassword,
    );

    final http.Response response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/token'),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, String>{
        'username': normalizedUsername,
        'password': normalizedPassword,
      }),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Authority authentication failed: HTTP ${response.statusCode}',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Authority authentication returned an invalid payload.');
    }

    final String token = decoded['access_token']?.toString() ?? '';
    if (token.isEmpty) {
      throw StateError('Authority authentication returned no access token.');
    }

    _bearerToken = token;
  }

  static void logout() {
    _bearerToken = null;
    _username = null;
    _password = null;
  }

  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    bool authenticated = false,
  }) async {
    return _send(
      () => _client.get(uri, headers: headers),
      uri,
      headers: headers,
      authenticated: authenticated,
    );
  }

  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    bool authenticated = false,
  }) async {
    return _send(
      () => _client.post(uri, headers: headers, body: body),
      uri,
      headers: headers,
      body: body,
      authenticated: authenticated,
    );
  }

  static Future<http.Response> _send(
    Future<http.Response> Function() fallbackRequest,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    required bool authenticated,
  }) async {
    if (!authenticated) {
      return fallbackRequest();
    }

    Future<http.Response> runRequest() async {
      final Map<String, String> mergedHeaders = <String, String>{
        if (headers != null) ...headers,
        'Authorization': 'Bearer ${await _ensureToken()}',
      };
      if (body == null) {
        return _client.get(uri, headers: mergedHeaders);
      }
      return _client.post(uri, headers: mergedHeaders, body: body);
    }

    http.Response response = await runRequest();
    if (response.statusCode != 401) {
      return response;
    }

    _bearerToken = null;
    response = await runRequest();
    return response;
  }

  static Future<String> _ensureToken() async {
    if (_bearerToken != null && _bearerToken!.isNotEmpty) {
      return _bearerToken!;
    }

    final fallbackUsername = _username ?? ApiConfig.authUsername;
    final fallbackPassword = _password ?? ApiConfig.authPassword;
    if (fallbackUsername.trim().isEmpty || fallbackPassword.trim().isEmpty) {
      throw StateError(ApiConfig.authorityCredentialHint);
    }

    await login(
      username: fallbackUsername,
      password: fallbackPassword,
    );
    return _bearerToken!;
  }
}
