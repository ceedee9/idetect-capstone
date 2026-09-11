// =============================================================================
// FILE: lib/services/seal_presence_detector.dart
// PURPOSE: Heuristic check for the holographic seal on new-format Senior and
// PWD IDs. NOTE: Not true anti-counterfeit hologram authentication — checks
// whether the expected zone matches the visual signature of that card type's
// hologram, as a decision aid for the human validator, not a verdict.
//
// Senior and PWD cards need DIFFERENT detection logic, not just different
// zone coordinates: Senior's old format has a white background, so hologram
// "blueness" cleanly separates seal from no-seal. PWD's card design (both
// old and new) is blue throughout, so blueness doesn't discriminate at all —
// the old card's plain blue background actually reads MORE blue than the
// new card's real hologram. For PWD, texture (stdDev) is the signal that
// actually separates them: the hologram's swirl pattern has far more
// brightness variance than the old card's flat printed color.
//
// Calibrated against real photos (Sept 2026):
//   Senior — old: blueness=-3.4, stdDev=38.2 | new (real seal): blueness=108.0, stdDev=53.8
//   PWD    — old: blueness=78.5, stdDev=32.6 | new (real seal): blueness=60.9, stdDev=78.3
// =============================================================================

import 'dart:io';
import 'dart:math' show sqrt;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class SealPresenceDetector {
  static Future<SealCheckResult> checkSeal({
    required String imagePath,
    required int imageWidth,
    required int imageHeight,
    required String beneficiaryType, // 'senior' or 'pwd'
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return SealCheckResult.unavailable('Image file not found');
      }

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        return SealCheckResult.unavailable('Failed to decode image');
      }

      final config = _configFor(beneficiaryType);

      final x = (imageWidth * config.left).round().clamp(0, imageWidth - 1);
      final y = (imageHeight * config.top).round().clamp(0, imageHeight - 1);
      final w = (imageWidth * (config.right - config.left))
          .round()
          .clamp(1, imageWidth - x);
      final h = (imageHeight * (config.bottom - config.top))
          .round()
          .clamp(1, imageHeight - y);

      final zone = img.copyCrop(image, x: x, y: y, width: w, height: h);

      double sumR = 0, sumG = 0, sumB = 0;
      double sumLum = 0, sumLumSquares = 0;
      final totalPixels = zone.width * zone.height;

      for (final pixel in zone) {
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        sumR += r;
        sumG += g;
        sumB += b;
        final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        sumLum += luminance;
        sumLumSquares += luminance * luminance;
      }

      final meanR = sumR / totalPixels;
      final meanB = sumB / totalPixels;
      final blueness = meanB - meanR;

      final meanLum = sumLum / totalPixels;
      final variance = (sumLumSquares / totalPixels) - (meanLum * meanLum);
      final stdDev = variance > 0 ? sqrt(variance) : 0.0;

      debugPrint('🔍 Seal zone stats ($beneficiaryType): '
          'blueness=${blueness.toStringAsFixed(1)} '
          'stdDev=${stdDev.toStringAsFixed(1)}');

      final passesStdDev = stdDev > config.stdDevThreshold;
      final passesBlueness = config.bluenessThreshold == null ||
          blueness > config.bluenessThreshold!;
      final looksLikeSeal = passesStdDev && passesBlueness;

      return SealCheckResult(
        sealDetected: looksLikeSeal,
        blueness: blueness,
        stdDevLuminance: stdDev,
      );
    } catch (e) {
      debugPrint('❌ Seal check error: $e');
      return SealCheckResult.unavailable('Error: $e');
    }
  }

  static _SealZoneConfig _configFor(String beneficiaryType) {
    if (beneficiaryType.toLowerCase() == 'pwd') return _pwdConfig;
    return _seniorConfig; // default — matches existing calibrated behavior
  }

  // Unchanged from the originally calibrated Senior detector.
  static const _seniorConfig = _SealZoneConfig(
    top: 0.48,
    bottom: 0.94,
    left: 0.70,
    right: 0.99,
    bluenessThreshold: 40.0,
    stdDevThreshold: 30.0,
  );

  // PWD's card background is blue throughout, so blueness alone can't
  // discriminate — texture (stdDev) does the real work here.
  static const _pwdConfig = _SealZoneConfig(
    top: 0.60,
    bottom: 0.85,
    left: 0.75,
    right: 1.0,
    bluenessThreshold: null, // not used as a gate for PWD
    stdDevThreshold: 55.0,
  );
}

class _SealZoneConfig {
  final double top;
  final double bottom;
  final double left;
  final double right;
  final double? bluenessThreshold; // null = don't gate on blueness
  final double stdDevThreshold;

  const _SealZoneConfig({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
    required this.bluenessThreshold,
    required this.stdDevThreshold,
  });
}

class SealCheckResult {
  final bool? sealDetected; // null = couldn't be determined
  final double? blueness;
  final double? stdDevLuminance;
  final String? unavailableReason;

  SealCheckResult({
    this.sealDetected,
    this.blueness,
    this.stdDevLuminance,
    this.unavailableReason,
  });

  factory SealCheckResult.unavailable(String reason) =>
      SealCheckResult(sealDetected: null, unavailableReason: reason);
}
