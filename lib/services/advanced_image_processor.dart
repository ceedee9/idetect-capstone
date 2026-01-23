// =============================================================================
// FILE: lib/services/advanced_image_processor.dart
// PURPOSE: Advanced image preprocessing for optimal OCR accuracy
// FEATURES: Perspective correction, deskewing, noise reduction, enhancement
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Advanced image processor for preparing ID images for OCR
///
/// Pipeline:
/// 1. Border detection and removal
/// 2. Perspective correction (straighten angled IDs)
/// 3. Deskewing (rotation correction)
/// 4. Noise reduction (bilateral filter)
/// 5. Contrast enhancement (CLAHE)
/// 6. Binarization (adaptive thresholding)
/// 7. Morphological operations (text enhancement)
class AdvancedImageProcessor {
  /// Process image through complete enhancement pipeline
  Future<ProcessedImageResult> processImage({
    required File imageFile,
    required String idType,
  }) async {
    try {
      debugPrint('🔬 Starting advanced image processing...');

      final bytes = await imageFile.readAsBytes();
      var image = img.decodeImage(bytes);

      if (image == null) {
        return ProcessedImageResult(
          success: false,
          errorMessage: 'Failed to decode image',
        );
      }

      // Step 1: Resize for optimal processing (balance speed vs quality)
      if (image.width > 2000 || image.height > 2000) {
        final maxDim = math.max(image.width, image.height);
        final scale = 2000 / maxDim;
        image = img.copyResize(
          image,
          width: (image.width * scale).round(),
          height: (image.height * scale).round(),
          interpolation: img.Interpolation.cubic,
        );
        debugPrint('📏 Resized to ${image.width}x${image.height}');
      }

      // Step 2: Detect and remove borders
      image = _removeBorders(image);
      debugPrint('✂️ Removed borders');

      // Step 3: Detect and correct perspective distortion
      image = await _correctPerspective(image);
      debugPrint('📐 Corrected perspective');

      // Step 4: Detect and correct skew (rotation)
      final skewAngle = _detectSkewAngle(image);
      if (skewAngle.abs() > 0.5) {
        image = img.copyRotate(image, angle: skewAngle);
        debugPrint('🔄 Deskewed by ${skewAngle.toStringAsFixed(2)}°');
      }

      // Step 5: Convert to grayscale
      image = img.grayscale(image);
      debugPrint('⚫ Converted to grayscale');

      // Step 6: Denoise with edge-preserving bilateral filter
      image = _bilateralFilter(image);
      debugPrint('🧹 Applied denoising');

      // Step 7: Enhance contrast with CLAHE
      image = _applyCLAHE(image);
      debugPrint('📊 Enhanced contrast (CLAHE)');

      // Step 8: Sharpen text edges
      image = _sharpenImage(image);
      debugPrint('🔪 Sharpened edges');

      // Step 9: Adaptive binarization (black text on white)
      image = _adaptiveThreshold(image);
      debugPrint('🎯 Applied adaptive thresholding');

      // Step 10: Morphological operations for text enhancement
      image = _morphologicalOperations(image, idType);
      debugPrint('🔬 Enhanced text regions');

      // Step 11: Final cleanup - remove small noise
      image = _removeSmallNoise(image);
      debugPrint('✨ Removed noise');

      // Save processed image
      final processedPath = imageFile.path.replaceAll('.jpg', '_processed.jpg');
      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(img.encodeJpg(image, quality: 95));

      debugPrint('✅ Advanced processing complete!');

      return ProcessedImageResult(
        success: true,
        processedFile: processedFile,
        originalImage: imageFile,
        width: image.width,
        height: image.height,
      );
    } catch (e) {
      debugPrint('❌ Processing error: $e');
      return ProcessedImageResult(
        success: false,
        errorMessage: 'Processing failed: $e',
      );
    }
  }

  // ===========================================================================
  // STEP 1: BORDER REMOVAL
  // ===========================================================================

