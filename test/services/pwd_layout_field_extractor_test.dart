import 'package:flutter_test/flutter_test.dart';
import 'package:idetect/services/parser_service.dart';

void main() {
  group('PWD extraction heuristics regression checks', () {
    test('handles uppercase labels and keeps canonical disability type',
        () async {
      final parser = ParserService();

      const rawText = '''
CITY GOVERNMENT OF VALENZUELA
PERSON WITH DISABILITY
MA. INES L. DELOS REYES
NAME
TYPE OF DISABILITY
MENTAL
ID NO. 13-7504-000-0004941
''';

      final parsed = await parser.parseIDText(rawText);

      expect(parsed.success, isTrue);
      expect(parsed.idType, IDType.pwd);
      expect(parsed.fullName, 'MA Ines L Delos Reyes');
      expect(parsed.disabilityType, 'Mental Disability');
      expect(parsed.idNumber, '13-7504-000-0004941');
    });

    test('prefers canonical mapping for common OCR alias', () async {
      final parser = ParserService();

      const rawText = '''
PWD
JUAN D. CRUZ
NAME
HEARING
TYPE OF DISABILITY
ID NO: 13-1234-000-0008888
''';

      final parsed = await parser.parseIDText(rawText);

      expect(parsed.success, isTrue);
      expect(parsed.disabilityType, 'Deaf or Hard of Hearing');
      expect(parsed.idNumber, '13-1234-000-0008888');
    });
  });
}
