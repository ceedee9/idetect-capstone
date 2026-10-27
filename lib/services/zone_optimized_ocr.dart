// =============================================================================
// FILE: lib/services/zone_optimized_ocr.dart
// PURPOSE: Zone-specific OCR with field-optimized PSM modes and whitelists
// ACCURACY TARGET: 97%+ (Quick Win #3)
// =============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

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

  /// Process each zone with field-optimized PSM + whitelist.
  ///
  /// [imageWidth]/[imageHeight] are informational: crops always use the real
  /// decoded size of [imagePath] so zones stay aligned even when the image was
  /// resized or warped after those dimensions were measured.
  ///
  /// Fields named in [skip] (e.g. 'name', 'controlNo') are not OCR'd.
  static Future<Map<String, String>> extractAllZones({
    required String imagePath,
    required int imageWidth,
    required int imageHeight,
    Set<String> skip = const {},
  }) async {
    debugPrint('🎯 Zone-optimized OCR starting...');

    final results = <String, String>{};

    try {
      final image = await _loadImage(imagePath, imageWidth, imageHeight);
      if (image == null) return results;

      Future<void> run(
        String key,
        ZoneConfig config, {
        List<ZoneConfig> fallbacks = const [],
        bool Function(String)? isValid,
      }) async {
        if (skip.contains(key)) return;
        results[key] = await _extractWithFallbacks(
          image,
          imagePath,
          config,
          fallbacks: fallbacks,
          isValid: isValid,
        );
      }

      // Zone positions below were re-measured on the two real sample cards
      // in assets/images (card normalized to fill the frame): the old values
      // clipped the tops of the digits and, for the name, missed its row.

      // Zone 1: Name — typed row sits on the "Name:" line (~35-42% vertical)
      await run(
        'name',
        ZoneConfig(
          top: 0.33,
          bottom: 0.43,
          left: 0.145,
          right: 0.67,
          psm: 6, // Uniform block (multiple words)
          whitelist:
              'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz -ñÑ.',
          fieldName: 'Name',
        ),
      );

      // Zone 2: DOB — digits only; stops above the "Date of Birth" label
      await run(
        'dob',
        ZoneConfig(
          top: 0.55,
          bottom: 0.645,
          left: 0.0,
          right: 0.30,
          psm: 7, // ⭐ Single text line (dates are one line!)
          whitelist: '0123456789/-',
          fieldName: 'Date_of_Birth',
        ),
      );

      // Zone 3: Sex — just the "F"/"M" between DOB and Date Issued
      await run(
        'sex',
        ZoneConfig(
          top: 0.54,
          bottom: 0.65,
          left: 0.29,
          right: 0.42,
          psm: 10, // ⭐ Single character (M or F only!)
          whitelist: 'MFmfEPNW', // Include common OCR errors: E/P→F, N/W→M
          fieldName: 'Sex',
        ),
      );

      // Zone 4: Date Issued — ends where the photo begins (~72% horizontal)
      await run(
        'dateIssued',
        ZoneConfig(
          top: 0.55,
          bottom: 0.645,
          left: 0.46,
          right: 0.74,
          psm: 7, // Single text line
          whitelist: '0123456789/-',
          fieldName: 'Date_Issued',
        ),
      );

      // Zone 5: Control No — the large red number. It is the identifier the
      // whole verification hangs on, so when the tight zone yields nothing
      // usable, retry with progressively wider zones and other
      // page-segmentation modes.
      await run(
        'controlNo',
        ZoneConfig(
          top: 0.73,
          bottom: 0.86,
          left: 0.66,
          right: 1.0,
          psm: 7, // Single text line
          whitelist: '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-',
          fieldName: 'Control_Number',
        ),
        isValid: _hasIdentifierDigits,
        fallbacks: [
          ZoneConfig(
            top: 0.70,
            bottom: 0.89,
            left: 0.55,
            right: 1.0,
            psm: 7,
            whitelist: '0123456789',
            fieldName: 'Control_Number_Wide',
          ),
          ZoneConfig(
            top: 0.70,
            bottom: 0.89,
            left: 0.55,
            right: 1.0,
            psm: 6,
            whitelist: '0123456789',
            fieldName: 'Control_Number_Block',
          ),
        ],
      );

      debugPrint('✅ Zone-optimized OCR complete!');
      debugPrint('   📊 Extracted ${results.length} fields');
    } catch (e) {
      debugPrint('❌ Zone-optimized OCR error: $e');
    }

    return results;
  }

  /// Extract zones for the REDESIGNED (2025+) Senior Citizen ID format — has
  /// a holographic seal and different field positions than the pre-2025
  /// layout (see extractAllZones for that one). Zone percentages calibrated
  /// against a real sample new-format ID (Sept 2026).
  ///
  /// Only the keys in [fields] are OCR'd (all when null): the caller can
  /// skip anything ML Kit already read confidently, which is what makes the
  /// scan fast.
  static Future<Map<String, String>> extractAllZonesNewFormat({
    required String imagePath,
    required int imageWidth,
    required int imageHeight,
    Set<String>? fields,
  }) async {
    debugPrint('🎯 Zone-optimized OCR (NEW FORMAT) starting...');

    final results = <String, String>{};

    try {
      final image = await _loadImage(imagePath, imageWidth, imageHeight);
      if (image == null) return results;

      Future<void> run(
        String key,
        ZoneConfig config, {
        List<ZoneConfig> fallbacks = const [],
        bool Function(String)? isValid,
      }) async {
        if (fields != null && !fields.contains(key)) return;
        results[key] = await _extractWithFallbacks(
          image,
          imagePath,
          config,
          fallbacks: fallbacks,
          isValid: isValid,
        );
      }

      // Name — includes the "Name:" label; same line as the value on this
      // layout, unlike the old format where the name sits above its label.
      await run(
        'name',
        ZoneConfig(
          top: 0.30,
          bottom: 0.40,
          left: 0.30,
          right: 0.95,
          psm: 7,
          whitelist:
              'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz -ñÑ.',
          fieldName: 'Name_New',
        ),
        isValid: _hasNameWords,
        fallbacks: [
          ZoneConfig(
            top: 0.28,
            bottom: 0.43,
            left: 0.25,
            right: 0.98,
            psm: 6,
            whitelist:
                'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz -ñÑ.',
            fieldName: 'Name_New_Wide',
          ),
        ],
      );

      // Address line 1 — includes the "Address:" label
      await run(
        'address',
        ZoneConfig(
          top: 0.40,
          bottom: 0.50,
          left: 0.30,
          right: 0.95,
          psm: 7,
          whitelist:
              'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 -.,',
          fieldName: 'Address_New',
        ),
      );

      // Barangay — continuation line under Address, no explicit label
      await run(
        'barangay',
        ZoneConfig(
          top: 0.49,
          bottom: 0.575,
          left: 0.30,
          right: 0.58,
          psm: 7,
          whitelist: 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz -',
          fieldName: 'Barangay_New',
        ),
      );

      // Sex — full word ("Female"/"Male"), not a single character like the
      // old format
      await run(
        'sex',
        ZoneConfig(
          top: 0.49,
          bottom: 0.585,
          left: 0.62,
          right: 0.82,
          psm: 7,
          whitelist: 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz:',
          fieldName: 'Sex_New',
        ),
      );

      // Date of Birth — narrowed to the value line only; the fuller zone
      // was pulling in the "Date of Birth" label line beneath it, which
      // PSM 7 (single-line mode) was blending into one garbled read
      await run(
        'dob',
        ZoneConfig(
          top: 0.565,
          bottom: 0.615,
          left: 0.30,
          right: 0.53,
          psm: 7,
          whitelist:
              'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789, ',
          fieldName: 'DOB_New',
        ),
        isValid: _hasMonthNameDate,
        fallbacks: [
          ZoneConfig(
            top: 0.55,
            bottom: 0.635,
            left: 0.28,
            right: 0.55,
            psm: 7,
            whitelist:
                'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789, ',
            fieldName: 'DOB_New_Wide',
          ),
        ],
      );

      // Date Issued — same fix, narrowed to exclude the "Date Issued" label
      await run(
        'dateIssued',
        ZoneConfig(
          top: 0.565,
          bottom: 0.615,
          left: 0.55,
          right: 0.75,
          psm: 7,
          whitelist:
              'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789, ',
          fieldName: 'DateIssued_New',
        ),
        isValid: _hasMonthNameDate,
        fallbacks: [
          ZoneConfig(
            top: 0.55,
            bottom: 0.635,
            left: 0.53,
            right: 0.80,
            psm: 7,
            whitelist:
                'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789, ',
            fieldName: 'DateIssued_New_Wide',
          ),
        ],
      );

      // ID No. — narrowed to the number line only; the fuller zone was
      // pulling in the "ID No." label line beneath it, and with a
      // digits-only whitelist, Tesseract couldn't reconcile the letters
      // in the label against a single numeric line, so it returned nothing.
      // Because that tight zone is unforgiving, retry wider if it fails.
      await run(
        'idNo',
        ZoneConfig(
          top: 0.78,
          bottom: 0.855,
          left: 0.0,
          right: 0.30,
          psm: 7,
          whitelist: '0123456789',
          fieldName: 'ID_No_New',
        ),
        isValid: _hasIdentifierDigits,
        fallbacks: [
          ZoneConfig(
            top: 0.75,
            bottom: 0.88,
            left: 0.0,
            right: 0.40,
            psm: 7,
            whitelist: '0123456789',
            fieldName: 'ID_No_New_Wide',
          ),
          ZoneConfig(
            top: 0.72,
            bottom: 0.90,
            left: 0.0,
            right: 0.45,
            psm: 6,
            whitelist: '0123456789',
            fieldName: 'ID_No_New_Block',
          ),
        ],
      );

      debugPrint('✅ Zone-optimized OCR (NEW FORMAT) complete!');
      debugPrint('   📊 Extracted ${results.length} fields');
    } catch (e) {
      debugPrint('❌ Zone-optimized OCR (NEW FORMAT) error: $e');
    }

    return results;
  }

  // ===========================================================================
  // VALIDATORS (decide whether a zone read is good enough to stop retrying)
  // ===========================================================================

  static bool _hasIdentifierDigits(String text) =>
      RegExp(r'\d').allMatches(text).length >= 4;

  static bool _hasNameWords(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'^\s*Name\s*:?\s*', caseSensitive: false), '')
        .trim();
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => RegExp(r'[A-Za-zñÑ]{2,}').hasMatch(w));
    return words.length >= 2;
  }

  static bool _hasMonthNameDate(String text) => RegExp(
        r'[A-Za-z]{3,9}\.?\s+\d{1,2},?\s+\d{4}',
      ).hasMatch(text);

  // ===========================================================================
  // ZONE EXTRACTION
  // ===========================================================================

  /// Decodes the zone source image once; every zone is then cropped from the
  /// in-memory copy instead of re-reading and re-decoding the whole photo.
  static Future<img.Image?> _loadImage(
    String imagePath,
    int expectedWidth,
    int expectedHeight,
  ) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      debugPrint('   ⚠️  Image file not found: $imagePath');
      return null;
    }
    final image = img.decodeImage(await file.readAsBytes());
    if (image == null) {
      debugPrint('   ⚠️  Failed to decode image');
      return null;
    }
    debugPrint('📐 Zone source: ${image.width}x${image.height} px');
    if (image.width != expectedWidth || image.height != expectedHeight) {
      debugPrint(
          '   ℹ️  Caller measured ${expectedWidth}x$expectedHeight — using '
          'the real size');
    }
    return image;
  }

  /// OCRs [config]; if the result fails [isValid], tries each fallback zone
  /// in turn. Returns the first valid read, otherwise the primary read.
  static Future<String> _extractWithFallbacks(
    img.Image image,
    String imagePath,
    ZoneConfig config, {
    List<ZoneConfig> fallbacks = const [],
    bool Function(String)? isValid,
  }) async {
    final primary = await _extractZone(image, imagePath, config);
    if (isValid == null || isValid(primary)) return primary;

    for (final fallback in fallbacks) {
      debugPrint(
          '   🔁 ${config.fieldName}: retrying as ${fallback.fieldName}');
      final retry = await _extractZone(image, imagePath, fallback);
      if (isValid(retry)) return retry;
    }
    return primary;
  }

  /// Extract text from a single zone with field-specific settings
  static Future<String> _extractZone(
    img.Image image,
    String imagePath,
    ZoneConfig config,
  ) async {
    String? zonePath;
    try {
      final x = (image.width * config.left).round().clamp(0, image.width - 1);
      final y = (image.height * config.top).round().clamp(0, image.height - 1);
      final w = (image.width * (config.right - config.left))
          .round()
          .clamp(1, image.width - x);
      final h = (image.height * (config.bottom - config.top))
          .round()
          .clamp(1, image.height - y);
      debugPrint('   📐 ${config.fieldName} crop: x=$x, y=$y, w=$w, h=$h');

      final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
      final padded = _addBorder(cropped, 10);

      zonePath = '${_workBase(imagePath)}_zone_${config.fieldName}.png';
      await File(zonePath).writeAsBytes(img.encodePng(padded, level: 1));

      final text = await FlutterTesseractOcr.extractText(
        zonePath,
        language: 'eng',
        args: {
          "psm": config.psm.toString(),
          "tessedit_char_whitelist": config.whitelist,
          "preserve_interword_spaces": "1",
          // Crops carry no DPI metadata; without this Tesseract assumes 70.
          "user_defined_dpi": "300",
        },
      );

      final cleanText = text.trim();
      debugPrint('   ${config.fieldName}: "$cleanText" (PSM ${config.psm})');
      return cleanText;
    } catch (e) {
      debugPrint('   ❌ ${config.fieldName}: Extraction error - $e');
      return '';
    } finally {
      if (zonePath != null) {
        try {
          await File(zonePath).delete();
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    }
  }

  static String _workBase(String imagePath) =>
      imagePath.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '');

  // ===========================================================================
  // IMAGE PROCESSING
  // ===========================================================================

  /// Add white border around image (helps Tesseract detect edges better)
  static img.Image _addBorder(img.Image image, int borderSize) {
    final withBorder = img.Image(
      width: image.width + (borderSize * 2),
      height: image.height + (borderSize * 2),
    );
    img.fill(withBorder, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(
      withBorder,
      image,
      dstX: borderSize,
      dstY: borderSize,
    );
    return withBorder;
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
