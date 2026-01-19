// =============================================================================
// FILE: lib/services/parser_service.dart
// PURPOSE: Parse raw OCR text into structured ID data
// HANDLES: Variable ID formats, fuzzy matching, pattern recognition
// =============================================================================

import 'package:flutter/material.dart';
import 'senior_citizen_field_extractor.dart';

/// Parser Service for extracting structured data from OCR text
///
/// Features:
/// - Automatic ID type detection (Senior Citizen vs PWD)
/// - Pattern matching for names, ID numbers, dates
/// - Fuzzy matching for error tolerance
/// - Handles multiple ID format variations
class ParserService {
  // ===========================================================================
  // REGEX PATTERNS FOR DATA EXTRACTION
  // ===========================================================================

  // ID Type Detection Keywords
  static final seniorKeywords = [
    'senior',
    'senior citizen',
    'senior id',
    'osca',
    'office of senior',
  ];

  static final pwdKeywords = [
    'pwd',
    'person with disability',
    'disability',
    'pdao',
    'persons with',
  ];

  // ID Number Patterns (various formats)
  static final idNumberPatterns = [
    RegExp(r'\b\d{2}-\d{4}\b'), // Format: 00-0001
    RegExp(r'\b\d{4}-\d{4}\b'), // Format: 2024-0001
    RegExp(r'\bSC-\d{4}-\d{4}\b', caseSensitive: false), // Format: SC-2024-0001
    RegExp(r'\bPWD-\d{4}-\d{4}\b',
        caseSensitive: false), // Format: PWD-2024-0001
    RegExp(r'\b\d{8,12}\b'), // Format: 12345678901
  ];

