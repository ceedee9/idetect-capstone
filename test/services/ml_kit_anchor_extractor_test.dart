import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:idetect/services/layout_based_field_extractor.dart';
import 'package:idetect/services/ml_kit_anchor_extractor.dart';

TextElement _el(String text, Rect box) => TextElement(
      text: text,
      symbols: const [],
      boundingBox: box,
      recognizedLanguages: const [],
      cornerPoints: const [],
      confidence: null,
      angle: null,
    );

/// One ML Kit line whose elements are the space-separated words, laid out
/// evenly across [box].
TextLine _line(String text, Rect box) {
  final words = text.split(' ');
  final w = box.width / words.length;
  final elements = [
    for (var i = 0; i < words.length; i++)
      _el(
        words[i],
        Rect.fromLTWH(box.left + i * w, box.top, w, box.height),
      ),
  ];
  return TextLine(
    text: text,
    elements: elements,
    boundingBox: box,
    recognizedLanguages: const [],
    cornerPoints: const [],
    confidence: null,
    angle: null,
  );
}

RecognizedText _recognized(Map<String, Rect> lines) {
  final blocks = [
    for (final e in lines.entries)
      TextBlock(
        text: e.key,
        lines: [_line(e.key, e.value)],
        boundingBox: e.value,
        recognizedLanguages: const [],
        cornerPoints: const [],
      ),
  ];
  return RecognizedText(text: lines.keys.join('\n'), blocks: blocks);
}

void main() {
  group('control number (old format)', () {
    // Coordinates measured from assets/images/seniorCitizenID.jpg (2000x1363)
    const w = 2000;
    const h = 1363;

    test('picks the tall red number, ignoring dates and labels', () {
      final text = _recognized({
        'Name: MARIA M. DELOS REYES': const Rect.fromLTWH(100, 480, 1200, 80),
        '11-03-64': const Rect.fromLTWH(80, 770, 380, 70),
        '12-04-24': const Rect.fromLTWH(950, 780, 400, 70),
        'Control No.': const Rect.fromLTWH(1260, 1100, 290, 70),
        '137005': const Rect.fromLTWH(1390, 1020, 510, 120),
      });
      expect(MlKitAnchorExtractor.controlNumberOldFormat(text, w, h), '137005');
    });

    test('repairs look-alike characters and split digit groups', () {
      final text = _recognized({
        'Control No.': const Rect.fromLTWH(1260, 1100, 290, 70),
        '137 OO5': const Rect.fromLTWH(1390, 1020, 510, 120),
      });
      expect(MlKitAnchorExtractor.controlNumberOldFormat(text, w, h), '137005');
    });

    test('returns empty when nothing number-like is in the lower right', () {
      final text = _recognized({
        '12-04-24': const Rect.fromLTWH(950, 780, 400, 70),
        'Control No.': const Rect.fromLTWH(1260, 1100, 290, 70),
      });
      expect(MlKitAnchorExtractor.controlNumberOldFormat(text, w, h), '');
    });
  });

  group('new format labelled fields', () {
    const w = 1600;
    const h = 1009;

    test('reads values printed above their labels and inline fields', () {
      final text = _recognized({
        'Name: JUAN DELA CRUZ': const Rect.fromLTWH(480, 330, 800, 60),
        'Sex: Female': const Rect.fromLTWH(1000, 520, 300, 50),
        'July 15, 1965': const Rect.fromLTWH(480, 580, 300, 40),
        'Date of Birth': const Rect.fromLTWH(480, 625, 250, 30),
        'Ju1y 9, 2024': const Rect.fromLTWH(880, 580, 300, 40),
        'Date Issued': const Rect.fromLTWH(880, 625, 220, 30),
        '123456': const Rect.fromLTWH(40, 800, 260, 50),
        'ID No.': const Rect.fromLTWH(40, 855, 160, 30),
      });

      final fields = MlKitAnchorExtractor.newFormatFields(text, w, h);
      expect(fields['name'], 'JUAN DELA CRUZ');
      expect(fields['sex'], 'F');
      expect(fields['dob'], 'July 15, 1965');
      expect(fields['dateIssued'], 'July 9, 2024');
      expect(fields['idNo'], '123456');
    });

    test('leaves fields empty when labels are missing', () {
      final text = _recognized({
        'Republic of the Philippines': const Rect.fromLTWH(300, 20, 900, 60),
      });
      final fields = MlKitAnchorExtractor.newFormatFields(text, w, h);
      expect(fields.values.every((v) => v.isEmpty), isTrue);
    });
  });

  group('resolveIdentifier', () {
    test('agreement gives high confidence', () {
      final r = LayoutBasedFieldExtractor.resolveIdentifier('137005', '137005');
      expect(r.value, '137005');
      expect(r.confidence, greaterThan(0.9));
    });

    test('disagreement keeps ML Kit but flags it', () {
      final r = LayoutBasedFieldExtractor.resolveIdentifier('137005', '137006');
      expect(r.value, '137005');
      expect(r.confidence, lessThan(0.7));
    });

    test('single valid source is used', () {
      expect(
        LayoutBasedFieldExtractor.resolveIdentifier('', '115806').value,
        '115806',
      );
      expect(
        LayoutBasedFieldExtractor.resolveIdentifier('115806', '').value,
        '115806',
      );
    });

    test('partial read is surfaced with very low confidence', () {
      final r = LayoutBasedFieldExtractor.resolveIdentifier('', '13');
      expect(r.value, '13');
      expect(r.confidence, lessThan(0.5));
    });

    test('nothing read gives empty with zero confidence', () {
      final r = LayoutBasedFieldExtractor.resolveIdentifier('', '');
      expect(r.value, '');
      expect(r.confidence, 0.0);
    });
  });
}
