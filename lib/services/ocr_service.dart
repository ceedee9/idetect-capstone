// =============================================================================
// FILE: lib/services/ocr_service.dart
// PURPOSE: Complete OCR service with preprocessing and text extraction
// ACCURACY TARGET: 95%+
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

/// OCR Service for extracting text from Senior Citizen and PWD IDs
///
/// Features:
/// - Image quality validation
/// - Automatic preprocessing
/// - Text extraction with confidence scores
/// - Support for various ID formats
class OCRService {
  // Initialize ML Kit Text Recognizer
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin, // For English/Filipino text
  );

  // Minimum confidence threshold (0.0 - 1.0)
  static const double minConfidence = 0.5; // More lenient

  // Image quality thresholds - VERY LENIENT for testing
  static const double minSharpness = 20.0; // Much more lenient
  static const int minBrightness = 20; // Allow darker images
  static const int maxBrightness = 240; // Allow brighter images

  // ===========================================================================
  // MAIN OCR PIPELINE
  // ===========================================================================

  /// Process ID image and extract text
  /// Returns OCRResult with extracted text and confidence
  Future<OCRResult> processIDImage(
    File imageFile, {
    String idType = 'senior', // 'senior' or 'pwd' - for future optimizations
  }) async {
    try {
      debugPrint('📸 Starting OCR processing for $idType ID...');

      // Step 1: Validate image quality
      final qualityCheck = await _validateImageQuality(imageFile);
      if (!qualityCheck.isValid) {
        return OCRResult(
          success: false,
          errorMessage: qualityCheck.message,
          rawText: '',
          confidence: 0.0,
        );
      }

      // Step 2: Preprocess image
      debugPrint('🔧 Preprocessing image...');
      final processedImage = await _preprocessImage(imageFile);

      // Step 3: Extract text using ML Kit
      debugPrint('🔍 Extracting text...');
      final inputImage = InputImage.fromFile(processedImage);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Step 4: Calculate confidence score
      final confidence = _calculateConfidence(recognizedText);

      // Step 5: Clean and format extracted text
      final cleanedText = _cleanExtractedText(recognizedText.text);

      debugPrint(
          '✅ OCR Complete! Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
      debugPrint('📝 Extracted Text:\n$cleanedText');

      return OCRResult(
        success: true,
        rawText: cleanedText,
        confidence: confidence,
        blocks: recognizedText.blocks,
        processedImagePath: processedImage.path,
      );
    } catch (e) {
      debugPrint('❌ OCR Error: $e');
      return OCRResult(
        success: false,
        errorMessage: 'OCR processing failed: $e',
        rawText: '',
        confidence: 0.0,
      );
    }
  }

  /// Process image WITHOUT quality validation (bypass for poor quality images)
  Future<OCRResult> processIDImageWithoutQualityCheck(
    File imageFile, {
    String idType = 'senior',
  }) async {
    try {
      debugPrint('⚠️ Processing WITHOUT quality check (forced)...');

      // Skip validation, go straight to preprocessing
      final processedImage = await _preprocessImage(imageFile);

      // Extract text
      final inputImage = InputImage.fromFile(processedImage);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final confidence = _calculateConfidence(recognizedText);
      final cleanedText = _cleanExtractedText(recognizedText.text);

      debugPrint(
          '✅ Forced OCR Complete! Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
      debugPrint('📝 Extracted Text:\n$cleanedText');

      return OCRResult(
        success: true,
        rawText: cleanedText,
        confidence:
            confidence * 0.8, // Penalize confidence for bypassing quality check
        blocks: recognizedText.blocks,
        processedImagePath: processedImage.path,
      );
    } catch (e) {
      debugPrint('❌ Forced OCR Error: $e');
      return OCRResult(
        success: false,
        errorMessage: 'Even forced processing failed: $e',
        rawText: '',
        confidence: 0.0,
      );
    }
  }

  // ===========================================================================
  // STEP 1: IMAGE QUALITY VALIDATION
  // ===========================================================================

  /// Validate if image is suitable for OCR
  Future<ImageQualityResult> _validateImageQuality(File imageFile) async {
    try {
      // Read image bytes
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        return ImageQualityResult(
          isValid: false,
          message: 'Invalid image format',
        );
      }

      // Check 1: Minimum resolution (very lenient for testing)
      if (image.width < 400 || image.height < 300) {
        return ImageQualityResult(
          isValid: false,
          message: 'Image resolution too low. Please move closer to the ID.',
        );
      }

      // Check 2: Brightness (too dark or too bright reduces OCR accuracy)
      final brightness = _calculateBrightness(image);
      if (brightness < minBrightness) {
        return ImageQualityResult(
          isValid: false,
          message:
              'Image too dark. Please use better lighting or enable flash.',
        );
      }
      if (brightness > maxBrightness) {
        return ImageQualityResult(
          isValid: false,
          message:
              'Image too bright. Reduce glare or move away from direct light.',
        );
      }

      // Check 3: Blur detection (Laplacian variance method)
      final sharpness = _calculateSharpness(image);
      if (sharpness < minSharpness) {
        return ImageQualityResult(
          isValid: false,
          message: 'Image is blurry. Hold phone steady and tap to focus.',
        );
      }

      debugPrint(
          '✅ Image Quality: Brightness=$brightness, Sharpness=$sharpness');

      return ImageQualityResult(
        isValid: true,
        message: 'Image quality good',
        brightness: brightness,
        sharpness: sharpness,
      );
    } catch (e) {
      debugPrint('❌ Quality check error: $e');
      return ImageQualityResult(
        isValid: true, // Allow processing even if quality check fails
        message: 'Quality check skipped',
      );
    }
  }

  /// Calculate average brightness (0-255)
  double _calculateBrightness(img.Image image) {
    int totalBrightness = 0;
    int pixelCount = 0;

    // Sample every 10th pixel for performance
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // Calculate perceived brightness (human eye is more sensitive to green)
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b);
        totalBrightness += brightness.toInt();
        pixelCount++;
      }
    }

    return pixelCount > 0 ? totalBrightness / pixelCount : 0;
  }

  /// Calculate sharpness using Laplacian variance (higher = sharper)
  double _calculateSharpness(img.Image image) {
    // Convert to grayscale for analysis
    final grayscale = img.grayscale(image);

    // Apply Laplacian filter to detect edges
    double variance = 0;
    int count = 0;

    // Sample center region (ID cards have text in center)
    final startX = grayscale.width ~/ 4;
    final endX = (grayscale.width * 3) ~/ 4;
    final startY = grayscale.height ~/ 4;
    final endY = (grayscale.height * 3) ~/ 4;

    for (int y = startY; y < endY - 1; y++) {
      for (int x = startX; x < endX - 1; x++) {
        final pixel = grayscale.getPixel(x, y).r.toInt();
        final rightPixel = grayscale.getPixel(x + 1, y).r.toInt();
        final bottomPixel = grayscale.getPixel(x, y + 1).r.toInt();

        final laplacian = (4 * pixel - rightPixel - bottomPixel).abs();
        variance += laplacian * laplacian;
        count++;
      }
    }

    return count > 0 ? variance / count : 0;
  }

  // ===========================================================================
  // STEP 2: IMAGE PREPROCESSING
  // ===========================================================================

  /// Preprocess image to improve OCR accuracy
  Future<File> _preprocessImage(File imageFile) async {
    try {
      // Read original image
      final bytes = await imageFile.readAsBytes();
      var image = img.decodeImage(bytes);

      if (image == null) {
        return imageFile; // Return original if preprocessing fails
      }

      // 1. Convert to grayscale (removes color noise)
      image = img.grayscale(image);

      // 2. Increase contrast (makes text stand out)
      image = img.adjustColor(
        image,
        contrast: 1.3, // Increase by 30%
        brightness: 1.1, // Slightly brighten
      );

      // 3. Apply slight sharpening (enhances edges)
      image = img.convolution(
        image,
        filter: [
          0,
          -1,
          0,
          -1,
          5,
          -1,
          0,
          -1,
          0,
        ],
      );

      // 4. Reduce noise (smoothing)
      // Skip for now to preserve text details

      // 5. Binarization (black text on white background)
      // Use Otsu's method for automatic threshold
      image = _applyOtsuThreshold(image);

      // Save processed image
      final processedPath = imageFile.path.replaceAll('.jpg', '_processed.jpg');
      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(img.encodeJpg(image, quality: 95));

      debugPrint('✅ Preprocessing complete: $processedPath');

      return processedFile;
    } catch (e) {
      debugPrint('⚠️ Preprocessing failed, using original: $e');
      return imageFile;
    }
  }

  /// Apply Otsu's thresholding for binarization
  img.Image _applyOtsuThreshold(img.Image grayscale) {
    // Calculate histogram
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < grayscale.height; y++) {
      for (int x = 0; x < grayscale.width; x++) {
        final pixel = grayscale.getPixel(x, y).r.toInt();
        histogram[pixel]++;
      }
    }

    // Calculate total pixels
    final total = grayscale.width * grayscale.height;

    // Find optimal threshold using Otsu's method
    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }

    double sumB = 0;
    int wB = 0;
    int wF = 0;
    double maxVariance = 0;
    int threshold = 0;

    for (int i = 0; i < 256; i++) {
      wB += histogram[i];
      if (wB == 0) continue;

      wF = total - wB;
      if (wF == 0) break;

      sumB += i * histogram[i];
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;

      final variance = wB * wF * (mB - mF) * (mB - mF);

      if (variance > maxVariance) {
        maxVariance = variance;
        threshold = i;
      }
    }

    // Apply threshold
    final binary = img.Image.from(grayscale);
    for (int y = 0; y < binary.height; y++) {
      for (int x = 0; x < binary.width; x++) {
        final pixel = grayscale.getPixel(x, y).r.toInt();
        final newValue = pixel > threshold ? 255 : 0;
        binary.setPixelRgba(x, y, newValue, newValue, newValue, 255);
      }
    }

    debugPrint('📊 Otsu threshold: $threshold');
    return binary;
  }

  // ===========================================================================
  // STEP 3: TEXT EXTRACTION (ML Kit handles this)
  // ===========================================================================

  // ===========================================================================
  // STEP 4: CONFIDENCE CALCULATION
  // ===========================================================================

  /// Calculate overall confidence score from recognized text
  double _calculateConfidence(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return 0.0;

    double totalConfidence = 0.0;
    int lineCount = 0;

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        // ML Kit doesn't provide confidence directly, so we estimate
        // based on factors like: text length, character variety, etc.

        // Factor 1: Line length (longer lines are usually more reliable)
        final lengthScore = (line.text.length / 20).clamp(0.0, 1.0);

        // Factor 2: Has alphanumeric characters
        final hasLetters = line.text.contains(RegExp(r'[a-zA-Z]'));
        final hasNumbers = line.text.contains(RegExp(r'[0-9]'));
        final varietyScore = (hasLetters && hasNumbers) ? 1.0 : 0.7;

        // Factor 3: Not too many special characters (might be noise)
        final specialChars = line.text.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '');
        final specialRatio = specialChars.length / line.text.length;
        final cleanScore = specialRatio < 0.3 ? 1.0 : 0.5;

        final lineConfidence = (lengthScore + varietyScore + cleanScore) / 3;
        totalConfidence += lineConfidence;
        lineCount++;
      }
    }

    return lineCount > 0 ? totalConfidence / lineCount : 0.0;
  }

  // ===========================================================================
  // STEP 5: TEXT CLEANING
  // ===========================================================================

  /// Clean extracted text (remove noise, fix common OCR errors)
  String _cleanExtractedText(String rawText) {
    String cleaned = rawText;

    // Remove excessive whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // ❌ REMOVED DESTRUCTIVE REPLACEMENTS:
    // These were replacing ALL 0s with Os and ALL 1s with Is
    // This destroyed ID numbers like "2024-0001" -> "2O24-OOO1"

    // Note: Context-aware character corrections should be done
    // in the parser service where we know if we're parsing a name vs number

    // Remove leading/trailing whitespace
    cleaned = cleaned.trim();

    return cleaned;
  }

  // ===========================================================================
  // CLEANUP
  // ===========================================================================

  /// Dispose resources
  void dispose() {
    _textRecognizer.close();
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

/// Result of OCR processing
class OCRResult {
  final bool success;
  final String rawText;
  final double confidence;
  final String? errorMessage;
  final List<TextBlock>? blocks;
  final String? processedImagePath;

  OCRResult({
    required this.success,
    required this.rawText,
    required this.confidence,
    this.errorMessage,
    this.blocks,
    this.processedImagePath,
  });

  /// Check if confidence meets minimum threshold
  bool get isConfident => confidence >= OCRService.minConfidence;

  /// Get confidence as percentage
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
}

/// Result of image quality validation
class ImageQualityResult {
  final bool isValid;
  final String message;
  final double? brightness;
  final double? sharpness;

  ImageQualityResult({
    required this.isValid,
    required this.message,
    this.brightness,
    this.sharpness,
  });
}

// =============================================================================
// USAGE EXAMPLE
// =============================================================================

/*
// In your camera screen or processing screen:

final ocrService = OCRService();

Future<void> processImage(File imageFile) async {
  // Show loading
  setState(() => isProcessing = true);

  // Process image
  final result = await ocrService.processIDImage(imageFile);

  if (result.success) {
    if (result.isConfident) {
      // High confidence - proceed to parsing
      print('✅ OCR Success: ${result.confidencePercent}');
      print('Text: ${result.rawText}');
      
      // Send to parser service
      final parsedData = await parserService.parseIDText(result.rawText);
      
    } else {
      // Low confidence - ask for manual entry or retake
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Low Confidence'),
          content: Text('Extraction quality score is ${result.confidencePercent}. Please retake photo or enter details manually.'),
          actions: [
            TextButton(
              onPressed: () => retakePhoto(),
              child: Text('Retake'),
            ),
            TextButton(
              onPressed: () => manualEntry(),
              child: Text('Enter Manually'),
            ),
          ],
        ),
      );
    }
  } else {
    // OCR failed
    showError(result.errorMessage ?? 'OCR failed');
  }

  setState(() => isProcessing = false);
}

// Don't forget to dispose
@override
void dispose() {
  ocrService.dispose();
  super.dispose();
}
*/
