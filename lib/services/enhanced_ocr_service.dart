// =============================================================================
// FILE: lib/services/enhanced_ocr_service.dart
// PURPOSE: Production-grade OCR with multiple engines and post-processing
// ENGINES: Tesseract (primary), ML Kit (fallback)
// ACCURACY TARGET: 98%+
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'advanced_image_processor.dart';

/// Enhanced OCR Service with multiple engines and intelligent post-processing
///
/// Features:
/// - Primary: Tesseract OCR (better for documents)
/// - Fallback: Google ML Kit (faster, always available)
/// - Advanced preprocessing pipeline
/// - Intelligent post-processing and error correction
/// - Context-aware text cleaning
/// - Confidence scoring
class EnhancedOCRService {
  final AdvancedImageProcessor _imageProcessor = AdvancedImageProcessor();
  final TextRecognizer _mlKitRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  // ===========================================================================
  // MAIN OCR PIPELINE
  // ===========================================================================

  /// Process ID image with best possible accuracy
  Future<EnhancedOCRResult> processIDImage({
    required File imageFile,
    required String idType,
  }) async {
    try {
      debugPrint('🚀 Starting Enhanced OCR Pipeline...');
      debugPrint('📋 ID Type: $idType');
      debugPrint('📁 Image: ${imageFile.path}');

      // Verify file exists
      if (!await imageFile.exists()) {
        return EnhancedOCRResult(
          success: false,
          errorMessage: 'Image file not found',
          rawText: '',
          confidence: 0.0,
        );
      }

      // STEP 1: Advanced Image Preprocessing
      debugPrint('🔬 Step 1/5: Advanced preprocessing...');
      File? processedFile;

      try {
        final processedResult = await _imageProcessor.processImage(
          imageFile: imageFile,
          idType: idType,
        );

        if (!processedResult.success) {
          debugPrint(
              '⚠️ Preprocessing failed, using original image: ${processedResult.errorMessage}');
          processedFile = imageFile; // Fallback to original
        } else {
          processedFile = processedResult.processedFile!;
          debugPrint('✅ Preprocessing successful');
        }
      } catch (e) {
        debugPrint('⚠️ Preprocessing exception: $e, using original image');
        processedFile = imageFile; // Fallback to original
      }

      // STEP 2: OCR with Tesseract (Primary Engine)
      debugPrint('🔍 Step 2/5: OCR with Tesseract...');
      String? tesseractText;
      double tesseractConfidence = 0.0;

      try {
        tesseractText = await FlutterTesseractOcr.extractText(
          processedFile.path,
          language: 'eng', // English
          args: {
            "psm": "6", // Assume uniform block of text
            "preserve_interword_spaces": "1",
          },
        );

        if (tesseractText.isNotEmpty) {
          tesseractConfidence = _estimateTesseractConfidence(tesseractText);
          debugPrint('✅ Tesseract extracted ${tesseractText.length} chars');
          debugPrint(
              '📊 Tesseract confidence: ${(tesseractConfidence * 100).toInt()}%');
        } else {
          debugPrint('⚠️ Tesseract returned empty text');
        }
      } catch (e) {
        debugPrint('⚠️ Tesseract failed: $e');
      }

      // STEP 3: OCR with ML Kit (Fallback Engine)
      debugPrint('🔍 Step 3/5: OCR with ML Kit (fallback)...');
      String? mlkitText;
      double mlkitConfidence = 0.0;

      try {
        final inputImage = InputImage.fromFile(processedFile);
        final recognizedText = await _mlKitRecognizer.processImage(inputImage);

        if (recognizedText.text.isNotEmpty) {
          mlkitText = recognizedText.text;
          mlkitConfidence = _calculateMLKitConfidence(recognizedText);
          debugPrint('✅ ML Kit extracted ${mlkitText.length} chars');
          debugPrint(
              '📊 ML Kit confidence: ${(mlkitConfidence * 100).toInt()}%');
        } else {
          debugPrint('⚠️ ML Kit returned empty text');
        }
      } catch (e) {
        debugPrint('⚠️ ML Kit failed: $e');
      }

      // STEP 4: Choose Best Result
      debugPrint('🎯 Step 4/5: Selecting best result...');
      String rawText;
      double confidence;
      String engine;

      if (tesseractText != null && tesseractConfidence >= mlkitConfidence) {
        rawText = tesseractText;
        confidence = tesseractConfidence;
        engine = 'Tesseract';
      } else if (mlkitText != null) {
        rawText = mlkitText;
        confidence = mlkitConfidence;
        engine = 'ML Kit';
      } else {
        return EnhancedOCRResult(
          success: false,
          errorMessage: 'Both OCR engines failed to extract text',
          rawText: '',
          confidence: 0.0,
        );
      }

      debugPrint(
          '🏆 Selected: $engine (confidence: ${(confidence * 100).toInt()}%)');

      // STEP 5: Post-Processing
      debugPrint('🧹 Step 5/5: Post-processing and error correction...');
      final cleanedText = _postProcessText(rawText, idType);
      final finalConfidence = _calculateFinalConfidence(
        cleanedText,
        confidence,
        idType,
      );

      debugPrint('✅ OCR Complete!');
      debugPrint('📝 Final confidence: ${(finalConfidence * 100).toInt()}%');
      debugPrint('=== EXTRACTED TEXT ===');
      debugPrint(cleanedText);
      debugPrint('======================');

      return EnhancedOCRResult(
        success: true,
        rawText: cleanedText,
        confidence: finalConfidence,
        engine: engine,
        processedImagePath: processedFile.path,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Enhanced OCR Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return EnhancedOCRResult(
        success: false,
        errorMessage: 'OCR processing failed: $e',
        rawText: '',
        confidence: 0.0,
      );
    }
  }

  // ===========================================================================
  // FIELD-SPECIFIC OCR (QUICK WIN #2: CHARACTER WHITELIST)
  // ===========================================================================

  /// Extract text from image with field-specific character whitelist
  /// This dramatically improves accuracy by limiting possible characters
  static Future<String> extractFieldWithWhitelist(
    String imagePath,
    String fieldType, {
    int? psm,
  }) async {
    final whitelist = _getWhitelistForField(fieldType);
    final psmMode = psm ?? _getPsmForField(fieldType);

    debugPrint('🎯 Extracting $fieldType with whitelist PSM $psmMode');
    debugPrint(
        '   Allowed chars: ${whitelist.substring(0, whitelist.length > 50 ? 50 : whitelist.length)}...');

    try {
      final text = await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'eng',
        args: {
          "psm": psmMode.toString(),
          "tessedit_char_whitelist": whitelist,
          "preserve_interword_spaces": "1",
        },
      );

      debugPrint('   ✅ Extracted: "${text.trim()}"');
      return text.trim();
    } catch (e) {
      debugPrint('   ❌ Whitelist extraction failed: $e');
      return '';
    }
  }

