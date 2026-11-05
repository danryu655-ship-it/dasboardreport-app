import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan ringan — cerminan key localStorage web:
/// `dasboard_active_account`, `dasboard_lang`, `app_pin_<profil>`.
/// v1: 100% lokal. TIDAK ADA key untuk API_URL/API_KEY/GSHEET (scope v1).
class PrefsHelper {
  static const _kActiveProfile = 'active_profile';
  static const _kLang = 'lang';

  static String _pinKey(String profile) => 'pin_$profile';

  static Future<SharedPreferences> get _prefs async =>
      SharedPreferences.getInstance();

  static Future<String?> getActiveProfile() async =>
      (await _prefs).getString(_kActiveProfile);

  static Future<void> setActiveProfile(String name) async =>
      (await _prefs).setString(_kActiveProfile, name);

  static Future<String> getLang() async =>
      (await _prefs).getString(_kLang) ?? 'id';

  static Future<void> setLang(String lang) async =>
      (await _prefs).setString(_kLang, lang);

  static Future<String?> getPin(String profile) async =>
      (await _prefs).getString(_pinKey(profile));

  static Future<void> setPin(String profile, String pin) async =>
      (await _prefs).setString(_pinKey(profile), pin);

  static Future<void> removePin(String profile) async =>
      (await _prefs).remove(_pinKey(profile));

  /// Pindahkan PIN saat profil diganti nama (cerminan web).
  static Future<void> movePin(String oldName, String newName) async {
    final prefs = await _prefs;
    final pin = prefs.getString(_pinKey(oldName));
    if (pin != null) {
      await prefs.setString(_pinKey(newName), pin);
      await prefs.remove(_pinKey(oldName));
    }
  }
}
