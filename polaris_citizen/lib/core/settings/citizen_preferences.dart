import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CitizenPreferencesController extends ChangeNotifier {
  static const String _languageKey = 'citizen.pref.language.v1';

  SharedPreferences? _prefs;
  bool _loaded = false;
  String _languageCode = 'en';

  bool get loaded => _loaded;
  String get languageCode => _languageCode;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> load() async {
    final SharedPreferences prefs = await _instance();
    _languageCode = prefs.getString(_languageKey) ?? 'en';
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    _languageCode = code;
    final SharedPreferences prefs = await _instance();
    await prefs.setString(_languageKey, code);
    notifyListeners();
  }
}
