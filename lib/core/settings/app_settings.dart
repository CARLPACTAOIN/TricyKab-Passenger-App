import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors the driver app AppSettings: persists API base, tokens, and last phone.
class AppSettings {
  AppSettings._(this._prefs);

  static const String _kApiBase = 'tricykab_api_base';
  static const String _kAccessToken = 'tricykab_access_token';
  static const String _kRefreshToken = 'tricykab_refresh_token';
  static const String _kPhone = 'tricykab_last_phone';
  static const String _kEmail = 'tricykab_last_email';

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(prefs);
  }

  String get apiBase => _prefs.getString(_kApiBase)?.trim() ?? '';

  Future<void> setApiBase(String value) async {
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      await _prefs.remove(_kApiBase);
    } else {
      await _prefs.setString(_kApiBase, cleaned);
    }
  }

  String? get accessToken => _prefs.getString(_kAccessToken);

  Future<void> setAccessToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _prefs.remove(_kAccessToken);
    } else {
      await _prefs.setString(_kAccessToken, token);
    }
  }

  String? get refreshToken => _prefs.getString(_kRefreshToken);

  Future<void> setRefreshToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _prefs.remove(_kRefreshToken);
    } else {
      await _prefs.setString(_kRefreshToken, token);
    }
  }

  String? get lastPhone => _prefs.getString(_kPhone);

  Future<void> setLastPhone(String? phone) async {
    if (phone == null || phone.isEmpty) {
      await _prefs.remove(_kPhone);
    } else {
      await _prefs.setString(_kPhone, phone);
    }
  }

  String? get lastEmail => _prefs.getString(_kEmail);

  Future<void> setLastEmail(String? email) async {
    final cleaned = email?.trim() ?? '';
    if (cleaned.isEmpty) {
      await _prefs.remove(_kEmail);
    } else {
      await _prefs.setString(_kEmail, cleaned);
    }
  }

  Future<void> clearTokens() async {
    await _prefs.remove(_kAccessToken);
    await _prefs.remove(_kRefreshToken);
  }
}
