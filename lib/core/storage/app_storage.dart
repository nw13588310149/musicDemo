import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  AppStorage(this._prefs);

  static const _tokenKey = 'token';
  static const _pushIdKey = 'pushId';
  static const _checkStatusKey = 'checkStatus';
  static const _schoolIdKey = 'schoolId';

  /// 通过 `/app/common/v2/configList` 拉取的「文件服务器域名」。所有
  /// 后端返回的相对路径（如 `app/upload/.../foo.png`）需要拼接到这个域名
  /// 上才能加载到。为空时回退到 `AppConstants.apiBaseUrl`。
  static const _fileBaseUrlKey = 'fileBaseUrl';

  final SharedPreferences _prefs;

  static Future<AppStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStorage(prefs);
  }

  String get token => _prefs.getString(_tokenKey) ?? '';

  String get pushId => _prefs.getString(_pushIdKey) ?? '';

  String get schoolId => _prefs.getString(_schoolIdKey) ?? '0';

  String get fileBaseUrl => _prefs.getString(_fileBaseUrlKey) ?? '';

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

  Future<void> saveSchoolId(dynamic schoolId) async {
    final value = int.tryParse(schoolId?.toString() ?? '') ?? 0;
    await _prefs.setString(_schoolIdKey, value.toString());
  }

  Future<void> clearSchoolId() async {
    await _prefs.remove(_schoolIdKey);
  }

  Future<void> savePushId(String pushId) async {
    await _prefs.setString(_pushIdKey, pushId);
  }

  Future<void> saveFileBaseUrl(String url) async {
    final value = url.trim();
    if (value.isEmpty) {
      await _prefs.remove(_fileBaseUrlKey);
      return;
    }
    await _prefs.setString(_fileBaseUrlKey, value);
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
