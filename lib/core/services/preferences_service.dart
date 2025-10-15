import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _rememberMeKey = 'remember_me';
  static const String _savedEmailKey = 'saved_email';
  static const String _savedPasswordKey = 'saved_password';

  static PreferencesService? _instance;
  static SharedPreferences? _prefs;

  PreferencesService._();

  static Future<PreferencesService> getInstance() async {
    _instance ??= PreferencesService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Remember Me functionality
  Future<void> setRememberMe(bool remember) async {
    await _prefs!.setBool(_rememberMeKey, remember);
  }

  bool getRememberMe() {
    return _prefs!.getBool(_rememberMeKey) ?? false;
  }

  // Save credentials (encrypted in production)
  Future<void> saveCredentials(String email, String password) async {
    await _prefs!.setString(_savedEmailKey, email);
    // In production, encrypt the password before storing
    await _prefs!.setString(_savedPasswordKey, password);
  }

  Future<Map<String, String?>> getSavedCredentials() async {
    final email = _prefs!.getString(_savedEmailKey);
    final password = _prefs!.getString(_savedPasswordKey);
    return {
      'email': email,
      'password': password,
    };
  }

  Future<void> clearSavedCredentials() async {
    await _prefs!.remove(_savedEmailKey);
    await _prefs!.remove(_savedPasswordKey);
    await _prefs!.remove(_rememberMeKey);
  }

  // Auto-login check
  Future<bool> shouldAutoLogin() async {
    final rememberMe = getRememberMe();
    if (!rememberMe) return false;

    final credentials = await getSavedCredentials();
    return credentials['email'] != null && credentials['password'] != null;
  }
}