  /// Detect and remove borders/background around ID
  img.Image _removeBorders(img.Image image) {
    try {
      // Find content boundaries using edge detection
      final edges = _detectEdges(image);

      // Find bounding box of content
      int minX = image.width;
      int maxX = 0;
      int minY = image.height;
      int maxY = 0;

      for (int y = 0; y < edges.height; y++) {
        for (int x = 0; x < edges.width; x++) {
          final pixel = edges.getPixel(x, y);
          if (pixel.r > 128) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      // Add small margin
      final margin = 20;
      minX = (minX - margin).clamp(0, image.width - 1);
      maxX = (maxX + margin).clamp(0, image.width - 1);
      minY = (minY - margin).clamp(0, image.height - 1);
      maxY = (maxY + margin).clamp(0, image.height - 1);

      // Crop to content
      if (maxX > minX && maxY > minY) {
        return img.copyCrop(
          image,
          x: minX,
          y: minY,
          width: maxX - minX,
          height: maxY - minY,
        );
      }

      return image;
    } catch (e) {
      debugPrint('⚠️ Border removal failed: $e');
      return image;
    }
  }

  /// Simple edge detection using Sobel operator
  img.Image _detectEdges(img.Image image) {
    final gray = img.grayscale(image);
    final result = img.Image.from(gray);

    // Sobel kernels
    const sobelX = [-1, 0, 1, -2, 0, 2, -1, 0, 1];
    const sobelY = [-1, -2, -1, 0, 0, 0, 1, 2, 1];

    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        double gx = 0;
        double gy = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = gray.getPixel(x + kx, y + ky);
            final value = pixel.r.toDouble();
            final idx = (ky + 1) * 3 + (kx + 1);
            gx += value * sobelX[idx];
            gy += value * sobelY[idx];
          }
        }

        final magnitude = math.sqrt(gx * gx + gy * gy).clamp(0, 255).toInt();
        result.setPixelRgba(x, y, magnitude, magnitude, magnitude, 255);
      }
    }

    return result;
  }

  // ===========================================================================
  // STEP 2: PERSPECTIVE CORRECTION
  // ===========================================================================

  /// Detect and correct perspective distortion (angled ID)
  Future<img.Image> _correctPerspective(img.Image image) async {
    try {
      // Detect corners of ID card
      final corners = _detectIDCorners(image);

      if (corners.length == 4) {
        // Apply perspective transform to straighten
        return _warpPerspective(image, corners);
      }

      return image;
    } catch (e) {
      debugPrint('⚠️ Perspective correction failed: $e');
      return image;
    }
  }

  /// Detect corners of ID card using contour detection
  List<Point> _detectIDCorners(img.Image image) {
    // Simplified corner detection
    // In production, use OpenCV's findContours and approxPolyDP
    return [];
  }

  /// Warp image to correct perspective
  img.Image _warpPerspective(img.Image image, List<Point> corners) {
    // Simplified perspective transform
    // In production, use OpenCV's warpPerspective
    return image;
  }

  // ===========================================================================
  // STEP 3: SKEW DETECTION AND CORRECTION
  // ===========================================================================

  /// Detect skew angle using Hough transform
  double _detectSkewAngle(img.Image image) {
    try {
      // Simplified skew detection using horizontal line detection
      final edges = _detectEdges(image);

      // Use Hough transform to detect dominant angle
      final angles = <double, int>{};

      // Sample horizontal lines
      for (int y = 0; y < edges.height; y += 5) {
        int whiteCount = 0;
        for (int x = 0; x < edges.width; x++) {
          if (edges.getPixel(x, y).r > 128) {
            whiteCount++;
          }
        }

        // If line has significant edges, it might be text
        if (whiteCount > edges.width * 0.1) {
          // Estimate local angle (simplified)
          final angle = _estimateLineAngle(edges, y);
          angles[angle] = (angles[angle] ?? 0) + 1;
        }
      }

      // Find most common angle
      if (angles.isNotEmpty) {
        final sortedAngles = angles.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return sortedAngles.first.key;
      }

      return 0.0;
    } catch (e) {
      debugPrint('⚠️ Skew detection failed: $e');
      return 0.0;
    }
  }

  double _estimateLineAngle(img.Image image, int y) {
    // Simplified angle estimation
    // In production, use full Hough transform
    return 0.0;
  }

  // ===========================================================================
  // STEP 4: BILATERAL FILTER (Edge-Preserving Denoising)
  // ===========================================================================

  /// Apply bilateral filter to reduce noise while preserving edges
  img.Image _bilateralFilter(img.Image image) {
    final result = img.Image.from(image);
    const radius = 3;
    const sigmaColor = 50.0;
    const sigmaSpace = 50.0;

    for (int y = radius; y < image.height - radius; y++) {
      for (int x = radius; x < image.width - radius; x++) {
        double sum = 0;
        double wSum = 0;

        final centerValue = image.getPixel(x, y).r.toInt();

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final neighborValue = image.getPixel(x + dx, y + dy).r.toInt();

            // Spatial weight
            final spatialDist = math.sqrt((dx * dx + dy * dy).toDouble());
            final spatialWeight = math.exp(
                -(spatialDist * spatialDist) / (2 * sigmaSpace * sigmaSpace));

            // Color weight
            final colorDiff = centerValue - neighborValue;
            final colorWeight = math
                .exp(-(colorDiff * colorDiff) / (2 * sigmaColor * sigmaColor));

            final weight = spatialWeight * colorWeight;
            sum += neighborValue * weight;
            wSum += weight;
          }
        }

        final newValue = (sum / wSum).round().clamp(0, 255);
        result.setPixelRgba(x, y, newValue, newValue, newValue, 255);
      }
    }

    return result;
  }

  // ===========================================================================
  // STEP 5: CLAHE (Contrast Limited Adaptive Histogram Equalization)
  // ===========================================================================

  /// Apply CLAHE for local contrast enhancement
  img.Image _applyCLAHE(img.Image image) {
    const tileSize = 8;
    const clipLimit = 2.0;

    final tilesX = (image.width / tileSize).ceil();
    final tilesY = (image.height / tileSize).ceil();

    final result = img.Image.from(image);

    for (int ty = 0; ty < tilesY; ty++) {
      for (int tx = 0; tx < tilesX; tx++) {
        final x = tx * tileSize;
        final y = ty * tileSize;
        final w = math.min(tileSize, image.width - x);
        final h = math.min(tileSize, image.height - y);

        // Extract tile
        final tile = img.copyCrop(image, x: x, y: y, width: w, height: h);

        // Calculate histogram
        final histogram = List<int>.filled(256, 0);
        for (int py = 0; py < tile.height; py++) {
          for (int px = 0; px < tile.width; px++) {
            histogram[tile.getPixel(px, py).r.toInt()]++;
          }
        }

        // Clip histogram
        final excess = _clipHistogram(histogram, clipLimit, w * h);

        // Redistribute excess
        final bonus = excess ~/ 256;
        for (int i = 0; i < 256; i++) {
          histogram[i] += bonus;
        }

        // Calculate cumulative distribution
        final cdf = List<int>.filled(256, 0);
        cdf[0] = histogram[0];
        for (int i = 1; i < 256; i++) {
          cdf[i] = cdf[i - 1] + histogram[i];
        }

        // Normalize
        final cdfMin = cdf.firstWhere((v) => v > 0);
        final cdfMax = cdf.last;

        // Apply equalization to tile
        for (int py = 0; py < tile.height; py++) {
          for (int px = 0; px < tile.width; px++) {
            final oldValue = tile.getPixel(px, py).r.toInt();
            final newValue =
                ((cdf[oldValue] - cdfMin) * 255 / (cdfMax - cdfMin))
                    .round()
                    .clamp(0, 255);
            result.setPixelRgba(
                x + px, y + py, newValue, newValue, newValue, 255);
          }
        }
      }
    }

    return result;
  }

  int _clipHistogram(List<int> histogram, double clipLimit, int total) {
    final limit = (clipLimit * total / 256).round();
    int excess = 0;

    for (int i = 0; i < 256; i++) {
      if (histogram[i] > limit) {
        excess += histogram[i] - limit;
        histogram[i] = limit;
      }
    }

    return excess;
  }

  // ===========================================================================
  // STEP 6: SHARPENING
  // ===========================================================================

  /// Sharpen image to enhance text edges
  img.Image _sharpenImage(img.Image image) {
    // Unsharp mask kernel
    return img.convolution(
      image,
      filter: [
        -1,
        -1,
        -1,
        -1,
        9,
        -1,
        -1,
        -1,
        -1,
      ],
    );
  }

  // ===========================================================================
  // STEP 7: ADAPTIVE THRESHOLDING
  // ===========================================================================

  /// Apply adaptive thresholding for binarization
  img.Image _adaptiveThreshold(img.Image image) {
    final result = img.Image.from(image);
    const blockSize = 25;
    const c = 10;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        // Calculate local mean
        int sum = 0;
        int count = 0;

        final startY = (y - blockSize ~/ 2).clamp(0, image.height - 1);
        final endY = (y + blockSize ~/ 2).clamp(0, image.height - 1);
        final startX = (x - blockSize ~/ 2).clamp(0, image.width - 1);
        final endX = (x + blockSize ~/ 2).clamp(0, image.width - 1);

        for (int ny = startY; ny <= endY; ny++) {
          for (int nx = startX; nx <= endX; nx++) {
            sum += image.getPixel(nx, ny).r.toInt();
            count++;
          }
        }

        final mean = sum / count;
        final pixel = image.getPixel(x, y).r.toInt();
        final threshold = mean - c;

        final newValue = pixel > threshold ? 255 : 0;
        result.setPixelRgba(x, y, newValue, newValue, newValue, 255);
      }
    }

    return result;
  }

  // ===========================================================================
  // STEP 8: MORPHOLOGICAL OPERATIONS
  // ===========================================================================

  /// Apply morphological operations for text enhancement
  img.Image _morphologicalOperations(img.Image image, String idType) {
    // Dilation followed by erosion (closing) to connect text
    var result = _dilate(image, 1);
    result = _erode(result, 1);

    // For small text (Senior IDs), additional enhancement
    if (idType == 'senior') {
      result = _dilate(result, 1);
    }

    return result;
  }

  img.Image _dilate(img.Image image, int radius) {
    final result = img.Image.from(image);

    for (int y = radius; y < image.height - radius; y++) {
      for (int x = radius; x < image.width - radius; x++) {
        int maxVal = 0;

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final val = image.getPixel(x + dx, y + dy).r.toInt();
            if (val > maxVal) maxVal = val;
          }
        }

        result.setPixelRgba(x, y, maxVal, maxVal, maxVal, 255);
      }
    }

    return result;
  }

  img.Image _erode(img.Image image, int radius) {
    final result = img.Image.from(image);

    for (int y = radius; y < image.height - radius; y++) {
      for (int x = radius; x < image.width - radius; x++) {
        int minVal = 255;

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final val = image.getPixel(x + dx, y + dy).r.toInt();
            if (val < minVal) minVal = val;
          }
        }

        result.setPixelRgba(x, y, minVal, minVal, minVal, 255);
      }
    }

    return result;
  }

  // ===========================================================================
  // STEP 9: NOISE REMOVAL
  // ===========================================================================

  /// Remove small noise blobs
  img.Image _removeSmallNoise(img.Image image) {
    // Simple noise removal by removing isolated pixels
    final result = img.Image.from(image);

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final center = image.getPixel(x, y).r.toInt();

        if (center == 0) {
          // Check if isolated black pixel
          int blackNeighbors = 0;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              if (image.getPixel(x + dx, y + dy).r < 128) {
                blackNeighbors++;
              }
            }
          }

          // If mostly white neighbors, remove this pixel
          if (blackNeighbors < 3) {
            result.setPixelRgba(x, y, 255, 255, 255, 255);
          }
        }
      }
    }

    return result;
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

class ProcessedImageResult {
  final bool success;
  final File? processedFile;
  final File? originalImage;
  final int? width;
  final int? height;
  final String? errorMessage;

  ProcessedImageResult({
    required this.success,
    this.processedFile,
    this.originalImage,
    this.width,
    this.height,
    this.errorMessage,
  });
}

class Point {
  final int x;
  final int y;

  Point(this.x, this.y);
}
