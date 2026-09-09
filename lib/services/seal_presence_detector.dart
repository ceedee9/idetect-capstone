// =============================================================================
// FILE: lib/services/seal_presence_detector.dart
// PURPOSE: Heuristic check for the holographic seal on new-format Senior IDs.
// NOTE: Not true anti-counterfeit hologram authentication — checks whether
// the expected zone is blue/cyan-dominant (the seal's actual foil color) and
// visually textured, as a decision aid for the human validator, not a verdict.
// Zone coordinates calibrated against one real new-format ID sample (Sept
// 2026) — recalibrate further as more real samples become available.
// =============================================================================

import 'dart:io';
import 'dart:math' show sqrt;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class SealPresenceDetector {
  // Zone calibrated from a real new-format ID sample — the seal sits in the
  // lower-right area, below/beside the Date Issued row.
  static const double _top = 0.48;
  static const double _bottom = 0.94;
  static const double _left = 0.70;
  static const double _right = 0.99;

  // Primary signal: hologram foil is blue/cyan, unlike skin tone, red ink,
  // or white card stock. Real sample measured ~+126; false-positive cases
  // (photo, control number) measured ~+7. Threshold sits well between them.
  static const double _bluenessThreshold = 40.0;

  // Secondary signal: the seal has visible texture (engraved pattern),
  // unlike a flat printed color. Guards against a uniform blue surface
  // (e.g. part of the card's blue banner) reading as a false positive.
  static const double _stdDevThreshold = 30.0;

  static Future<SealCheckResult> checkSeal({
    required String imagePath,
    required int imageWidth,
    required int imageHeight,
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

      final x = (imageWidth * _left).round().clamp(0, imageWidth - 1);
      final y = (imageHeight * _top).round().clamp(0, imageHeight - 1);
      final w =
          (imageWidth * (_right - _left)).round().clamp(1, imageWidth - x);
      final h =
          (imageHeight * (_bottom - _top)).round().clamp(1, imageHeight - y);

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
      final meanG = sumG / totalPixels;
      final meanB = sumB / totalPixels;
      final blueness = meanB - meanR;

      final meanLum = sumLum / totalPixels;
      final variance = (sumLumSquares / totalPixels) - (meanLum * meanLum);
      final stdDev = variance > 0 ? sqrt(variance) : 0.0;

      debugPrint('🔍 Seal zone stats: R=${meanR.toStringAsFixed(0)} '
          'G=${meanG.toStringAsFixed(0)} B=${meanB.toStringAsFixed(0)} '
          'blueness=${blueness.toStringAsFixed(1)} '
          'stdDev=${stdDev.toStringAsFixed(1)}');

      final looksLikeSeal =
          blueness > _bluenessThreshold && stdDev > _stdDevThreshold;

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
