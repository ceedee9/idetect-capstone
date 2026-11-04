// Phone-side copy of apps/api/src/utils/issuingLgu.js. Keep the two in sync:
// same header rule, keywords, misread tolerance, and Valenzuela guard.
import 'dart:math';

import 'ph_lgu_names.dart';

enum IssuingCity { valenzuela, other, unknown }

const int headerLineCount = 8;

final RegExp _valenzuelaPattern = RegExp(r'VALENZ|ALENZU');

final RegExp _keywordPattern = RegExp(
  r'\b(?:CITY|MUNICIPALITY|MUNICIPAL|LUNGSOD|BAYAN)\s+'
  r'(?:GOVERNMENT\s+|GOVT\.?\s+)?(?:OF|NG)\s+',
);

final RegExp _alnumPattern = RegExp(r'[A-Z0-9]');

// Names shorter than 6 letters must match exactly. Longer names tolerate
// 1 misread letter, and names of 12 letters or more tolerate 2.
int _maxEditsFor(String name) {
  if (name.length >= 12) return 2;
  if (name.length >= 6) return 1;
  return 0;
}

int _editDistance(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = min(min(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost);
    }
    prev = cur;
  }
  return prev[b.length];
}

// Names that the start of [tail] matches, allowing the name to end at a word boundary.
Iterable<String> _namesAtTail(String tail) sync* {
  for (final name in phLguNames) {
    final k = _maxEditsFor(name);
    final to = min(tail.length, name.length + k);
    for (var l = max(1, name.length - k); l <= to; l++) {
      if (l < tail.length && _alnumPattern.hasMatch(tail[l])) continue;
      if (_editDistance(tail.substring(0, l), name) <= k) {
        yield name;
        break;
      }
    }
  }
}

// Every city or municipality name that follows a government keyword in the header.
Set<String> _issuingCityNames(String upperHeader) {
  final text = upperHeader.replaceAll(RegExp(r'\s+'), ' ');
  final names = <String>{};
  for (final match in _keywordPattern.allMatches(text)) {
    names.addAll(_namesAtTail(text.substring(match.end)));
  }
  return names;
}

String headerLines(String? rawText) {
  if (rawText == null) return '';
  return rawText
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .take(headerLineCount)
      .join('\n');
}

IssuingCity classifyIssuingCity(String? rawText) {
  final upper = headerLines(rawText).toUpperCase();
  if (upper.isEmpty) return IssuingCity.unknown;
  if (_valenzuelaPattern.hasMatch(upper)) return IssuingCity.valenzuela;
  final names = _issuingCityNames(upper);
  if (names.contains('VALENZUELA')) return IssuingCity.valenzuela;
  return names.isNotEmpty ? IssuingCity.other : IssuingCity.unknown;
}

bool textNamesOtherCity(String? rawText) =>
    classifyIssuingCity(rawText) == IssuingCity.other;