  /// Get character whitelist for specific field type
  static String _getWhitelistForField(String fieldType) {
    switch (fieldType.toLowerCase()) {
      case 'name':
      case 'fullname':
      case 'full_name':
        // Letters, spaces, hyphen, Filipino ñ, period for abbreviations
        return 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz -ñÑ.';

      case 'date':
      case 'dob':
      case 'date_of_birth':
      case 'dateofbirth':
      case 'date_issued':
      case 'dateissued':
        // Numbers and date separators only
        return '0123456789/-';

      case 'sex':
      case 'gender':
        // Only M and F (no other letters!)
        return 'MFmf';

      case 'controlno':
      case 'control_no':
      case 'control_number':
      case 'controlnumber':
        // Alphanumeric + hyphen
        return '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-';

      case 'address':
        // Full alphanumeric with common punctuation
        return 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 -.,#ñÑ';

      case 'number':
      case 'numeric':
        // Numbers only
        return '0123456789';

      default:
        // Full alphabet + numbers + common punctuation
        return 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 -/.,#ñÑ';
    }
  }

  /// Get optimal PSM mode for specific field type (QUICK WIN #3)
  static int _getPsmForField(String fieldType) {
    switch (fieldType.toLowerCase()) {
      case 'name':
      case 'fullname':
      case 'full_name':
      case 'address':
        return 6; // Uniform block (multiple words)

      case 'date':
      case 'dob':
      case 'date_of_birth':
      case 'dateofbirth':
      case 'date_issued':
      case 'dateissued':
      case 'controlno':
      case 'control_no':
      case 'control_number':
      case 'controlnumber':
        return 7; // Single text line

      case 'sex':
      case 'gender':
        return 10; // Single character

      default:
        return 6; // Uniform block (default)
    }
  }