  // Date Patterns (multiple formats)
  static final datePatterns = [
    RegExp(
        r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b'), // DD/MM/YYYY or MM/DD/YYYY
    RegExp(r'\b(\d{2,4})[/-](\d{1,2})[/-](\d{1,2})\b'), // YYYY/MM/DD
  ];

  // Name Patterns
  static final namePattern = RegExp(
    r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\b',
  );

  // ===========================================================================
  // MAIN PARSING FUNCTION
  // ===========================================================================

  /// Parse raw OCR text into structured ID data
  Future<ParsedIDData> parseIDText(String rawText) async {
    debugPrint('🔍 Parsing OCR text...');
    debugPrint('Raw text length: ${rawText.length} characters');

    try {
      // Step 1: Detect ID type
      final idType = _detectIDType(rawText);
      debugPrint('📋 Detected ID Type: $idType');

      // Use specialized parser for Senior Citizen ID if detected
      if (idType == IDType.seniorCitizen) {
        return await _parseSeniorCitizenID(rawText);
      }

      // Step 2: Extract ID number
      final idNumber = _extractIDNumber(rawText);
      debugPrint('🔢 ID Number: $idNumber');

      // Step 3: Extract name
      final fullName = _extractName(rawText);
      debugPrint('👤 Name: $fullName');

      // Step 4: Extract dates
      final dateIssued =
          _extractDate(rawText, ['issued', 'date issued', 'petsa']);
      debugPrint('📅 Date Issued: $dateIssued');

      // Step 5: Extract age
      final age = _extractAge(rawText);
      debugPrint('🎂 Age: $age');

      // Step 6: Extract sex
      final sex = _extractSex(rawText);
      debugPrint('⚧ Sex: $sex');

      // Step 7: Extract control number (if present)
      final controlNumber = _extractControlNumber(rawText);
      debugPrint('🎫 Control Number: $controlNumber');

      // Step 8: Calculate confidence score
      final confidence = _calculateParsingConfidence(
        idType: idType,
        idNumber: idNumber,
        fullName: fullName,
        age: age,
        sex: sex,
      );

      debugPrint(
          '✅ Parsing complete! Confidence: ${(confidence * 100).toStringAsFixed(1)}%');

      return ParsedIDData(
        success: true,
        idType: idType,
        idNumber: idNumber,
        fullName: fullName,
        age: age,
        sex: sex,
        dateIssued: dateIssued,
        controlNumber: controlNumber,
        confidence: confidence,
        rawText: rawText,
      );
    } catch (e) {
      debugPrint('❌ Parsing error: $e');
      return ParsedIDData(
        success: false,
        errorMessage: 'Failed to parse ID data: $e',
        rawText: rawText,
      );
    }
  }

  // ===========================================================================
  // SPECIALIZED SENIOR CITIZEN ID PARSER
  // ===========================================================================

  /// Parse Senior Citizen ID with known layout structure
  /// Uses specialized field extractor with fuzzy matching and Filipino name database
  Future<ParsedIDData> _parseSeniorCitizenID(String rawText) async {
    debugPrint(
        '🎯 Using specialized Senior Citizen ID parser with field extractor');

    try {
      // Use the specialized field extractor
      final extractedFields =
          SeniorCitizenFieldExtractor.extractFields(rawText);

      // Extract values and confidences
      final fullName = extractedFields['fullName']?['value'] ?? '';
      final sex = extractedFields['sex']?['value'] ?? '';
      final dateIssued = extractedFields['dateIssued']?['value'] ?? '';
      final controlNumber = extractedFields['controlNo']?['value'] ?? '';
      final age = extractedFields['age'];

      // Per-field confidences
      final nameConfidence =
          (extractedFields['fullName']?['confidence'] ?? 0.0) as double;
      final dobConfidence =
          (extractedFields['dateOfBirth']?['confidence'] ?? 0.0) as double;
      final sexConfidence =
          (extractedFields['sex']?['confidence'] ?? 0.0) as double;
      final dateIssuedConfidence =
          (extractedFields['dateIssued']?['confidence'] ?? 0.0) as double;
      final controlNoConfidence =
          (extractedFields['controlNo']?['confidence'] ?? 0.0) as double;
      final overallConfidence = extractedFields['confidence'] as double;

      // Try to extract ID number (not handled by field extractor yet)
      final idNumber = _extractIDNumber(rawText);
      final idNumberConfidence = idNumber != null ? 0.8 : 0.0;

      // Convert age to int if available
      int? ageInt;
      if (age != null && age.isNotEmpty) {
        ageInt = int.tryParse(age);
      }

      debugPrint('📊 Field Extraction Complete:');
      debugPrint(
          '   Overall Confidence: ${(overallConfidence * 100).toStringAsFixed(1)}%');

      return ParsedIDData(
        success: true,
        idType: IDType.seniorCitizen,
        idNumber: idNumber,
        fullName: fullName.isNotEmpty ? fullName : null,
        age: ageInt,
        sex: sex.isNotEmpty ? sex : null,
        dateIssued: dateIssued.isNotEmpty ? dateIssued : null,
        controlNumber: controlNumber.isNotEmpty ? controlNumber : null,
        confidence: overallConfidence,
        rawText: rawText,
        nameConfidence: nameConfidence,
        idNumberConfidence: idNumberConfidence,
        ageConfidence: dobConfidence, // Age confidence tied to DOB
        sexConfidence: sexConfidence,
        dateIssuedConfidence: dateIssuedConfidence,
        controlNumberConfidence: controlNoConfidence,
      );
    } catch (e) {
      debugPrint('❌ Specialized parser failed: $e');
      return ParsedIDData(
        success: false,
        errorMessage: 'Failed to parse Senior Citizen ID: $e',
        rawText: rawText,
      );
    }
  }

  /// Check if a line looks like a name
  bool _looksLikeName(String line) {
    // Name should have at least 2 words, all capitalized or title case
    final words = line.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length < 2) return false;

    // Check if mostly letters
    final letterCount = line.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
    return letterCount > line.length * 0.7;
  }

  /// Check if line contains date pattern
  bool _containsDatePattern(String line) {
    for (final pattern in datePatterns) {
      if (pattern.hasMatch(line)) return true;
    }
    return false;
  }

