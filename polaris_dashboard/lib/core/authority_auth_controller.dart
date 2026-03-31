import 'package:flutter/foundation.dart';

import 'api.dart';
import 'auth_http.dart';

class AuthorityAuthController extends ChangeNotifier {
  AuthorityAuthController() {
    _username = ApiConfig.authUsername;
    _password = ApiConfig.authPassword;
    if (_username.trim().isNotEmpty && _password.trim().isNotEmpty) {
      AuthHttp.configureCredentials(
        username: _username,
        password: _password,
      );
    }
  }

  String _username = '';
  String _password = '';
  bool _isSubmitting = false;
  String? _errorMessage;

  String get username => _username;
  String get password => _password;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => AuthHttp.isAuthenticated;

  void updateUsername(String value) {
    _username = value;
    notifyListeners();
  }

  void updatePassword(String value) {
    _password = value;
    notifyListeners();
  }

  Future<bool> signIn({
    String? username,
    String? password,
  }) async {
    final nextUsername = (username ?? _username).trim();
    final nextPassword = (password ?? _password).trim();
    if (nextUsername.isEmpty || nextPassword.isEmpty) {
      _errorMessage = 'Enter your authority username and password.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _username = nextUsername;
    _password = nextPassword;
    notifyListeners();

    try {
      await AuthHttp.login(username: nextUsername, password: nextPassword);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void signOut() {
    AuthHttp.logout();
    _errorMessage = null;
    notifyListeners();
  }
}
