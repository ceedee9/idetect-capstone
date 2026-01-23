// =============================================================================
// FILE: lib/services/zone_optimized_ocr.dart
// PURPOSE: Zone-specific OCR with field-optimized PSM modes and whitelists
// ACCURACY TARGET: 97%+ (Quick Win #3)
// =============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import 'enhanced_ocr_service.dart';

/// Zone-Optimized OCR Service
///
/// Processes each zone with field-specific optimizations:
/// - Different PSM modes per field (6 for names, 7 for dates, 10 for single char)
/// - Character whitelists to eliminate impossible characters
/// - White border padding to improve Tesseract accuracy
/// - Precise zone cropping based on ID layout
class ZoneOptimizedOCR {
  // ===========================================================================
  // MAIN EXTRACTION METHOD
  // ===========================================================================

  /// Process each zone with field-optimized PSM + whitelist
  static Future<Map<String, String>> extractAllZones({
    required String imagePath,
    required int imageWidth,
    required int imageHeight,
  }) async {
    debugPrint('🎯 Zone-optimized OCR starting...');
    debugPrint('📐 Image: ${imageWidth}x$imageHeight px');

    final results = <String, String>{};

    try {
      // Zone 1: Name - text appears ABOVE the "Name:" label (24-38% vertical)
      results['name'] = await _extractZone(
        imagePath,
        imageWidth,
        imageHeight,
        ZoneConfig(
          top: 0.24,
          bottom: 0.38,
          left: 0.08,
          right: 0.65,
          psm: 6, // Uniform block (multiple words)
          whitelist:
              'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz -ñÑ.',
          fieldName: 'Name',
        ),
      );

      // Zone 2: DOB (58-72% vertical, 0-30% horizontal - LEFT COLUMN)
      results['dob'] = await _extractZone(
        imagePath,
        imageWidth,
        imageHeight,
        ZoneConfig(
          top: 0.58,
          bottom: 0.72,
          left: 0.0,
          right: 0.30,
          psm: 7, // ⭐ Single text line (dates are one line!)
          whitelist: '0123456789/-',
          fieldName: 'Date_of_Birth',
        ),
      );

      // Zone 3: Sex (58-68% vertical, 32-48% horizontal - NARROW to get just the character)
      // The "F" or "M" appears between DOB and Date Issued, above the "Sex" label
      results['sex'] = await _extractZone(
        imagePath,
        imageWidth,
        imageHeight,
        ZoneConfig(
          top: 0.56,
          bottom: 0.66,
          left: 0.32,
          right: 0.48,
          psm: 10, // ⭐ Single character (M or F only!)
          whitelist: 'MFmfEPNW', // Include common OCR errors: E/P→F, N/W→M
          fieldName: 'Sex',
        ),
      );

      // Zone 4: Date Issued (58-72% vertical, 55-95% horizontal - RIGHT COLUMN)
      results['dateIssued'] = await _extractZone(
        imagePath,
        imageWidth,
        imageHeight,
        ZoneConfig(
          top: 0.58,
          bottom: 0.72,
          left: 0.55,
          right: 0.95,
          psm: 7, // Single text line
          whitelist: '0123456789/-',
          fieldName: 'Date_Issued',
        ),
      );

      // Zone 5: Control No (75-85% vertical, 65-100% horizontal)
      results['controlNo'] = await _extractZone(
        imagePath,
        imageWidth,
        imageHeight,
        ZoneConfig(
          top: 0.75,
          bottom: 0.85,
          left: 0.65,
          right: 1.0,
          psm: 7, // Single text line
          whitelist: '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-',
          fieldName: 'Control_Number',
        ),
      );

      debugPrint('✅ Zone-optimized OCR complete!');
      debugPrint('   📊 Extracted ${results.length} fields');
    } catch (e) {
      debugPrint('❌ Zone-optimized OCR error: $e');
    }

    return results;
  }

  // ===========================================================================
  // ZONE EXTRACTION
  // ===========================================================================

