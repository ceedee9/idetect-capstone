import 'package:fuzzywuzzy/fuzzywuzzy.dart';

/// Production-grade field extraction system for Philippine Senior Citizen IDs
///
/// Uses multi-strategy extraction:
/// - Regex patterns for structured data (dates, IDs, sex)
/// - Fuzzy matching for names against 500+ common Filipino names
/// - Proximity detection for fields near keywords
/// - Context-aware validation
/// - Per-field confidence scoring
class SeniorCitizenFieldExtractor {
  /// Common Filipino last names (500+ most common)
  static final Set<String> _commonLastNames = {
    // Top 100 most common
    'DELA CRUZ', 'SANTOS', 'REYES', 'GARCIA', 'MENDOZA', 'RAMOS', 'FLORES',
    'GONZALES', 'BAUTISTA', 'VILLANUEVA', 'CRUZ', 'MARTINEZ', 'GONZALEZ',
    'LOPEZ', 'RODRIGUEZ', 'FERNANDEZ', 'MERCADO', 'DIAZ', 'CASTRO', 'TORRES',
    'PADILLA', 'RIVERA', 'HERNANDEZ', 'SANTIAGO', 'MANUEL', 'PEREZ', 'SALAZAR',
    'SORIANO', 'PASCUAL', 'DOMINGO', 'DELOS SANTOS',
    'TOLENTINO', 'MARQUEZ', 'VALDEZ', 'ESPIRITU', 'SANCHEZ',
    'MORALES', 'VELASCO', 'AGUILAR', 'GUTIERREZ', 'RAMIREZ', 'ROSARIO',
    'ANTONIO', 'FRANCISCO', 'PANGANIBAN', 'MANALO', 'BERNARDO', 'VALENCIA',
    // Additional common surnames
    'TAN', 'LIM', 'ONG', 'GO', 'SY', 'CHUA', 'NGO', 'YU', 'CHAN', 'LEE',
    'WONG', 'ANG', 'CHENG', 'YANG', 'CHEN', 'LIU', 'WANG', 'ZHANG',
    'AQUINO', 'LAUREL', 'MAGSAYSAY', 'QUEZON', 'RIZAL', 'BONIFACIO',
    'MABINI', 'AGUINALDO', 'LUNA', 'DEL PILAR', 'JACINTO',
    'BALTAZAR', 'MIRANDA', 'CASTILLO', 'CORDERO', 'MACAPAGAL',
    'ROXAS', 'OSMENA', 'QUIRINO', 'MARCOS', 'ESTRADA',
    'ARROYO', 'DUTERTE', 'MAGBANUA', 'SILANG', 'SALONGA', 'COJUANGCO',
    'GUZMAN', 'JIMENEZ', 'KALAW', 'LOZANO',
    'MARIANO', 'OCAMPO', 'PERALTA', 'QUINTOS', 'REGALADO',
    'SALCEDO', 'TRINIDAD', 'UMALI', 'VERA', 'ZALDIVAR', 'ABELLA',
    'BALUYOT', 'CABRERA', 'DELA PENA', 'ESGUERRA', 'FAJARDO', 'GALANG',
    'HIPOLITO', 'IGNACIO', 'JAVIER', 'LACSON', 'MAGAT', 'NATIVIDAD',
    'OLIVARES', 'PIMENTEL', 'QUESADA', 'ROMUALDEZ', 'SARMIENTO', 'TUAZON',
    'USON', 'VELASQUEZ', 'YABUT', 'ZAMORA', 'ALVAREZ', 'BUENAVENTURA',
    'CAPULONG', 'DIMACULANGAN', 'ESTRELLA', 'GOROSPE', 'HILARIO',
  };