  // ===========================================================================
  // CONFIDENCE ESTIMATION
  // ===========================================================================

  /// Estimate Tesseract confidence from output quality
  double _estimateTesseractConfidence(String text) {
    double score = 0.5; // Base score

    // Factor 1: Text length (reasonable IDs have 100-500 chars)
    if (text.length >= 100 && text.length <= 1000) {
      score += 0.2;
    }

    // Factor 2: Has letters and numbers
    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(text);
    final hasNumbers = RegExp(r'[0-9]').hasMatch(text);
    if (hasLetters && hasNumbers) score += 0.15;

    // Factor 3: Not too many special characters
    final specialChars = text.replaceAll(RegExp(r'[a-zA-Z0-9\s\n\-:,./]'), '');
    final specialRatio = specialChars.length / text.length;
    if (specialRatio < 0.1) score += 0.15;

    return score.clamp(0.0, 1.0);
  }

  /// Calculate ML Kit confidence from recognized text
  double _calculateMLKitConfidence(dynamic recognizedText) {
    if (recognizedText.blocks.isEmpty) return 0.0;

    double totalScore = 0.0;
    int lineCount = 0;

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final length = line.text.length;
        final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(line.text);
        final hasNumbers = RegExp(r'[0-9]').hasMatch(line.text);

        double score = 0.5;
        if (length >= 5) score += 0.2;
        if (hasLetters) score += 0.15;
        if (hasNumbers) score += 0.15;

        totalScore += score;
        lineCount++;
      }
    }

    return lineCount > 0 ? (totalScore / lineCount).clamp(0.0, 1.0) : 0.0;
  }

  /// Calculate final confidence after post-processing
  double _calculateFinalConfidence(
      String text, double baseConfidence, String idType) {
    double bonus = 0.0;

    // Bonus for ID-specific keywords
    final lower = text.toLowerCase();
    if (idType == 'senior') {
      if (lower.contains('senior') || lower.contains('citizen')) bonus += 0.1;
      if (lower.contains('osca')) bonus += 0.05;
    } else {
      if (lower.contains('pwd') || lower.contains('disability')) bonus += 0.1;
      if (lower.contains('pdao')) bonus += 0.05;
    }

    // Bonus for expected fields
    if (RegExp(r'\b[A-Z][a-z]+ [A-Z][a-z]+').hasMatch(text))
      bonus += 0.05; // Name
    if (RegExp(r'\d{2,4}-\d{4}').hasMatch(text)) bonus += 0.05; // ID number
    if (RegExp(r'\d{1,2}/\d{1,2}/\d{2,4}').hasMatch(text))
      bonus += 0.05; // Date

    return (baseConfidence + bonus).clamp(0.0, 1.0);
  }

  // ===========================================================================
  // POST-PROCESSING & ERROR CORRECTION
  // ===========================================================================

  /// Post-process and clean extracted text
  String _postProcessText(String rawText, String idType) {
    String text = rawText;

    // 1. Fix common OCR errors
    text = _fixCommonOCRErrors(text);

    // 2. Fix line breaks and spacing
    text = _fixLineBreaks(text);

    // 3. Fix dates
    text = _fixDates(text);

    // 4. Fix ID numbers
    text = _fixIDNumbers(text);

    // 5. Fix names (title case)
    text = _fixNames(text);

    // 6. Remove noise
    text = _removeNoise(text);

    return text.trim();
  }

  /// Fix common OCR character misreads
  String _fixCommonOCRErrors(String text) {
    // Only fix in specific contexts, not globally

    // Fix in date contexts (0 vs O)
    text = text.replaceAllMapped(
      RegExp(r'(\d{1,2}[/-])O(\d|\d[/-])'),
      (match) => '${match.group(1)}0${match.group(2)}',
    );

    // Fix in number contexts (1 vs I)
    text = text.replaceAllMapped(
      RegExp(r'(\d)I(\d)'),
      (match) => '${match.group(1)}1${match.group(2)}',
    );

    // Fix common character confusions
    text = text.replaceAll('|', 'I'); // Vertical bar -> I
    text = text.replaceAll('!', '1'); // Exclamation -> 1 in numeric context

    return text;
  }

  /// Fix line breaks and spacing
  String _fixLineBreaks(String text) {
    // Remove excessive blank lines
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Fix broken words across lines
    text = text.replaceAll(RegExp(r'-\n'), '');

    // Normalize spaces
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');

    // Trim each line
    final lines = text.split('\n').map((line) => line.trim()).toList();

    return lines.join('\n');
  }

  /// Fix dates to standard format
  String _fixDates(String text) {
    // Fix common date format issues
    text = text.replaceAllMapped(
      RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})'),
      (match) {
        final month = match.group(1)!.padLeft(2, '0');
        final day = match.group(2)!.padLeft(2, '0');
        var year = match.group(3)!;

        // Convert 2-digit year to 4-digit
        if (year.length == 2) {
          final yearNum = int.tryParse(year) ?? 0;
          year = yearNum > 50 ? '19$year' : '20$year';
        }

        return '$month/$day/$year';
      },
    );

    return text;
  }

  /// Fix ID number formats
  String _fixIDNumbers(String text) {
    // Ensure ID numbers have proper format (e.g., 2024-0001)
    text = text.replaceAllMapped(
      RegExp(r'(\d{2,4})\s*[-–—]\s*(\d{4})'),
      (match) => '${match.group(1)}-${match.group(2)}',
    );

    return text;
  }

  /// Fix names to proper title case
  String _fixNames(String text) {
    // Find potential names (2-4 capitalized words in sequence)
    text = text.replaceAllMapped(
      RegExp(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,3})\b'),
      (match) {
        final name = match.group(1)!;
        // Ensure proper title case
        return name.split(' ').map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }).join(' ');
      },
    );

    return text;
  }

  /// Remove noise and artifacts
  String _removeNoise(String text) {
    // Remove single character lines (likely noise)
    final lines = text.split('\n');
    final cleaned = lines.where((line) {
      final trimmed = line.trim();
      // Keep line if it's longer than 2 chars or is a number/letter
      return trimmed.length > 2 || RegExp(r'^[A-Z0-9]$').hasMatch(trimmed);
    }).toList();

    text = cleaned.join('\n');

    // Remove repeated special characters
    text = text.replaceAll(RegExp(r'([^\w\s])\1{2,}'), '');

    // Remove lines with too many special characters (noise)
    final finalLines = text.split('\n').where((line) {
      if (line.trim().isEmpty) return false;
      final specialCount = line.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '').length;
      return specialCount < line.length * 0.5;
    }).toList();

    return finalLines.join('\n');
  }

  // ===========================================================================
  // LAYOUT-BASED EXTRACTION (NEW!)
  // ===========================================================================

  /// Extract text WITH positional information (bounding boxes)
  /// This enables layout-based field extraction for higher accuracy
  Future<RecognizedText?> extractTextWithPositions(File imageFile) async {
    try {
      debugPrint('📍 Extracting text with positions using ML Kit...');

      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _mlKitRecognizer.processImage(inputImage);

      debugPrint(
          '✅ Extracted ${recognizedText.blocks.length} text blocks with positions');
      debugPrint(
          '   Total lines: ${recognizedText.blocks.fold(0, (sum, block) => sum + block.lines.length)}');

      return recognizedText;
    } catch (e) {
      debugPrint('❌ Position-based extraction failed: $e');
      return null;
    }
  }

  /// Get image dimensions for layout-based extraction
  Future<Map<String, int>?> getImageDimensions(File imageFile) async {
    try {
      debugPrint('📐 Getting image dimensions...');

      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        debugPrint('❌ Failed to decode image');
        return null;
      }

      final dimensions = {
        'width': image.width,
        'height': image.height,
      };

      debugPrint(
          '✅ Image size: ${dimensions['width']}x${dimensions['height']} pixels');
      return dimensions;
    } catch (e) {
      debugPrint('❌ Failed to get image dimensions: $e');
      return null;
    }
  }

  // ===========================================================================
  // CLEANUP
  // ===========================================================================

  void dispose() {
    _mlKitRecognizer.close();
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

class EnhancedOCRResult {
  final bool success;
  final String rawText;
  final double confidence;
  final String? engine;
  final String? processedImagePath;
  final String? errorMessage;

  EnhancedOCRResult({
    required this.success,
    required this.rawText,
    required this.confidence,
    this.engine,
    this.processedImagePath,
    this.errorMessage,
  });

  bool get isConfident => confidence >= 0.7;
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
}
