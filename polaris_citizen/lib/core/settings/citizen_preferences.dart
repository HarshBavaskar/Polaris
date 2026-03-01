import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CitizenPreferencesController extends ChangeNotifier {
  static const String _languageKey = 'citizen.pref.language.v1';
  static const String _dataSaverKey = 'citizen.pref.data_saver.v1';
  static const String _defaultCityKey = 'citizen.pref.default_city.v1';
  static const String _defaultLocalityKey = 'citizen.pref.default_locality.v1';
  static const String _defaultPincodeKey = 'citizen.pref.default_pincode.v1';

  SharedPreferences? _prefs;
  bool _loaded = false;
  String _languageCode = 'en';
  bool _dataSaverEnabled = false;
  String _defaultCity = 'Mumbai';
  String _defaultLocality = '';
  String _defaultPincode = '';

  bool get loaded => _loaded;
  String get languageCode => _languageCode;
  bool get dataSaverEnabled => _dataSaverEnabled;
  String get defaultCity => _defaultCity;
  String get defaultLocality => _defaultLocality;
  String get defaultPincode => _defaultPincode;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> load() async {
    final SharedPreferences prefs = await _instance();
    _languageCode = prefs.getString(_languageKey) ?? 'en';
    _dataSaverEnabled = prefs.getBool(_dataSaverKey) ?? false;
    _defaultCity = prefs.getString(_defaultCityKey) ?? 'Mumbai';
    _defaultLocality = prefs.getString(_defaultLocalityKey) ?? '';
    _defaultPincode = prefs.getString(_defaultPincodeKey) ?? '';
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    _languageCode = code;
    final SharedPreferences prefs = await _instance();
    await prefs.setString(_languageKey, code);
    notifyListeners();
  }

  Future<void> setDataSaverEnabled(bool enabled) async {
    _dataSaverEnabled = enabled;
    final SharedPreferences prefs = await _instance();
    await prefs.setBool(_dataSaverKey, enabled);
    notifyListeners();
  }

  Future<void> setDefaultArea({
    required String city,
    required String locality,
    required String pincode,
  }) async {
    _defaultCity = city.trim().isEmpty ? 'Mumbai' : city.trim();
    _defaultLocality = locality.trim();
    _defaultPincode = pincode.trim();
    final SharedPreferences prefs = await _instance();
    await prefs.setString(_defaultCityKey, _defaultCity);
    await prefs.setString(_defaultLocalityKey, _defaultLocality);
    await prefs.setString(_defaultPincodeKey, _defaultPincode);
    notifyListeners();
  }

  Future<void> clearDefaultArea() async {
    _defaultCity = 'Mumbai';
    _defaultLocality = '';
    _defaultPincode = '';
    final SharedPreferences prefs = await _instance();
    await prefs.remove(_defaultCityKey);
    await prefs.remove(_defaultLocalityKey);
    await prefs.remove(_defaultPincodeKey);
    notifyListeners();
  }
}