  /// Calculate age from date of birth
  int? _calculateAgeFromDOB(String dob) {
    try {
      // Try to parse date
      final parts = dob.split(RegExp(r'[/-]'));
      if (parts.length != 3) return null;

      int year, month, day;

      // Try different formats
      if (parts[0].length == 4) {
        // YYYY-MM-DD
        year = int.parse(parts[0]);
        month = int.parse(parts[1]);
        day = int.parse(parts[2]);
      } else {
        // DD/MM/YYYY or MM/DD/YYYY (assume DD/MM/YYYY for Philippines)
        day = int.parse(parts[0]);
        month = int.parse(parts[1]);
        year = int.parse(parts[2]);

        // Handle 2-digit year
        if (year < 100) {
          year += year < 50 ? 2000 : 1900;
        }
      }

      final birthDate = DateTime(year, month, day);
      final now = DateTime.now();
      int age = now.year - birthDate.year;

      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }

      return age > 0 && age < 150 ? age : null;
    } catch (e) {
      debugPrint('⚠️ Failed to calculate age from DOB: $e');
      return null;
    }
  }

  // ===========================================================================
  // STEP 1: ID TYPE DETECTION
  // ===========================================================================

  /// Detect if ID is Senior Citizen or PWD
  IDType _detectIDType(String text) {
    final lowerText = text.toLowerCase();

    // Count keyword matches
    int seniorMatches = 0;
    int pwdMatches = 0;

    for (final keyword in seniorKeywords) {
      if (lowerText.contains(keyword)) {
        seniorMatches++;
      }
    }

    for (final keyword in pwdKeywords) {
      if (lowerText.contains(keyword)) {
        pwdMatches++;
      }
    }

    // Also check ID number prefixes
    if (lowerText.contains(RegExp(r'\bsc-\d', caseSensitive: false))) {
      seniorMatches += 2;
    }
    if (lowerText.contains(RegExp(r'\bpwd-\d', caseSensitive: false))) {
      pwdMatches += 2;
    }

    if (pwdMatches > seniorMatches) {
      return IDType.pwd;
    } else if (seniorMatches > 0) {
      return IDType.seniorCitizen;
    } else {
      return IDType.unknown;
    }
  }

  // ===========================================================================
  // STEP 2: ID NUMBER EXTRACTION
  // ===========================================================================

  /// Extract ID number from text
  String? _extractIDNumber(String text) {
    // Try each pattern in order of specificity
    for (final pattern in idNumberPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }

    // Fallback: Look for "ID" or "NUMBER" keywords followed by digits
    final fallbackPattern = RegExp(
      r'(?:id|number|no\.?|control)\s*:?\s*([0-9-]+)',
      caseSensitive: false,
    );
    final match = fallbackPattern.firstMatch(text);
    if (match != null) {
      return match.group(1);
    }

    return null;
  }

  // ===========================================================================
  // STEP 3: NAME EXTRACTION
  // ===========================================================================

  /// Extract full name from text
  String? _extractName(String text) {
    // Look for "NAME" or "PANGALAN" keyword
    final nameWithLabel = RegExp(
      r'(?:name|pangalan|fullname)\s*:?\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)',
      caseSensitive: false,
    );
    final labelMatch = nameWithLabel.firstMatch(text);
    if (labelMatch != null) {
      return _cleanName(labelMatch.group(1) ?? '');
    }

    // Fallback: Find longest capitalized sequence (likely a name)
    final allMatches = namePattern.allMatches(text);
    String? longestName;
    int maxLength = 0;

    for (final match in allMatches) {
      final name = match.group(0) ?? '';
      if (name.length > maxLength && _isValidName(name)) {
        longestName = name;
        maxLength = name.length;
      }
    }

    return longestName != null ? _cleanName(longestName) : null;
  }

  /// Clean and validate name
  String _cleanName(String name) {
    // Remove common OCR errors
    name = name.replaceAll(RegExp(r'[^a-zA-Z\s]'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    name = name.trim();

    // Title case
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Check if string looks like a valid name
  bool _isValidName(String name) {
    final words = name.split(' ');

    // Should have at least 2 words (first and last name)
    if (words.length < 2) return false;

    // Each word should be reasonable length
    for (final word in words) {
      if (word.length < 2 || word.length > 20) return false;
    }

    // Should not contain common non-name words
    final nonNameWords = [
      'republic',
      'philippines',
      'valenzuela',
      'city',
      'office',
      'government',
    ];
    for (final nonName in nonNameWords) {
      if (name.toLowerCase().contains(nonName)) return false;
    }

    return true;
  }

  // ===========================================================================
  // STEP 4: DATE EXTRACTION
  // ===========================================================================

  /// Extract date from text (looks for keyword context)
  String? _extractDate(String text, List<String> keywords) {
    final lowerText = text.toLowerCase();

    // Find position of keyword
    int keywordPos = -1;
    for (final keyword in keywords) {
      keywordPos = lowerText.indexOf(keyword);
      if (keywordPos != -1) break;
    }

    if (keywordPos == -1) {
      // No keyword found, try to find any date
      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          return _formatDate(match.group(0) ?? '');
        }
      }
      return null;
    }

    // Look for date near keyword (within 50 characters)
    final searchText = text.substring(
      keywordPos,
      (keywordPos + 50).clamp(0, text.length),
    );

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(searchText);
      if (match != null) {
        return _formatDate(match.group(0) ?? '');
      }
    }

    return null;
  }

  /// Format date to consistent format (MM/DD/YYYY)
  String _formatDate(String date) {
    // Remove any separators
    final numbers = date.replaceAll(RegExp(r'[^0-9]'), ' ').split(' ');
    final parts = numbers.where((s) => s.isNotEmpty).toList();

    if (parts.length < 3) return date; // Return as-is if can't parse

    // Assume format based on number lengths
    String month, day, year;

    if (parts[0].length == 4) {
      // YYYY-MM-DD format
      year = parts[0];
      month = parts[1].padLeft(2, '0');
      day = parts[2].padLeft(2, '0');
    } else {
      // MM-DD-YYYY or DD-MM-YYYY format (ambiguous)
      month = parts[0].padLeft(2, '0');
      day = parts[1].padLeft(2, '0');
      year = parts[2];

      // Convert 2-digit year to 4-digit
      if (year.length == 2) {
        final yearNum = int.tryParse(year) ?? 0;
        year = yearNum > 50 ? '19$year' : '20$year';
      }
    }

    return '$month/$day/$year';
  }

  // ===========================================================================
  // STEP 5: AGE EXTRACTION
  // ===========================================================================

  /// Extract age from text
  int? _extractAge(String text) {
    // Look for "AGE" or "EDAD" keyword
    final agePattern = RegExp(
      r'(?:age|edad|years\s+old)\s*:?\s*(\d{1,3})',
      caseSensitive: false,
    );
    final match = agePattern.firstMatch(text);
    if (match != null) {
      final age = int.tryParse(match.group(1) ?? '');
      if (age != null && age >= 18 && age <= 120) {
        return age;
      }
    }

    // Fallback: Look for any 2-digit number that could be age
    final numbers = RegExp(r'\b([6-9]\d|1[0-1]\d)\b').allMatches(text);
    for (final match in numbers) {
      final age = int.tryParse(match.group(0) ?? '');
      if (age != null && age >= 60 && age <= 120) {
        return age; // Likely age for senior citizen
      }
    }

    return null;
  }

  // ===========================================================================
  // STEP 6: SEX/GENDER EXTRACTION
  // ===========================================================================

  /// Extract sex/gender from text
  String? _extractSex(String text) {
    final lowerText = text.toLowerCase();

    // Look for "SEX" or "KASARIAN" keyword
    final sexPattern = RegExp(
      r'(?:sex|gender|kasarian)\s*:?\s*(male|female|m|f|lalaki|babae)',
      caseSensitive: false,
    );
    final match = sexPattern.firstMatch(lowerText);
    if (match != null) {
      final sex = match.group(1)?.toLowerCase() ?? '';
      if (sex.startsWith('m') || sex == 'lalaki') return 'Male';
      if (sex.startsWith('f') || sex == 'babae') return 'Female';
    }

    // Fallback: Look for standalone M or F
    if (lowerText.contains(RegExp(r'\bm\b'))) return 'Male';
    if (lowerText.contains(RegExp(r'\bf\b'))) return 'Female';

    return null;
  }

  // ===========================================================================
  // STEP 7: CONTROL NUMBER EXTRACTION
  // ===========================================================================

  /// Extract control number (if present on ID)
  String? _extractControlNumber(String text) {
    final controlPattern = RegExp(
      r'(?:control|ctrl)\s*(?:id|number|no\.?)?\s*:?\s*([0-9]+)',
      caseSensitive: false,
    );
    final match = controlPattern.firstMatch(text);
    return match?.group(1);
  }

  // ===========================================================================
  // STEP 8: CONFIDENCE CALCULATION
  // ===========================================================================

  /// Calculate parsing confidence based on extracted data
  double _calculateParsingConfidence({
    required IDType? idType,
    required String? idNumber,
    required String? fullName,
    required int? age,
    required String? sex,
  }) {
    double confidence = 0.0;

    // ID Type detected: +20%
    if (idType != null && idType != IDType.unknown) {
      confidence += 0.20;
    }

    // ID Number extracted: +30% (most critical)
    if (idNumber != null && idNumber.isNotEmpty) {
      confidence += 0.30;
    }

    // Name extracted: +25%
    if (fullName != null && fullName.split(' ').length >= 2) {
      confidence += 0.25;
    }

    // Age extracted: +15%
    if (age != null) {
      confidence += 0.15;
    }

    // Sex extracted: +10%
    if (sex != null) {
      confidence += 0.10;
    }

    return confidence.clamp(0.0, 1.0);
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

/// ID Type enumeration
enum IDType {
  seniorCitizen,
  pwd,
  unknown,
}

/// Parsed ID data result
class ParsedIDData {
  final bool success;
  final IDType? idType;
  final String? idNumber;
  final String? fullName;
  final int? age;
  final String? sex;
  final String? dateIssued;
  final String? controlNumber;
  final double confidence;
  final String? errorMessage;
  final String rawText;

  // Per-field confidence scores
  final double nameConfidence;
  final double idNumberConfidence;
  final double ageConfidence;
  final double sexConfidence;
  final double dateIssuedConfidence;
  final double controlNumberConfidence;

  // NEW: Extraction metadata for hybrid approach
  final String? extractionMethod; // 'layout-only', 'fuzzy-only', 'hybrid'
  final bool? templateMatched; // Did layout template validation pass?

  ParsedIDData({
    required this.success,
    this.idType,
    this.idNumber,
    this.fullName,
    this.age,
    this.sex,
    this.dateIssued,
    this.controlNumber,
    this.confidence = 0.0,
    this.errorMessage,
    this.rawText = '',
    this.nameConfidence = 0.0,
    this.idNumberConfidence = 0.0,
    this.ageConfidence = 0.0,
    this.sexConfidence = 0.0,
    this.dateIssuedConfidence = 0.0,
    this.controlNumberConfidence = 0.0,
    this.extractionMethod,
    this.templateMatched,
  });

  /// Check if all critical fields are present
  bool get hasAllCriticalFields {
    return idType != null &&
        idType != IDType.unknown &&
        idNumber != null &&
        fullName != null;
  }

  /// Get confidence as percentage
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Convert to readable string
  @override
  String toString() {
    return '''
ParsedIDData:
  Type: ${idType?.name ?? 'Unknown'}
  ID Number: ${idNumber ?? 'N/A'}
  Name: ${fullName ?? 'N/A'}
  Age: ${age ?? 'N/A'}
  Sex: ${sex ?? 'N/A'}
  Date Issued: ${dateIssued ?? 'N/A'}
  Control #: ${controlNumber ?? 'N/A'}
  Confidence: $confidencePercent
''';
  }
}

// =============================================================================
// USAGE EXAMPLE
// =============================================================================

/*
final parserService = ParserService();

// After OCR extraction:
final ocrResult = await ocrService.processIDImage(imageFile);

if (ocrResult.success) {
  // Parse the raw text
  final parsedData = await parserService.parseIDText(ocrResult.rawText);
  
  if (parsedData.success && parsedData.hasAllCriticalFields) {
    // All critical data extracted successfully
    print('✅ Parsing successful!');
    print(parsedData);
    
    // Proceed to verification
    final verificationResult = await verificationService.verify(parsedData);
    
  } else {
    // Missing critical fields - ask user to confirm/correct
    showManualCorrectionDialog(parsedData);
  }
}
*/
