import 'package:flutter_contacts/flutter_contacts.dart';

class ContactMatch {
  const ContactMatch({required this.name, this.phone, required this.score});

  final String name;
  final String? phone;
  final double score;
}

class VoiceContactsService {
  static const double _threshold = 0.4;

  Future<List<ContactMatch>> searchByName(String query) async {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return const <ContactMatch>[];

    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
      return const <ContactMatch>[];
    }

    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    final matches = <ContactMatch>[];

    for (final contact in contacts) {
      final name = contact.displayName?.trim() ?? '';
      if (name.isEmpty || contact.phones.isEmpty) continue;

      final normalizedName = _normalize(name);
      final score = _score(normalizedQuery, normalizedName);
      if (score >= _threshold) {
        final phone = contact.phones.first.number.trim();
        if (phone.isEmpty) continue;
        matches.add(ContactMatch(name: name, phone: phone, score: score));
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }

  String _normalize(String text) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to   = 'aaaaaeeeeiiiiooooouuuuc';
    final buf = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      final idx = from.indexOf(ch);
      buf.write(idx >= 0 ? to[idx] : ch);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  double _score(String query, String candidate) {
    if (candidate == query) return 1.0;
    if (candidate.contains(query)) return 0.85;

    final qWords = query.split(' ');
    final cWords = candidate.split(' ');
    var matched = 0;
    for (final w in qWords) {
      if (cWords.any((cw) => cw.startsWith(w) || w.startsWith(cw))) {
        matched++;
      }
    }
    final wordScore = matched / qWords.length;

    final dist = _levenshtein(query, candidate).toDouble();
    final maxLen = query.length > candidate.length ? query.length : candidate.length;
    final distScore = maxLen == 0 ? 0.0 : 1.0 - (dist / maxLen);

    return ((wordScore * 0.55) + (distScore * 0.45)).clamp(0.0, 1.0);
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = <int>[
          curr[j - 1] + 1,
          prev[j] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }
}
