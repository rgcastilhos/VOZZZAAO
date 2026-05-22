import 'phone_control_service.dart';
import 'user_preferences.dart';

class AppResolver {
  AppResolver([PhoneControlService? phoneControlService])
    : _phoneControlService = phoneControlService ?? PhoneControlService();

  final PhoneControlService _phoneControlService;
  final Map<String, String> _installedApps = <String, String>{};

  static const Map<String, String> _knownApps = <String, String>{
    'whatsapp': 'com.whatsapp',
    'instagram': 'com.instagram.android',
    'facebook': 'com.facebook.katana',
    'spotify': 'com.spotify.music',
    'youtube': 'com.google.android.youtube',
    'youtube music': 'com.google.android.apps.youtube.music',
    'maps': 'com.google.android.apps.maps',
    'mapas': 'com.google.android.apps.maps',
    'google maps': 'com.google.android.apps.maps',
    'configuracoes': 'com.android.settings',
    'configuracao': 'com.android.settings',
    'settings': 'com.android.settings',
  };

  Future<int> mapInstalledApps() async {
    final installedApps = await _phoneControlService.getInstalledApps();
    _installedApps
      ..clear()
      ..addAll(_knownApps);

    for (final app in installedApps) {
      final normalizedName = _normalize(app.name);
      _installedApps[normalizedName] = app.packageName;

      final compactName = normalizedName.replaceAll(' ', '');
      if (compactName != normalizedName) {
        _installedApps[compactName] = app.packageName;
      }
    }

    return installedApps.length;
  }

  Future<String?> resolvePackage(String appName) async {
    final normalized = _normalize(appName);
    if (normalized.isEmpty) return null;

    // 1. Verifica apps mapeados automaticamente (primeiros 15 dias)
    final mappedApps = await UserPreferences.getMappedApps();
    if (mappedApps.containsKey(normalized)) {
      return mappedApps[normalized];
    }

    // 2. Cache local de apps instalados
    if (_installedApps.isEmpty) {
      await mapInstalledApps();
    }

    return _installedApps[normalized] ??
        _installedApps[normalized.replaceAll(' ', '')] ??
        _knownApps[normalized] ??
        _findBestPackage(normalized);
  }

  String? _findBestPackage(String normalizedName) {
    for (final entry in _installedApps.entries) {
      if (entry.key.contains(normalizedName) ||
          normalizedName.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  String _normalize(String value) {
    const accentsFrom = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const accentsTo = 'aaaaaeeeeiiiiooooouuuuc';
    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().trim().runes) {
      final char = String.fromCharCode(rune);
      final index = accentsFrom.indexOf(char);
      buffer.write(index >= 0 ? accentsTo[index] : char);
    }

    return buffer
        .toString()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