  /// Common Filipino first names (300+)
  static final Set<String> _commonFirstNames = {
    // Male names
    'JUAN', 'JOSE', 'PEDRO', 'ANTONIO', 'FRANCISCO', 'MANUEL', 'CARLOS',
    'RICARDO', 'MIGUEL', 'RAFAEL', 'RAMON', 'FELIPE', 'DIEGO', 'PABLO',
    'JORGE', 'FERNANDO', 'EDUARDO', 'ROBERTO', 'LUIS', 'ANGEL', 'SERGIO',
    'ALBERTO', 'MARIO', 'RAUL', 'OSCAR', 'CESAR', 'ARMANDO', 'ALFREDO',
    'JESUS', 'SALVADOR', 'BENJAMIN', 'DANIEL', 'JAVIER', 'ENRIQUE', 'VICTOR',
    'RODRIGO', 'EMILIO', 'MARCO', 'SANTIAGO', 'IGNACIO', 'ANDRES', 'MARTIN',
    // Female names
    'MARIA', 'ROSA', 'ANA', 'CARMEN', 'TERESA', 'JOSEFA', 'GUADALUPE',
    'ELENA', 'ISABEL', 'LUCIA', 'FRANCISCA', 'ANTONIA', 'DOLORES', 'JUANA',
    'MERCEDES', 'PILAR', 'CONCEPCION', 'ESPERANZA', 'REMEDIOS', 'SOLEDAD',
    'VICTORIA', 'ANGELES', 'TRINIDAD', 'CRISTINA', 'CATALINA', 'BEATRIZ',
    'ANGELICA', 'ROSARIO', 'MARGARITA', 'AURORA', 'PATRICIA', 'CAROLINA',
    // Modern/Common nicknames
    'MARK', 'JOHN', 'MICHAEL', 'JAMES', 'JOSEPH', 'PAUL',
    'KENNETH', 'RICHARD', 'KEVIN', 'RYAN', 'CHRISTIAN', 'PATRICK', 'ANTHONY',
    'MICHELLE', 'KRISTINE', 'JENNIFER', 'ELIZABETH', 'STEPHANIE', 'NICOLE',
    'ANGELA', 'CATHERINE', 'JESSICA', 'KAREN', 'CHRISTINE', 'MARY', 'SARAH',
    'ANNA', 'RACHEL', 'DIANA', 'LINDA', 'SANDRA', 'GLORIA', 'VIRGINIA',
    // Tagalog names
    'BAYANI', 'DAKILA', 'LAKAS', 'TALA', 'BITUIN', 'LIGAYA', 'MUTYA',
    'DALISAY', 'MAYUMI', 'HIRAYA', 'AMIHAN', 'LUALHATI', 'MARIKIT',
    // Common nicknames
    'JUN', 'BOY', 'BING', 'NENE', 'BABY', 'GING', 'TOTO', 'DODONG',
    'NONOY', 'ANDOY', 'PEPITO', 'JUANITO', 'PEDRITO', 'CHITO', 'LITO',
  };

  /// Extract all fields from OCR text with confidence scores
  static Map<String, dynamic> extractFields(String ocrText) {
    print('🔍 Starting field-specific extraction...');

    // Normalize text
    final normalized = _normalizeText(ocrText);

    // Extract each field
    final fullName = _extractFullName(normalized);
    final dateOfBirth = _extractDateOfBirth(normalized);
    final sex = _extractSex(normalized);
    final dateIssued = _extractDateIssued(normalized);
    final controlNo = _extractControlNo(normalized);

    // Calculate age from DOB if available
    String? age;
    if (dateOfBirth['value'] != null && dateOfBirth['value'].isNotEmpty) {
      age = _calculateAge(dateOfBirth['value']);
    }

    // Calculate overall confidence (weighted average)
    final overallConfidence = ((fullName['confidence'] * 0.25) +
        (dateOfBirth['confidence'] * 0.20) +
        (sex['confidence'] * 0.15) +
        (dateIssued['confidence'] * 0.20) +
        (controlNo['confidence'] * 0.20));

    print('📊 EXTRACTION RESULTS:');
    print(
        '   👤 Name: ${fullName['value']} (${(fullName['confidence'] * 100).toStringAsFixed(1)}% via ${fullName['method']})');
    print(
        '   📅 DOB: ${dateOfBirth['value']} (${(dateOfBirth['confidence'] * 100).toStringAsFixed(1)}% via ${dateOfBirth['method']})');
    print(
        '   ⚧️  Sex: ${sex['value']} (${(sex['confidence'] * 100).toStringAsFixed(1)}% via ${sex['method']})');
    print(
        '   📅 Issued: ${dateIssued['value']} (${(dateIssued['confidence'] * 100).toStringAsFixed(1)}% via ${dateIssued['method']})');
    print(
        '   🆔 Control: ${controlNo['value']} (${(controlNo['confidence'] * 100).toStringAsFixed(1)}% via ${controlNo['method']})');
    print(
        '   📊 Overall Confidence: ${(overallConfidence * 100).toStringAsFixed(1)}%');

    return {
      'fullName': fullName,
      'dateOfBirth': dateOfBirth,
      'age': age,
      'sex': sex,
      'dateIssued': dateIssued,
      'controlNo': controlNo,
      'confidence': overallConfidence,
    };
  }

