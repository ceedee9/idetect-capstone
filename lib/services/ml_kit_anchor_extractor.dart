// =============================================================================
// FILE: lib/services/ml_kit_anchor_extractor.dart
// PURPOSE: Locate Senior ID fields from ML Kit text lines using their printed
//          labels / unmistakable shape instead of fixed zone percentages.
// WHY:     Fast (reuses the single ML Kit pass), and keeps working when the
//          photo is slightly off-angle or the card is a little mis-framed,
//          where a fixed crop would cut the value in half.
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// A single ML Kit text line with its geometry.
class _Line {
  final String text;
  final Rect box;
  final List<TextElement> elements;

  _Line(this.text, this.box, this.elements);

  double get cy => box.center.dy;
}

/// Reads Senior ID fields straight from ML Kit's positioned text lines.
class MlKitAnchorExtractor {
  static const _months = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];

  // ===========================================================================
  // OLD FORMAT — "Control No." (large red number, lower right)
  // ===========================================================================

  /// Returns the control number as digits only, or '' when none is found.
  ///
  /// Works from shape rather than position: among the lines in the lower-right
  /// of the card, the control number is the tall run of 4-8 digits.
  static String controlNumberOldFormat(
    RecognizedText text,
    int width,
    int height,
  ) {
    String best = '';
    double bestScore = 0;

    for (final line in _lines(text)) {
      if (line.box.center.dx < width * 0.45) continue;
      if (line.cy < height * 0.68 || line.cy > height * 0.95) continue;

      // Concatenate digit-like elements, so "137 005" or "137005" both work
      // and the neighbouring "Control No." label is left out.
      final digits = StringBuffer();
      double tallest = 0;
      for (final e in line.elements) {
        // Dates such as 12-04-24 are digit-like too; they are not the number
        if (RegExp(r'\d{1,2}[-/]\d{1,2}[-/]\d{2,4}').hasMatch(e.text)) continue;
        final fixed = _digitsFromDigitLike(e.text);
        if (fixed.isEmpty) continue;
        digits.write(fixed);
        tallest = math.max(tallest, e.boundingBox.height);
      }
      final value = digits.toString();
      if (value.length < 4 || value.length > 8) continue;

      // Taller text wins: the control number is printed larger than the
      // surrounding labels. Length is a tiebreaker (6 digits is typical).
      final score = tallest * (value.length == 6 ? 1.15 : 1.0);
      if (score > bestScore) {
        bestScore = score;
        best = value;
      }
    }
    debugPrint('🔎 ML Kit control number: "${best.isEmpty ? '-' : best}"');
    return best;
  }

  // ===========================================================================
  // NEW FORMAT — labelled fields
  // ===========================================================================

  /// Reads the redesigned ID's fields. Keys: name, sex, dob, dateIssued, idNo.
  /// Dates come back as "July 15, 1965" (month corrected), ready for
  /// numeric normalisation by the caller. Missing fields are ''.
  static Map<String, String> newFormatFields(
    RecognizedText text,
    int width,
    int height,
  ) {
    final lines = _lines(text);
    final out = <String, String>{
      'name': '',
      'sex': '',
      'dob': '',
      'dateIssued': '',
      'idNo': '',
    };

    // Name: value sits right of (or after the colon of) the "Name:" label
    final nameLabel = _findLabel(lines, RegExp(r'^\s*N[a4]me\s*:?'));
    if (nameLabel != null) {
      final raw =
          _inlineValue(lines, nameLabel, RegExp(r'^\s*N[a4]me\s*:?\s*'));
      out['name'] = _cleanName(raw);
    }

    // Sex: "Sex: Female" or a bare Male/Female line anywhere
    final sexLabel = _findLabel(lines, RegExp(r'^\s*Sex\s*:?'));
    var sexRaw = '';
    if (sexLabel != null) {
      sexRaw = _inlineValue(lines, sexLabel, RegExp(r'^\s*Sex\s*:?\s*'));
    }
    final sexMatch =
        RegExp(r'\b(FEMALE|MALE)\b', caseSensitive: false).firstMatch(
      sexRaw.isNotEmpty ? sexRaw : text.text,
    );
    if (sexMatch != null) {
      out['sex'] = sexMatch.group(1)!.toUpperCase() == 'FEMALE' ? 'F' : 'M';
    }

    // Dates: value printed directly above its label
    final dobLabel = _findLabel(
      lines,
      RegExp(r'DATE\s*OF\s*BIRTH|BIRTH\s*DATE', caseSensitive: false),
    );
    if (dobLabel != null) {
      out['dob'] = _monthDate(_valueAbove(lines, dobLabel));
    }
    final issuedLabel = _findLabel(
      lines,
      RegExp(r'DATE\s*ISSUED|ISSUE\s*DATE', caseSensitive: false),
    );
    if (issuedLabel != null) {
      out['dateIssued'] = _monthDate(_valueAbove(lines, issuedLabel));
    }

    // ID No.: digits printed directly above the "ID No." label
    final idLabel = _findLabel(
      lines,
      RegExp(r'^\s*[I1l]D\s*N[o0]\.?\s*:?\s*$', caseSensitive: false),
    );
    if (idLabel != null) {
      out['idNo'] = _digitsFromDigitLike(_valueAbove(lines, idLabel));
      if (out['idNo']!.isEmpty) {
        // Some layouts print "ID No.: 12345" on one line
        out['idNo'] = _digitsFromDigitLike(
          _inlineValue(
              lines, idLabel, RegExp(r'^\s*[I1l]D\s*N[o0]\.?\s*:?\s*')),
        );
      }
    }

    debugPrint('🔎 ML Kit new-format anchors: $out');
    return out;
  }

  // ===========================================================================
  // GEOMETRY HELPERS
  // ===========================================================================

  static List<_Line> _lines(RecognizedText text) {
    final lines = <_Line>[];
    for (final block in text.blocks) {
      for (final line in block.lines) {
        lines.add(_Line(line.text, line.boundingBox, line.elements));
      }
    }
    return lines;
  }

  static _Line? _findLabel(List<_Line> lines, RegExp pattern) {
    for (final line in lines) {
      if (pattern.hasMatch(line.text)) return line;
    }
    return null;
  }

  /// Text on the label's own line after the label, plus any lines to its right
  /// on the same row.
  static String _inlineValue(List<_Line> lines, _Line label, RegExp strip) {
    final parts = <MapEntry<double, String>>[];
    final own = label.text.replaceFirst(strip, '').trim();
    if (own.isNotEmpty) parts.add(MapEntry(label.box.left, own));

    for (final line in lines) {
      if (identical(line, label)) continue;
      final sameRow = (line.cy - label.cy).abs() < label.box.height * 0.6;
      if (sameRow && line.box.left >= label.box.right - 4) {
        parts.add(MapEntry(line.box.left, line.text.trim()));
      }
    }
    parts.sort((a, b) => a.key.compareTo(b.key));
    return parts.map((e) => e.value).join(' ').trim();
  }

  /// The line printed immediately above [label], horizontally overlapping it.
  static String _valueAbove(List<_Line> lines, _Line label) {
    _Line? best;
    double bestGap = double.infinity;
    final maxGap = math.max(label.box.height * 3.0, 20.0);

    for (final line in lines) {
      if (identical(line, label)) continue;
      final gap = label.box.top - line.box.bottom;
      if (gap < -label.box.height * 0.3 || gap > maxGap) continue;

      final overlap = math.min(line.box.right, label.box.right) -
          math.max(line.box.left, label.box.left);
      final minWidth = math.min(line.box.width, label.box.width);
      if (minWidth <= 0 || overlap / minWidth < 0.3) continue;

      if (gap < bestGap) {
        bestGap = gap;
        best = line;
      }
    }
    return best?.text.trim() ?? '';
  }

  // ===========================================================================
  // VALUE CLEANING
  // ===========================================================================

  /// Digits from a token that is "digit-like": mostly digits, possibly with
  /// the usual look-alikes (O→0, I/l→1, S→5, B→8, Z→2). Returns '' for
  /// ordinary words so labels never leak into numbers.
  static String _digitsFromDigitLike(String token) {
    final compact = token.replaceAll(RegExp(r'[\s\-.,:]'), '');
    if (compact.isEmpty) return '';
    final realDigits = RegExp(r'\d').allMatches(compact).length;
    final likeChars = RegExp(r'[0-9OoIlSBZ]').allMatches(compact).length;
    if (realDigits < 1 ||
        compact.length < 2 ||
        likeChars / compact.length < 0.85) {
      return '';
    }
    return compact
        .replaceAll(RegExp(r'[Oo]'), '0')
        .replaceAll(RegExp(r'[Il]'), '1')
        .replaceAll('S', '5')
        .replaceAll('B', '8')
        .replaceAll('Z', '2')
        .replaceAll(RegExp(r'\D'), '');
  }

  static String _cleanName(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[^A-Za-zñÑ .\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final words = cleaned.split(' ').where((w) => w.length >= 2 || w == 'Ñ');
    return words.length >= 2 ? cleaned : '';
  }

  /// Finds "Month D, YYYY" in [raw], repairing a one-character month misread
  /// ("Ju1y" → "July") and digit look-alikes. Returns '' if no plausible date.
  static String _monthDate(String raw) {
    final match = RegExp(
      r'([A-Za-z0-9]{3,9})\.?\s*([0-9OIl]{1,2})\s*,?\s*([0-9OIlS]{4})',
    ).firstMatch(raw);
    if (match == null) return '';

    final month = _fixMonth(match.group(1)!);
    if (month == null) return '';
    String digits(String s) => s
        .replaceAll(RegExp(r'[Oo]'), '0')
        .replaceAll(RegExp(r'[Il]'), '1')
        .replaceAll('S', '5');
    final day = int.tryParse(digits(match.group(2)!));
    final year = int.tryParse(digits(match.group(3)!));
    if (day == null || year == null) return '';
    if (day < 1 || day > 31) return '';
    if (year < 1900 || year > DateTime.now().year + 1) return '';

    final name = month[0] + month.substring(1).toLowerCase();
    return '$name $day, $year';
  }

  static String? _fixMonth(String token) {
    final t = token
        .toUpperCase()
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('5', 'S');
    for (final m in _months) {
      if (t == m ||
          (t.length == 3 && m.startsWith(t)) ||
          t == '${m.substring(0, 3)}.') {
        return m;
      }
    }
    if (t == 'SEPT') return 'SEPTEMBER';
    if (t.length >= 4) {
      for (final m in _months) {
        if (_editDistance(t, m) <= 1) return m;
      }
    }
    return null;
  }

  static int _editDistance(String a, String b) {
    if ((a.length - b.length).abs() > 1) return 2;
    final dp = List.generate(
      a.length + 1,
      (i) => List<int>.filled(b.length + 1, 0),
    );
    for (int i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = math.min(
          math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
          dp[i - 1][j - 1] + cost,
        );
      }
    }
    return dp[a.length][b.length];
  }
}
