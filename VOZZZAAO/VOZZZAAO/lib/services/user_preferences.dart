import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const String _wakeWordKey = 'wake_word';
  static const String _firstRunKey = 'first_run_complete';

  static Future<String?> getWakeWord() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_wakeWordKey);
  }

  static Future<void> setWakeWord(String word) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wakeWordKey, word.toLowerCase().trim());
  }

  static Future<bool> isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_firstRunKey) ?? false);
  }

  static Future<void> markFirstRunComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstRunKey, true);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wakeWordKey);
    await prefs.remove(_firstRunKey);
  }
}
