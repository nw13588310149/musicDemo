import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  AppStorage(this._prefs);

  static const _tokenKey = 'token';
  static const _pushIdKey = 'pushId';
  static const _checkStatusKey = 'checkStatus';

  final SharedPreferences _prefs;

  static Future<AppStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStorage(prefs);
  }

  String get token => _prefs.getString(_tokenKey) ?? '';

  String get pushId => _prefs.getString(_pushIdKey) ?? '';

  bool get hasCheckStatus {
    if (_prefs.containsKey(_checkStatusKey)) {
      final value = _prefs.get(_checkStatusKey);
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        return value.isNotEmpty && value != 'false' && value != '0';
      }
    }
    return false;
  }

  Future<void> saveToken(String token) async {
    await _prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    await _prefs.remove(_tokenKey);
  }

  Future<void> savePushId(String pushId) async {
    await _prefs.setString(_pushIdKey, pushId);
  }

  Future<void> saveCheckStatus(dynamic value) async {
    if (value == null) {
      await _prefs.remove(_checkStatusKey);
      return;
    }
    if (value is bool) {
      await _prefs.setBool(_checkStatusKey, value);
      return;
    }
    if (value is int) {
      await _prefs.setInt(_checkStatusKey, value);
      return;
    }
    if (value is double) {
      await _prefs.setDouble(_checkStatusKey, value);
      return;
    }
    await _prefs.setString(_checkStatusKey, value.toString());
  }
}