  /// Extract text from a single zone with field-specific settings
  static Future<String> _extractZone(
    String imagePath,
    int width,
    int height,
    ZoneConfig config,
  ) async {
    try {
      // 1. Crop to zone
      final croppedPath = await _cropImageToZone(
        imagePath,
        width,
        height,
        config,
      );

      if (croppedPath == null) {
        debugPrint('   ⚠️  ${config.fieldName}: Cropping failed');
        return '';
      }

      // 2. Add white border (helps Tesseract detect edges)
      final borderedPath = await _addBorder(croppedPath, 10);

      // 3. OCR with zone-specific settings
      final text = await FlutterTesseractOcr.extractText(
        borderedPath,
        language: 'eng',
        args: {
          "psm": config.psm.toString(),
          "tessedit_char_whitelist": config.whitelist,
          "preserve_interword_spaces": "1",
        },
      );

      final cleanText = text.trim();
      debugPrint('   ${config.fieldName}: "$cleanText" (PSM ${config.psm})');

      // Clean up temporary files
      try {
        await File(croppedPath).delete();
        await File(borderedPath).delete();
      } catch (e) {
        // Ignore cleanup errors
      }

      return cleanText;
    } catch (e) {
      debugPrint('   ❌ ${config.fieldName}: Extraction error - $e');
      return '';
    }
  }

  // ===========================================================================
  // IMAGE PROCESSING
  // ===========================================================================

  /// Crop image to specific zone
  static Future<String?> _cropImageToZone(
    String imagePath,
    int width,
    int height,
    ZoneConfig config,
  ) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('   ⚠️  Image file not found: $imagePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        debugPrint('   ⚠️  Failed to decode image');
        return null;
      }

      // Calculate crop coordinates
      final x = (width * config.left).round().clamp(0, width - 1);
      final y = (height * config.top).round().clamp(0, height - 1);
      final w =
          (width * (config.right - config.left)).round().clamp(1, width - x);
      final h =
          (height * (config.bottom - config.top)).round().clamp(1, height - y);

      debugPrint('   📐 Crop: x=$x, y=$y, w=$w, h=$h');

      // Crop the image
      final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);

      // Save to temporary file
      final outputPath = imagePath.replaceAll(
        '.jpg',
        '_zone_${config.fieldName}.jpg',
      );
      await File(outputPath).writeAsBytes(img.encodeJpg(cropped, quality: 95));

      return outputPath;
    } catch (e) {
      debugPrint('   ❌ Cropping error: $e');
      return null;
    }
  }

  /// Add white border around image (helps Tesseract detect edges better)
  static Future<String> _addBorder(String imagePath, int borderSize) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        return imagePath; // Return original if decode fails
      }

      // Create new image with border
      final newWidth = image.width + (borderSize * 2);
      final newHeight = image.height + (borderSize * 2);

      // Create white canvas
      final withBorder = img.Image(width: newWidth, height: newHeight);
      img.fill(withBorder, color: img.ColorRgb8(255, 255, 255));

      // Copy original image to center
      img.compositeImage(
        withBorder,
        image,
        dstX: borderSize,
        dstY: borderSize,
      );

      // Save to temporary file
      final outputPath = imagePath.replaceAll('.jpg', '_bordered.jpg');
      await File(outputPath)
          .writeAsBytes(img.encodeJpg(withBorder, quality: 95));

      return outputPath;
    } catch (e) {
      debugPrint('   ⚠️  Border addition failed: $e, using original');
      return imagePath;
    }
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

/// Configuration for a specific zone
class ZoneConfig {
  /// Top boundary (percentage of image height: 0.0 to 1.0)
  final double top;

  /// Bottom boundary (percentage of image height: 0.0 to 1.0)
  final double bottom;

  /// Left boundary (percentage of image width: 0.0 to 1.0)
  final double left;

  /// Right boundary (percentage of image width: 0.0 to 1.0)
  final double right;

  /// PSM mode (6=block, 7=line, 10=single char)
  final int psm;

  /// Character whitelist
  final String whitelist;

  /// Field name (for debugging)
  final String fieldName;

  ZoneConfig({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
    required this.psm,
    required this.whitelist,
    required this.fieldName,
  });
}
