import 'package:flutter_test/flutter_test.dart';
import 'package:idetect/services/outside_lgu_detector.dart';

void main() {
  group('classifyIssuingCity', () {
    test('flags a card that names another city in the header', () {
      expect(
        classifyIssuingCity('CITY OF MALABON\nSENIOR CITIZEN ID\nJUAN DELA CRUZ'),
        IssuingCity.other,
      );
    });

    test('flags the City Government wording', () {
      expect(
        classifyIssuingCity('CITY GOVERNMENT OF MALABON\nSENIOR CITIZEN ID'),
        IssuingCity.other,
      );
    });

    test('flags Tagalog wording', () {
      expect(classifyIssuingCity('LUNGSOD NG MALABON\nID 123'), IssuingCity.other);
      expect(classifyIssuingCity('BAYAN NG BOCAUE\nID 123'), IssuingCity.other);
    });

    test('flags multi-word city names', () {
      expect(
        classifyIssuingCity('CITY OF SAN JOSE DEL MONTE\nID 123'),
        IssuingCity.other,
      );
    });

    test('treats a Valenzuela header as valenzuela', () {
      expect(
        classifyIssuingCity('CITY GOVERNMENT OF VALENZUELA\nSENIOR CITIZEN ID'),
        IssuingCity.valenzuela,
      );
    });

    test('a Valenzuela header wins over another city in the header', () {
      expect(
        classifyIssuingCity('CITY GOVERNMENT OF VALENZUELA\nCITY OF MALABON'),
        IssuingCity.valenzuela,
      );
    });

    test('tolerates a common OCR misread of Valenzuela', () {
      expect(
        classifyIssuingCity('CITY GOVERNMENT OF VALENZUEIA\nID 123'),
        IssuingCity.valenzuela,
      );
    });

    test('does not flag a bare city or surname without a government keyword', () {
      expect(classifyIssuingCity('MALABON\nJUAN DELA CRUZ'), IssuingCity.unknown);
      expect(classifyIssuingCity('ANGELES\nLOPEZ\nID 123'), IssuingCity.unknown);
    });

    test('ignores a city printed below the header lines', () {
      final lines = List<String>.generate(10, (i) => 'LINE ${i + 1}');
      lines[9] = 'CITY OF MALABON';
      expect(classifyIssuingCity(lines.join('\n')), IssuingCity.unknown);
    });

    test('returns unknown for empty or missing text', () {
      expect(classifyIssuingCity(null), IssuingCity.unknown);
      expect(classifyIssuingCity(''), IssuingCity.unknown);
      expect(classifyIssuingCity('   \n  \n'), IssuingCity.unknown);
    });

    test('matches a city name with one misread letter', () {
      expect(classifyIssuingCity('CITY OF MALABQN\nID 123'), IssuingCity.other);
      expect(classifyIssuingCity('CITY GOVERNMENT OF MALABQN\nID 123'), IssuingCity.other);
      expect(classifyIssuingCity('LUNGSOD NG MALABQN\nID 123'), IssuingCity.other);
    });

    test('matches a longer city name with two misread letters', () {
      expect(
        classifyIssuingCity('CITY OF SAN JOSE DEL M0NTE\nID 123'),
        IssuingCity.other,
      );
      expect(
        classifyIssuingCity('CITY OF SAN JOSE DEL M0N7E\nID 123'),
        IssuingCity.other,
      );
    });

    test('does not match a short city name with a misread letter', () {
      expect(classifyIssuingCity('CITY OF PILER\nID 123'), IssuingCity.unknown);
    });

    test('does not match a name with too many misread letters', () {
      expect(classifyIssuingCity('CITY OF MALAB\nID 123'), IssuingCity.unknown);
      expect(classifyIssuingCity('CITY OF MALAXQN\nID 123'), IssuingCity.unknown);
    });

    test('a misread Valenzuela after the keyword still counts as Valenzuela', () {
      expect(
        classifyIssuingCity('CITY OF VALEN2UELA\nCITY OF MALABON'),
        IssuingCity.valenzuela,
      );
    });
  });

  group('headerLines', () {
    test('keeps the first 8 non-empty trimmed lines', () {
      final raw = List<String>.generate(12, (i) => '  L${i + 1}  ').join('\n\n');
      final header = headerLines(raw).split('\n');
      expect(header.length, headerLineCount);
      expect(header.first, 'L1');
      expect(header.last, 'L8');
    });
  });

  test('textNamesOtherCity is true only for other-city text', () {
    expect(textNamesOtherCity('CITY OF MALABON'), isTrue);
    expect(textNamesOtherCity('CITY GOVERNMENT OF VALENZUELA'), isFalse);
    expect(textNamesOtherCity(null), isFalse);
  });
}
