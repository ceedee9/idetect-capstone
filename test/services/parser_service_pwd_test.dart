import 'package:flutter_test/flutter_test.dart';
import 'package:idetect/services/parser_service.dart';

void main() {
  group('ParserService PWD extraction', () {
    test(
        'extracts name, disability type, and id number from multiline PWD ID text',
        () async {
      final parser = ParserService();

      const rawText = '''
REPUBLIC OF THE PHILIPPINES
CITY GOVERNMENT OF VALENZUELA
PERSON WITH DISABILITY
MA. INES L. DELOS REYES
NAME
MENTAL
TYPE OF DISABILITY
ID NO. 13-7504-000-0004941
''';

      final parsed = await parser.parseIDText(rawText);

      expect(parsed.success, isTrue);
      expect(parsed.idType, IDType.pwd);
      expect(parsed.fullName, 'MA Ines L Delos Reyes');
      expect(parsed.disabilityType, 'Mental Disability');
      expect(parsed.idNumber, '13-7504-000-0004941');
    });

    test('normalizes alias disability labels into canonical values', () async {
      final parser = ParserService();

      const rawText = '''
PDAO
PERSON WITH DISABILITY
JUAN DELA CRUZ
NAME
TYPE OF DISABILITY: HEARING
ID NO: 13-1234-000-0009999
''';

      final parsed = await parser.parseIDText(rawText);

      expect(parsed.success, isTrue);
      expect(parsed.idType, IDType.pwd);
      expect(parsed.disabilityType, 'Deaf or Hard of Hearing');
      expect(parsed.idNumber, '13-1234-000-0009999');
    });

    test('keeps uppercase initials for PWD names', () async {
      final parser = ParserService();

      const rawText = '''
PWD
MA. A. SANTOS
NAME
PHYSICAL
TYPE OF DISABILITY
ID NO 13-0001-000-0000001
''';

      final parsed = await parser.parseIDText(rawText);

      expect(parsed.success, isTrue);
      expect(parsed.fullName, 'MA A Santos');
    });
  });

  test('preserves senior DOB and calculates age from it', () async {
    final parser = ParserService();

    const rawText = '''
OSCA SENIOR CITIZEN
NAME: MARIA SANTOS
DATE OF BIRTH: 12.31.1940
SEX: F
DATE ISSUED: 01/01/2025
CONTROL NO: 2025-0001
''';

    final parsed = await parser.parseIDText(rawText);

    expect(parsed.success, isTrue);
    expect(parsed.dateOfBirth, '12/31/40');
    expect(parsed.age, 85);
  });
}