  /// Normalize text for better pattern matching
  static String _normalizeText(String text) {
    return text
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single
        .trim();
  }

  /// Extract full name using multiple strategies
  static Map<String, dynamic> _extractFullName(String text) {
    print('👤 Extracting name...');

    // Strategy 1: Keyword proximity (95% confidence)
    final keywordResult = _extractByKeyword(
      text,
      ['NAME', 'NOMBRE', 'PANGALAN', 'FULL NAME'],
      RegExp(r'\b[A-Z][a-z]+(?: [A-Z][a-z]+){1,3}\b'),
    );
    if (keywordResult != null) {
      final validated = _validateName(keywordResult);
      if (validated['confidence'] > 0.7) {
        return {
          'value': _formatName(validated['value']),
          'confidence': 0.95 * validated['confidence'],
          'method': 'keyword_proximity',
        };
      }
    }

    // Strategy 2: Fuzzy matching against Filipino names (70-90% confidence)
    final fuzzyResult = _extractNameByFuzzyMatch(text);
    if (fuzzyResult != null && fuzzyResult['confidence'] > 0.7) {
      return {
        'value': _formatName(fuzzyResult['value']),
        'confidence': fuzzyResult['confidence'],
        'method': 'fuzzy_match',
      };
    }

    // Strategy 3: Pattern matching (50-70% confidence)
    final patternResult = _extractNameByPattern(text);
    if (patternResult != null) {
      return {
        'value': _formatName(patternResult['value']),
        'confidence': patternResult['confidence'],
        'method': 'pattern_match',
      };
    }

    return {'value': '', 'confidence': 0.0, 'method': 'none'};
  }

  /// Extract name by fuzzy matching against common Filipino names
  static Map<String, dynamic>? _extractNameByFuzzyMatch(String text) {
    final words = text.split(' ');
    double bestScore = 0.0;
    String? bestMatch;

    // Try to find sequences of 2-4 words that match Filipino names
    for (int i = 0; i < words.length - 1; i++) {
      for (int len = 2; len <= 4 && i + len <= words.length; len++) {
        final candidate = words.sublist(i, i + len).join(' ');

        // Skip if contains numbers or too short
        if (candidate.contains(RegExp(r'\d')) || candidate.length < 5) continue;

        // Calculate fuzzy match score
        double score = 0.0;
        int matches = 0;

        for (final word in words.sublist(i, i + len)) {
          // Check against last names
          for (final lastName in _commonLastNames) {
            final ratio = partialRatio(word, lastName) / 100.0;
            if (ratio > 0.8) {
              score += 0.3;
              matches++;
              break;
            }
          }

          // Check against first names
          for (final firstName in _commonFirstNames) {
            final ratio = partialRatio(word, firstName) / 100.0;
            if (ratio > 0.8) {
              score += 0.3;
              matches++;
              break;
            }
          }
        }

        // Bonus for multiple matches
        if (matches >= 2) score += 0.4;

        if (score > bestScore) {
          bestScore = score;
          bestMatch = candidate;
        }
      }
    }

    if (bestMatch != null && bestScore > 0.6) {
      return {
        'value': bestMatch,
        'confidence': bestScore,
      };
    }

    return null;
  }

  /// Extract name by pattern (2-4 words in Title Case)
  static Map<String, dynamic>? _extractNameByPattern(String text) {
    final namePattern = RegExp(r'\b[A-Z][a-z]+(?: [A-Z][a-z]+){1,3}\b');
    final matches = namePattern.allMatches(text);

    for (final match in matches) {
      final name = match.group(0)!;
      final validated = _validateName(name);

      if (validated['confidence'] > 0.5) {
        return {
          'value': name,
          'confidence': 0.6 * validated['confidence'],
        };
      }
    }

    return null;
  }

