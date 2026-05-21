import 'package:flutter_contacts/flutter_contacts.dart';

class ContactMatch {
  const ContactMatch({required this.name, this.phone, required this.score});

  final String name;
  final String? phone;
  final double score;
}

class VoiceContactsService {
  static const double _threshold = 0.6;

  Future<List<ContactMatch>> searchByName(String query) async {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return const <ContactMatch>[];
    }

    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.limited) {
      return const <ContactMatch>[];
    }

    final contacts = await FlutterContacts.getAll(
      properties: const <ContactProperty>{ContactProperty.phone},
    );
    final matches = <ContactMatch>[];
    for (final contact in contacts) {
      final displayName = contact.displayName?.trim();
      if (displayName == null ||
          displayName.isEmpty ||
          contact.phones.isEmpty) {
        continue;
      }

      final name = _normalize(displayName);
      final score = _score(normalizedQuery, name);
      if (score >= _threshold) {
        matches.add(
          ContactMatch(
            name: displayName,
            phone: contact.phones.first.number,
            score: score,
          ),
        );
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }

  String _normalize(String text) {
    const accentsFrom = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const accentsTo = 'aaaaaeeeeiiiiooooouuuuc';
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final index = accentsFrom.indexOf(char);
      buffer.write(index >= 0 ? accentsTo[index] : char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  double _score(String query, String candidate) {
    final normalizedQuery = _normalize(query);
    final normalizedCandidate = _normalize(candidate);
    if (normalizedCandidate == normalizedQuery) {
      return 1.0;
    }

    final queryWords = normalizedQuery.split(' ');
    final candidateWords = normalizedCandidate.split(' ');

    var matchedWords = 0;
    for (final word in queryWords) {
      if (candidateWords.any(
        (candidateWord) => candidateWord.startsWith(word),
      )) {
        matchedWords++;
      }
    }
    final wordScore = matchedWords / queryWords.length;

    final editDistance = _levenshtein(
      normalizedQuery,
      normalizedCandidate,
    ).toDouble();
    final maxLen = normalizedQuery.length > normalizedCandidate.length
        ? normalizedQuery.length
        : normalizedCandidate.length;
    final distanceScore = maxLen == 0 ? 0.0 : (1 - (editDistance / maxLen));

    final orderBonus = normalizedCandidate.contains(normalizedQuery)
        ? 0.15
        : 0.0;
    final score = (wordScore * 0.55) + (distanceScore * 0.45) + orderBonus;
    return score.clamp(0.0, 1.0);
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final previous = List<int>.generate(b.length + 1, (i) => i);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = [
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      for (var j = 0; j <= b.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous[b.length];
  }
}
