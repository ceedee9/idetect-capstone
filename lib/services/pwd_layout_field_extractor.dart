// =============================================================================
// FILE: lib/services/pwd_layout_field_extractor.dart
// PURPOSE: Layout-aware extraction for PWD IDs using OCR bounding boxes
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PWDLayoutFieldExtractor {
  static final RegExp _idPattern = RegExp(r'\b\d{2}-\d{4}-\d{3}-\d{4,8}\b');

  /// Substitutes common OCR misreads before running the ID number regex.
  /// Applies only to the candidate string, not to name/disability fields.
  static String _sanitizeForId(String text) {
    return text
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .replaceAll('I', '1')
        .replaceAll('l', '1')
        .replaceAll('S', '5')
        .replaceAll('s', '5')
        .replaceAll('B', '8')
        .replaceAll('Z', '2');
  }

  static final Map<String, String> _disabilityAliases = {
    'DEAF OR HARD OF HEARING': 'Deaf or Hard of Hearing',
    'DEAF': 'Deaf or Hard of Hearing',
    'HARD OF HEARING': 'Deaf or Hard of Hearing',
    'HEARING': 'Deaf or Hard of Hearing',
    'INTELLECTUAL DISABILITY': 'Intellectual Disability',
    'INTELLECTUAL': 'Intellectual Disability',
    'LEARNING DISABILITY': 'Learning Disability',
    'LEARNING': 'Learning Disability',
    'MENTAL DISABILITY': 'Mental Disability',
    'MENTAL': 'Mental Disability',
    'PSYCHOSOCIAL DISABILITY': 'Psychosocial Disability',
    'PSYCHOSOCIAL': 'Psychosocial Disability',
    'PHYSICAL DISABILITY': 'Physical Disability',
    'PHYSICAL': 'Physical Disability',
    'ORTHOPEDIC': 'Physical Disability',
    'MOBILITY': 'Physical Disability',
    'SPEECH AND LANGUAGE IMPAIRMENT': 'Speech and Language Impairment',
    'SPEECH': 'Speech and Language Impairment',
    'LANGUAGE': 'Speech and Language Impairment',
    'VISUAL DISABILITY': 'Visual Disability',
    'VISUAL': 'Visual Disability',
    'BLIND': 'Visual Disability',
    'CANCER': 'Cancer',
    'RARE DISEASE': 'Rare Disease',
  };

  static Future<Map<String, dynamic>> extractFieldsWithLayout({
    required RecognizedText recognizedText,
    required int imageWidth,
    required int imageHeight,
  }) async {
    final lines = <_LineNode>[];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        final box = line.boundingBox;
        lines.add(_LineNode(
          text: text,
          upper: text.toUpperCase(),
          left: box.left.toDouble(),
          right: box.right.toDouble(),
          top: box.top.toDouble(),
          bottom: box.bottom.toDouble(),
          centerX: (box.left + box.right) / 2,
          centerY: (box.top + box.bottom) / 2,
        ));
      }
    }

    if (lines.isEmpty) {
      return {
        'fullName': '',
        'disabilityType': '',
        'idNumber': '',
        'confidence': 0.0,
        'fieldConfidences': {
          'fullName': 0.0,
          'disabilityType': 0.0,
          'idNumber': 0.0,
        },
        'extractionMethod': 'pwd-layout',
      };
    }

    final nameAnchor = _findAnchor(lines, ['NAME']);
    final disabilityAnchor =
        _findAnchor(lines, ['TYPE OF DISABILITY', 'DISABILITY TYPE']);
    final idAnchor = _findAnchor(lines, ['ID NO', 'ID NUMBER', 'ID NO.']);

    final nameCandidate = _extractNearestAbove(
      lines: lines,
      anchor: nameAnchor,
      imageHeight: imageHeight,
      maxDistanceFactor: 0.22,
      accept: (v) => _looksLikeName(v),
    );

    final disabilityCandidate = _extractNearestAbove(
      lines: lines,
      anchor: disabilityAnchor,
      imageHeight: imageHeight,
      maxDistanceFactor: 0.18,
      accept: (v) => _normalizeDisability(v).isNotEmpty,
    );

    final idCandidate = _extractIDNumber(
        lines: lines, idAnchor: idAnchor, imageHeight: imageHeight);

    var normalizedName = _normalizeName(nameCandidate ?? '');
    final normalizedDisability =
        _normalizeDisability(disabilityCandidate ?? '');
    final normalizedId = (idCandidate == null)
        ? ''
        : (_idPattern.firstMatch(idCandidate)?.group(0) ?? idCandidate);

    // Fix: ML Kit may combine the name and disability type into one line
    // (e.g. "MA. INES L. DELOS REYES MENTAL"). Strip trailing disability.
    normalizedName = _stripTrailingDisability(normalizedName);

    final nameConfidence = normalizedName.isNotEmpty ? 0.90 : 0.0;
    final disabilityConfidence = normalizedDisability.isNotEmpty ? 0.92 : 0.0;
    final idConfidence = _idPattern.hasMatch(normalizedId) ? 0.95 : 0.0;

    var overall = 0.0;
    var n = 0;
    for (final c in [nameConfidence, disabilityConfidence, idConfidence]) {
      if (c > 0) {
        overall += c;
        n++;
      }
    }
    overall = n == 0 ? 0.0 : (overall / n).clamp(0.0, 1.0);

    debugPrint('♿ PWD layout extraction summary:');
    debugPrint('   Name: "$normalizedName"');
    debugPrint('   Disability: "$normalizedDisability"');
    debugPrint('   ID: "$normalizedId"');
    debugPrint('   Confidence: ${(overall * 100).toInt()}%');

    return {
      'fullName': normalizedName,
      'disabilityType': normalizedDisability,
      'idNumber': normalizedId,
      'confidence': overall,
      'fieldConfidences': {
        'fullName': nameConfidence,
        'disabilityType': disabilityConfidence,
        'idNumber': idConfidence,
      },
      'extractionMethod': 'pwd-layout',
    };
  }

  static _LineNode? _findAnchor(List<_LineNode> lines, List<String> patterns) {
    for (final line in lines) {
      for (final p in patterns) {
        if (line.upper.contains(p)) {
          return line;
        }
      }
    }
    return null;
  }

  static String? _extractNearestAbove({
    required List<_LineNode> lines,
    required _LineNode? anchor,
    required int imageHeight,
    required double maxDistanceFactor,
    required bool Function(String) accept,
  }) {
    if (anchor == null) return null;

    final maxDistance = imageHeight * maxDistanceFactor;
    String? best;
    double bestDistance = double.infinity;

    for (final line in lines) {
      if (line.centerY >= anchor.centerY) continue;

      final verticalDistance = anchor.centerY - line.centerY;
      if (verticalDistance > maxDistance) continue;

      final horizontalOverlap =
          (line.right >= anchor.left - 20) && (line.left <= anchor.right + 20);
      if (!horizontalOverlap) continue;

      if (!accept(line.text)) continue;

      if (verticalDistance < bestDistance) {
        bestDistance = verticalDistance;
        best = line.text;
      }
    }

    return best;
  }

  static String? _extractIDNumber({
    required List<_LineNode> lines,
    required _LineNode? idAnchor,
    required int imageHeight,
  }) {
    // Priority 1: explicit match across all lines.
    // Try original text first, then OCR-sanitized fallback.
    for (final line in lines) {
      final match = _idPattern.firstMatch(line.text);
      if (match != null) return match.group(0);
    }
    // Sanitized pass (O→0, I→1, l→1, S→5, etc.)
    for (final line in lines) {
      final sanitized = _sanitizeForId(line.text);
      final match = _idPattern.firstMatch(sanitized);
      if (match != null) return match.group(0);
    }

    if (idAnchor == null) return null;

    // Priority 2: close to ID anchor (same row or just below).
    final maxDistance = imageHeight * 0.08;
    for (final line in lines) {
      final dy = (line.centerY - idAnchor.centerY).abs();
      if (dy > maxDistance) continue;

      // Try original first, then sanitized
      for (final candidate in [line.text, _sanitizeForId(line.text)]) {
        final match = RegExp(r'([0-9-]{8,30})').firstMatch(candidate);
        if (match != null) {
          final val = match.group(1) ?? '';
          if (val.contains('-')) return val;
        }
      }
    }

    return null;
  }

  static bool _looksLikeName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z\s\.-]'), ' ').trim();
    final upper = cleaned.toUpperCase();

    if (cleaned.isEmpty) return false;
    if (upper.contains('PWD') ||
        upper.contains('TYPE') ||
        upper.contains('DISABILITY') ||
        upper.contains('ID NO')) {
      return false;
    }

    final words =
        cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 2 || words.length > 8) return false;

    return words.any((w) => w.replaceAll('.', '').length >= 2);
  }

  static String _normalizeName(String value) {
    var cleaned = value
        .replaceAll(RegExp(r'[^A-Za-z\s\.-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return '';

    return cleaned.split(' ').map((word) {
      final normalized = word.replaceAll('.', '');
      if (normalized.isEmpty) return '';

      final isAbbrev =
          normalized.length <= 3 && normalized == normalized.toUpperCase();
      if (isAbbrev) return normalized.toUpperCase();
      if (normalized.toLowerCase() == 'delos') return 'Delos';

      return normalized[0].toUpperCase() +
          normalized.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Strip trailing disability type keywords from a name string.
  /// Handles the common case where ML Kit concatenates name + disability.
  static String _stripTrailingDisability(String name) {
    if (name.isEmpty) return name;
    final nameUpper = name.toUpperCase();
    // Try longest aliases first so "HARD OF HEARING" matches before "HEARING"
    final sortedAliases = _disabilityAliases.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final alias in sortedAliases) {
      if (nameUpper.endsWith(alias)) {
        final stripped = name.substring(0, name.length - alias.length).trim();
        // Only accept if the remaining text still looks like a name
        if (stripped.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >=
            2) {
          return stripped;
        }
      }
    }
    return name;
  }

  static String _normalizeDisability(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[^A-Za-z\s/-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();

    if (normalized.isEmpty) return '';

    if (_disabilityAliases.containsKey(normalized)) {
      return _disabilityAliases[normalized]!;
    }

    for (final token in _disabilityAliases.keys) {
      if (normalized.contains(token)) {
        return _disabilityAliases[token]!;
      }
    }

    return '';
  }
}

class _LineNode {
  final String text;
  final String upper;
  final double left;
  final double right;
  final double top;
  final double bottom;
  final double centerX;
  final double centerY;

  _LineNode({
    required this.text,
    required this.upper,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.centerX,
    required this.centerY,
  });
}
