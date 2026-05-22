import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const String _wakeWordKey = 'wake_word';
  static const String _firstRunKey = 'first_run_complete';
  static const String _installDateKey = 'install_date';
  static const String _mappedAppsKey = 'mapped_apps';
  static const String _appOpenCountKey = 'app_open_count_';

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

  /// Retorna o dia da instalação (timestamp em ms).
  static Future<int> _getInstallDate() async {
    final prefs = await SharedPreferences.getInstance();
    var date = prefs.getInt(_installDateKey);
    if (date == null) {
      date = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_installDateKey, date);
    }
    return date;
  }

  /// Verifica se ainda está dentro dos primeiros 15 dias.
  static Future<bool> isWithinMappingPeriod() async {
    final installDate = await _getInstallDate();
    final daysSinceInstall =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(installDate)).inDays;
    return daysSinceInstall < 15;
  }

  /// Retorna lista de apps já mapeados (nome normalizado → package).
  static Future<Map<String, String>> getMappedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_mappedAppsKey);
    if (raw == null) return <String, String>{};
    return <String, String>{
      for (final entry in raw)
        if (entry.contains('|')) entry.split('|').first: entry.split('|').last,
    };
  }

  /// Registra que um app foi aberto (só salva se dentro dos 15 dias).
  static Future<void> registerAppOpen(String appName, String packageName) async {
    if (!await isWithinMappingPeriod()) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_mappedAppsKey) ?? <String>[];
    final key = '$appName|$packageName';
    if (!raw.contains(key)) {
      await prefs.setStringList(_mappedAppsKey, [...raw, key]);
    }
    // Contador de uso para ranking futuro
    final countKey = '$_appOpenCountKey$packageName';
    final count = prefs.getInt(countKey) ?? 0;
    await prefs.setInt(countKey, count + 1);
  }

  /// Limpa todos os dados.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wakeWordKey);
    await prefs.remove(_firstRunKey);
    await prefs.remove(_installDateKey);
    await prefs.remove(_mappedAppsKey);
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_appOpenCountKey)) await prefs.remove(key);
    }
  }
}