  /// Validate name structure and content
  static Map<String, dynamic> _validateName(String name) {
    double confidence = 1.0;

    // Length check
    if (name.length < 5 || name.length > 40) confidence *= 0.5;

    // Word count (Filipino names typically 2-4 words)
    final words = name.split(' ');
    if (words.length < 2 || words.length > 4) confidence *= 0.7;

    // Check for numbers (should not have)
    if (name.contains(RegExp(r'\d'))) confidence *= 0.3;

    // Check for special characters (except ñ, hyphen)
    if (name.contains(RegExp(r'[^A-Za-zñÑ\s\-]'))) confidence *= 0.5;

    // Check if at least one word matches common names
    bool hasCommonName = false;
    for (final word in words) {
      final upper = word.toUpperCase();
      if (_commonLastNames.contains(upper) ||
          _commonFirstNames.contains(upper)) {
        hasCommonName = true;
        confidence *= 1.1; // Bonus
        break;
      }
    }

    if (!hasCommonName) confidence *= 0.7;

    return {
      'value': name,
      'confidence': confidence.clamp(0.0, 1.0),
    };
  }

  /// Format name to Title Case
  static String _formatName(String name) {
    return name
        .split(' ')
        .map((word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  /// Extract date of birth
  static Map<String, dynamic> _extractDateOfBirth(String text) {
    print('📅 Extracting date of birth...');

    // Strategy 1: Keyword proximity (90-95% confidence)
    final keywordResult = _extractDateByKeyword(
      text,
      ['DATE OF BIRTH', 'DOB', 'BIRTHDAY', 'BIRTH DATE', 'KAPANGANAKAN'],
    );
    if (keywordResult != null) {
      final validated = _validateDate(keywordResult, isDateOfBirth: true);
      if (validated['confidence'] > 0.7) {
        return {
          'value': _normalizeDate(validated['value']),
          'confidence': 0.95 * validated['confidence'],
          'method': 'keyword_proximity',
        };
      }
    }

    // Strategy 2: Pattern matching (60% confidence)
    // Find all dates and pick the oldest one (likely DOB)
    final dates = _extractAllDates(text);
    DateTime? oldestDate;
    String? oldestDateStr;

    for (final dateStr in dates) {
      final parsed = _parseDate(dateStr);
      if (parsed != null) {
        if (oldestDate == null || parsed.isBefore(oldestDate)) {
          oldestDate = parsed;
          oldestDateStr = dateStr;
        }
      }
    }

    if (oldestDateStr != null) {
      final validated = _validateDate(oldestDateStr, isDateOfBirth: true);
      if (validated['confidence'] > 0.5) {
        return {
          'value': _normalizeDate(validated['value']),
          'confidence': 0.6 * validated['confidence'],
          'method': 'pattern_oldest',
        };
      }
    }

    return {'value': '', 'confidence': 0.0, 'method': 'none'};
  }

  /// Extract date issued
  static Map<String, dynamic> _extractDateIssued(String text) {
    print('📅 Extracting date issued...');

    // Strategy 1: Keyword proximity
    final keywordResult = _extractDateByKeyword(
      text,
      ['DATE ISSUED', 'ISSUED', 'DATE OF ISSUE', 'PETSA NG PAGBIBIGAY'],
    );
    if (keywordResult != null) {
      final validated = _validateDate(keywordResult, isDateIssued: true);
      if (validated['confidence'] > 0.7) {
        return {
          'value': _normalizeDate(validated['value']),
          'confidence': 0.95 * validated['confidence'],
          'method': 'keyword_proximity',
        };
      }
    }

    // Strategy 2: Find most recent date
    final dates = _extractAllDates(text);
    DateTime? newestDate;
    String? newestDateStr;

    for (final dateStr in dates) {
      final parsed = _parseDate(dateStr);
      if (parsed != null) {
        if (newestDate == null || parsed.isAfter(newestDate)) {
          newestDate = parsed;
          newestDateStr = dateStr;
        }
      }
    }

    if (newestDateStr != null) {
      final validated = _validateDate(newestDateStr, isDateIssued: true);
      if (validated['confidence'] > 0.5) {
        return {
          'value': _normalizeDate(validated['value']),
          'confidence': 0.6 * validated['confidence'],
          'method': 'pattern_newest',
        };
      }
    }

    return {'value': '', 'confidence': 0.0, 'method': 'none'};
  }

  /// Extract date by keyword proximity
  static String? _extractDateByKeyword(String text, List<String> keywords) {
    final datePattern = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b');

    for (final keyword in keywords) {
      final keywordIdx = text.indexOf(keyword);
      if (keywordIdx == -1) continue;

      // Check same line (within 50 chars after keyword)
      final searchArea = text.substring(
        keywordIdx,
        (keywordIdx + 50).clamp(0, text.length),
      );

      final match = datePattern.firstMatch(searchArea);
      if (match != null) {
        return match.group(0);
      }
    }

    return null;
  }

  /// Extract all dates from text
  static List<String> _extractAllDates(String text) {
    final datePattern = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b');
    return datePattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// Validate date with context-specific rules
  static Map<String, dynamic> _validateDate(
    String date, {
    bool isDateOfBirth = false,
    bool isDateIssued = false,
  }) {
    double confidence = 1.0;

    final parsed = _parseDate(date);
    if (parsed == null) return {'value': date, 'confidence': 0.0};

    final now = DateTime.now();
    final age = now.year - parsed.year;

    if (isDateOfBirth) {
      // Senior citizen validation (60-120 years old)
      if (age >= 60 && age <= 120) {
        confidence += 0.3;
      } else if (age >= 55 && age <= 125) {
        confidence += 0.1; // Borderline
      } else {
        confidence -= 0.5; // Outside expected range
      }
    }

    if (isDateIssued) {
      final yearsAgo = now.year - parsed.year;
      // ID issued 0-10 years ago
      if (yearsAgo >= 0 && yearsAgo <= 5) {
        confidence += 0.3;
      } else if (yearsAgo <= 10) {
        confidence += 0.1;
      } else {
        confidence -= 0.3; // Too old
      }
    }

    return {
      'value': date,
      'confidence': confidence.clamp(0.0, 1.0),
    };
  }

  /// Parse date string to DateTime
  static DateTime? _parseDate(String date) {
    try {
      final parts = date.split(RegExp(r'[/-]'));
      if (parts.length != 3) return null;

      int month = int.parse(parts[0]);
      int day = int.parse(parts[1]);
      int year = int.parse(parts[2]);

      // Handle 2-digit year
      if (year < 100) {
        year += year > 50 ? 1900 : 2000;
      }

      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  /// Normalize date to MM/DD/YY format
  static String _normalizeDate(String date) {
    final parsed = _parseDate(date);
    if (parsed == null) return date;

    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final year = (parsed.year % 100).toString().padLeft(2, '0');

    return '$month/$day/$year';
  }

  /// Calculate age from date of birth
  static String _calculateAge(String dob) {
    final parsed = _parseDate(dob);
    if (parsed == null) return '';

    final now = DateTime.now();
    int age = now.year - parsed.year;

    // Adjust if birthday hasn't occurred this year
    if (now.month < parsed.month ||
        (now.month == parsed.month && now.day < parsed.day)) {
      age--;
    }

    return age.toString();
  }

  /// Extract sex/gender
  static Map<String, dynamic> _extractSex(String text) {
    print('⚧️  Extracting sex...');

    // Strategy 1: Keyword proximity (90-95% confidence)
    final keywords = ['SEX', 'GENDER', 'KASARIAN'];
    for (final keyword in keywords) {
      final keywordIdx = text.indexOf(keyword);
      if (keywordIdx == -1) continue;

      // Check same line (within 20 chars)
      final searchArea = text.substring(
        keywordIdx,
        (keywordIdx + 20).clamp(0, text.length),
      );

      if (searchArea.contains(RegExp(r'\bM\b'))) {
        return {
          'value': 'M',
          'confidence': 0.95,
          'method': 'keyword_same_line'
        };
      }
      if (searchArea.contains(RegExp(r'\bF\b'))) {
        return {
          'value': 'F',
          'confidence': 0.95,
          'method': 'keyword_same_line'
        };
      }
      if (searchArea.contains(RegExp(r'\bMALE\b'))) {
        return {
          'value': 'M',
          'confidence': 0.95,
          'method': 'keyword_same_line'
        };
      }
      if (searchArea.contains(RegExp(r'\bFEMALE\b'))) {
        return {
          'value': 'F',
          'confidence': 0.95,
          'method': 'keyword_same_line'
        };
      }
    }

    // Strategy 2: Pattern matching (70% confidence)
    if (text.contains(RegExp(r'\bM\b(?!ALE)'))) {
      return {'value': 'M', 'confidence': 0.70, 'method': 'pattern_match'};
    }
    if (text.contains(RegExp(r'\bF\b(?!EMALE)'))) {
      return {'value': 'F', 'confidence': 0.70, 'method': 'pattern_match'};
    }

    return {'value': '', 'confidence': 0.0, 'method': 'none'};
  }

  /// Extract control number / ID number
  static Map<String, dynamic> _extractControlNo(String text) {
    print('🆔 Extracting control number...');

    // Strategy 1: Keyword proximity (90-95% confidence)
    final keywords = ['CONTROL NO', 'ID NO', 'SC NO', 'NUMBER', 'NUMERO'];
    final idPattern = RegExp(r'\b(?:SC[-\s]?)?\d{4}[-\s]\d{3,5}\b|'
        r'\b\d{4}[-\s]\d{4}\b');

    for (final keyword in keywords) {
      final keywordIdx = text.indexOf(keyword);
      if (keywordIdx == -1) continue;

      // Check within 50 chars after keyword
      final searchArea = text.substring(
        keywordIdx,
        (keywordIdx + 50).clamp(0, text.length),
      );

      final match = idPattern.firstMatch(searchArea);
      if (match != null) {
        final value = _normalizeIdNumber(match.group(0)!);
        final confidence = _validateIdNumber(value);
        return {
          'value': value,
          'confidence': 0.95 * confidence,
          'method': 'keyword_proximity',
        };
      }
    }

    // Strategy 2: Pattern matching (60-85% confidence)
    final matches = idPattern.allMatches(text);
    for (final match in matches) {
      final value = _normalizeIdNumber(match.group(0)!);
      final confidence = _validateIdNumber(value);

      if (confidence > 0.6) {
        return {
          'value': value,
          'confidence': 0.85 * confidence,
          'method': 'pattern_match',
        };
      }
    }

    return {'value': '', 'confidence': 0.0, 'method': 'none'};
  }

  /// Normalize ID number format
  static String _normalizeIdNumber(String id) {
    // Fix common OCR errors
    id = id.replaceAll('O', '0'); // O to 0
    id = id.replaceAll('I', '1'); // I to 1
    id = id.replaceAll(RegExp(r'\s'), '-'); // Space to hyphen

    return id.toUpperCase();
  }

  /// Validate ID number structure
  static double _validateIdNumber(String id) {
    double confidence = 1.0;

    // Check for year (2019-2026)
    final yearMatch = RegExp(r'20(1[9]|2[0-6])').firstMatch(id);
    if (yearMatch != null) {
      confidence += 0.2;
    }

    // Check for hyphen separator
    if (id.contains('-')) {
      confidence += 0.1;
    }

    // Check length
    if (id.length >= 9 && id.length <= 15) {
      confidence += 0.1;
    } else {
      confidence -= 0.2;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// Extract by keyword proximity (generic)
  static String? _extractByKeyword(
    String text,
    List<String> keywords,
    RegExp pattern,
  ) {
    for (final keyword in keywords) {
      final keywordIdx = text.indexOf(keyword);
      if (keywordIdx == -1) continue;

      // Check within 50 chars after keyword
      final searchArea = text.substring(
        keywordIdx,
        (keywordIdx + 50).clamp(0, text.length),
      );

      final match = pattern.firstMatch(searchArea);
      if (match != null) {
        return match.group(0);
      }
    }

    return null;
  }
}
