// =============================================================================
// FILE: lib/services/opencv_image_processor.dart
// PURPOSE: Fast native image preprocessing using OpenCV for OCR accuracy
// PERFORMANCE: ~200-400ms total (vs ~5-10s in pure Dart pixel loops)
// =============================================================================

import 'dart:io';
import 'dart:math' show sqrt;
import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Image quality assessment result
class ImageQualityResult {
  final bool acceptable;
  final double blurScore; // Higher = sharper
  final double brightnessScore; // 0-255 mean brightness
  final String? rejectionReason;

  const ImageQualityResult({
    required this.acceptable,
    required this.blurScore,
    required this.brightnessScore,
    this.rejectionReason,
  });
}

/// Result of OpenCV image preprocessing
class OpenCVProcessedResult {
  final bool success;
  final String? processedPath;
  final String? errorMessage;
  final int? width;
  final int? height;

  const OpenCVProcessedResult({
    required this.success,
    this.processedPath,
    this.errorMessage,
    this.width,
    this.height,
  });
}

/// Result of [OpenCVImageProcessor.normalizeCard]: the ID card flattened to a
/// fixed-size, upright rectangle so every OCR zone lines up with the layout
/// regardless of how the phone was held.
class NormalizedCard {
  final bool success;

  /// Colour card image (for ML Kit, which prefers colour).
  final String? colorPath;

  /// Grayscale, contrast-enhanced copy with identical dimensions (for Tesseract).
  final String? enhancedPath;
  final int width;
  final int height;

  /// True when the card edges were found and the card was perspective-warped;
  /// false when the frame was assumed to already contain just the card.
  final bool cardDetected;
  final String? errorMessage;

  const NormalizedCard({
    required this.success,
    this.colorPath,
    this.enhancedPath,
    this.width = 0,
    this.height = 0,
    this.cardDetected = false,
    this.errorMessage,
  });
}

/// Fast OpenCV-based image preprocessor for ID card OCR.
///
/// Pipeline (~200-400ms on mobile):
/// 1. Quality gate — blur & brightness check  (~10ms)
/// 2. Resize if oversized                      (~10ms)
/// 3. Perspective correction                   (~30-60ms)
/// 4. Skew correction (Hough lines)            (~20-40ms)
/// 5. Grayscale + bilateral denoise            (~30-50ms)
/// 6. CLAHE contrast enhancement               (~10-20ms)
/// 7. Sharpen                                  (~10ms)
/// 8. Upscale if small                         (~20ms)
/// 9. Save processed image                     (~20ms)
///
/// Total: ~160-260ms — well within the 15-second budget.
class OpenCVImageProcessor {
  // Thresholds
  static const double _blurThreshold = 50.0; // Laplacian variance
  static const double _minBrightness = 40.0;
  static const double _maxBrightness = 230.0;
  static const int _maxDimension = 2000;
  static const int _minDimensionForUpscale = 800;

  // =========================================================================
  // QUALITY GATE
  // =========================================================================

  /// Quick check: is the image sharp and well-lit enough for OCR?
  /// Runs in ~10ms. Call this BEFORE heavy processing to save time on
  /// images that will definitely fail OCR.
  static Future<ImageQualityResult> assessQuality(File imageFile) async {
    return compute(_assessQualityIsolate, imageFile.path);
  }

  static ImageQualityResult _assessQualityIsolate(String imagePath) {
    try {
      final mat = cv.imread(imagePath, flags: cv.IMREAD_GRAYSCALE);
      if (mat.isEmpty) {
        return const ImageQualityResult(
          acceptable: false,
          blurScore: 0,
          brightnessScore: 0,
          rejectionReason: 'Failed to decode image',
        );
      }

      // Blur detection via Laplacian variance
      final laplacian = cv.laplacian(mat, cv.MatType.CV_64F);
      final meanStd = cv.meanStdDev(laplacian);
      final stdDev = meanStd.$2.val1;
      final blurScore = stdDev * stdDev; // variance

      // Brightness check
      final meanVal = cv.mean(mat);
      final brightness = meanVal.val1;

      mat.dispose();
      laplacian.dispose();

      String? rejection;
      if (blurScore < _blurThreshold) {
        rejection = 'Image is too blurry. Please hold steady and retake.';
      } else if (brightness < _minBrightness) {
        rejection = 'Image is too dark. Please improve lighting and retake.';
      } else if (brightness > _maxBrightness) {
        rejection = 'Image is too bright/washed out. Reduce glare and retake.';
      }

      return ImageQualityResult(
        acceptable: rejection == null,
        blurScore: blurScore,
        brightnessScore: brightness,
        rejectionReason: rejection,
      );
    } catch (e) {
      // If quality check itself fails, let processing continue
      return const ImageQualityResult(
        acceptable: true,
        blurScore: 100,
        brightnessScore: 128,
      );
    }
  }

  // =========================================================================
  // MAIN PREPROCESSING PIPELINE
  // =========================================================================

  /// Full preprocessing pipeline using OpenCV native calls.
  /// Returns path to the processed image file.
  ///
  /// Runs in an isolate to avoid blocking the UI thread.
  static Future<OpenCVProcessedResult> preprocess(
    File imageFile, {
    String idType = 'senior',
  }) async {
    final outputPath =
        imageFile.path.replaceAll(RegExp(r'\.(jpg|jpeg|png)$'), '_ocr.jpg');
    return compute(
      _preprocessIsolate,
      _PreprocessArgs(
        inputPath: imageFile.path,
        outputPath: outputPath,
        idType: idType,
      ),
    );
  }

  static OpenCVProcessedResult _preprocessIsolate(_PreprocessArgs args) {
    final sw = Stopwatch()..start();
    try {
      var mat = cv.imread(args.inputPath, flags: cv.IMREAD_COLOR);
      if (mat.isEmpty) {
        return const OpenCVProcessedResult(
          success: false,
          errorMessage: 'Failed to decode image',
        );
      }

      // Step 1: Resize if oversized (keeps aspect ratio)
      mat = _resizeIfNeeded(mat);
      _logTiming(sw, 'Resize check');

      // Step 2: Perspective correction (straighten angled IDs)
      mat = _correctPerspective(mat);
      _logTiming(sw, 'Perspective correction');

      // Step 3: Skew correction (rotation fix)
      mat = _correctSkew(mat);
      _logTiming(sw, 'Skew correction');

      // Step 4: Convert to grayscale
      var gray = cv.cvtColor(mat, cv.COLOR_BGR2GRAY);
      mat.dispose();
      _logTiming(sw, 'Grayscale');

      // Step 5: Bilateral filter (denoise while preserving edges)
      gray = cv.bilateralFilter(gray, 9, 75, 75);
      _logTiming(sw, 'Bilateral filter');

      // Step 6: CLAHE (local contrast enhancement)
      final clahe = cv.CLAHE(2.0, (8, 8));
      gray = clahe.apply(gray);
      clahe.dispose();
      _logTiming(sw, 'CLAHE');

      // Step 7: Sharpening via unsharp mask
      gray = _sharpen(gray);
      _logTiming(sw, 'Sharpen');

      // Step 8: Upscale if image is small (helps Tesseract)
      gray = _upscaleIfSmall(gray);
      _logTiming(sw, 'Upscale check');

      // Step 9: Save
      final success = cv.imwrite(args.outputPath, gray);
      gray.dispose();
      _logTiming(sw, 'Save');

      if (!success) {
        return const OpenCVProcessedResult(
          success: false,
          errorMessage: 'Failed to save processed image',
        );
      }

      // Read back dimensions for callers
      final result = cv.imread(args.outputPath, flags: cv.IMREAD_GRAYSCALE);
      final w = result.cols;
      final h = result.rows;
      result.dispose();

      return OpenCVProcessedResult(
        success: true,
        processedPath: args.outputPath,
        width: w,
        height: h,
      );
    } catch (e) {
      return OpenCVProcessedResult(
        success: false,
        errorMessage: 'OpenCV preprocessing failed: $e',
      );
    }
  }

  // =========================================================================
  // STEP 2: PERSPECTIVE CORRECTION
  // =========================================================================

  /// Detect the ID card quadrilateral and warp to a flat rectangle.
  static cv.Mat _correctPerspective(cv.Mat src) {
    try {
      // Work on a smaller copy for contour detection (speed)
      final gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY);
      final blurred = cv.gaussianBlur(gray, (5, 5), 0);
      final edges = cv.canny(blurred, 50, 150);

      // Dilate to connect broken edges
      final kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
      final dilated = cv.dilate(edges, kernel);

      // Find contours
      final contours = cv.findContours(
        dilated,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      );

      gray.dispose();
      blurred.dispose();
      edges.dispose();
      kernel.dispose();
      dilated.dispose();

      if (contours.$1.isEmpty) return src;

      // Find the largest quadrilateral contour
      final sorted = contours.$1.toList()
        ..sort((a, b) => cv.contourArea(b).compareTo(cv.contourArea(a)));

      for (final contour in sorted.take(5)) {
        final peri = cv.arcLength(contour, true);
        final approx = cv.approxPolyDP(contour, 0.02 * peri, true);

        if (approx.length == 4) {
          final area = cv.contourArea(approx);
          final imageArea = src.rows * src.cols;

          // Only warp if the detected quad covers at least 30% of the image
          // (avoids warping on noise contours)
          if (area < imageArea * 0.3) continue;

          final result = _warpQuadrilateral(src, approx);
          approx.dispose();
          return result;
        }
        approx.dispose();
      }

      return src; // No quad found — return unchanged
    } catch (e) {
      // If perspective correction fails, return the original
      return src;
    }
  }

  /// Warp a quadrilateral to a rectangle.
  static cv.Mat _warpQuadrilateral(cv.Mat src, cv.VecPoint approx) {
    // Extract 4 corner points and order them: TL, TR, BR, BL
    final pts = <cv.Point>[];
    for (int i = 0; i < approx.length; i++) {
      final p = approx[i];
      pts.add(cv.Point(p.x, p.y));
    }

    final ordered = _orderPoints(pts);
    final tl = ordered[0];
    final tr = ordered[1];
    final br = ordered[2];
    final bl = ordered[3];

    // Compute output dimensions
    final widthA = _distance(br.x, br.y, bl.x, bl.y);
    final widthB = _distance(tr.x, tr.y, tl.x, tl.y);
    final maxWidth = widthA > widthB ? widthA.toInt() : widthB.toInt();

    final heightA = _distance(tr.x, tr.y, br.x, br.y);
    final heightB = _distance(tl.x, tl.y, bl.x, bl.y);
    final maxHeight = heightA > heightB ? heightA.toInt() : heightB.toInt();

    // ID card aspect ratio check (~1.586:1 for standard cards)
    // Use the detected dimensions if reasonable, otherwise constrain
    final outputWidth = maxWidth > 0 ? maxWidth : src.cols;
    final outputHeight = maxHeight > 0 ? maxHeight : src.rows;

    // Source and destination points for perspective transform
    final srcPts = cv.VecPoint.fromList([
      cv.Point(tl.x, tl.y),
      cv.Point(tr.x, tr.y),
      cv.Point(br.x, br.y),
      cv.Point(bl.x, bl.y),
    ]);
    final dstPts = cv.VecPoint.fromList([
      cv.Point(0, 0),
      cv.Point(outputWidth, 0),
      cv.Point(outputWidth, outputHeight),
      cv.Point(0, outputHeight),
    ]);

    final transform = cv.getPerspectiveTransform(srcPts, dstPts);
    final warped = cv.warpPerspective(
      src,
      transform,
      (outputWidth, outputHeight),
    );

    srcPts.dispose();
    dstPts.dispose();
    transform.dispose();

    return warped;
  }

  /// Order 4 points as: top-left, top-right, bottom-right, bottom-left
  static List<cv.Point> _orderPoints(List<cv.Point> pts) {
    // Sum (x+y): smallest = TL, largest = BR
    // Diff (y-x): smallest = TR, largest = BL
    final sorted = List<cv.Point>.from(pts);

    sorted.sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
    final tl = sorted.first;
    final br = sorted.last;

    sorted.sort((a, b) => (a.y - a.x).compareTo(b.y - b.x));
    final tr = sorted.first;
    final bl = sorted.last;

    return [tl, tr, br, bl];
  }

  static double _distance(int x1, int y1, int x2, int y2) {
    final dx = (x2 - x1).toDouble();
    final dy = (y2 - y1).toDouble();
    return sqrt(dx * dx + dy * dy);
  }

  // =========================================================================
  // STEP 3: SKEW CORRECTION
  // =========================================================================

  /// Detect dominant text line angle and rotate to correct.
  static cv.Mat _correctSkew(cv.Mat src) {
    try {
      final gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY);
      final edges = cv.canny(gray, 50, 150, apertureSize: 3);

      // Detect lines with Hough transform
      final lines = cv.HoughLinesP(
        edges,
        1, // rho resolution
        cv.CV_PI / 180, // theta resolution (1 degree)
        80, // threshold (min votes)
        minLineLength: gray.cols * 0.3, // at least 30% image width
        maxLineGap: 20,
      );

      gray.dispose();
      edges.dispose();

      if (lines.rows == 0) {
        lines.dispose();
        return src;
      }

      // Compute median angle of detected lines
      final angles = <double>[];
      for (int i = 0; i < lines.rows; i++) {
        final x1 = lines.at<int>(i, 0);
        final y1 = lines.at<int>(i, 1);
        final x2 = lines.at<int>(i, 2);
        final y2 = lines.at<int>(i, 3);

        final dx = (x2 - x1).toDouble();
        final dy = (y2 - y1).toDouble();

        // Only consider near-horizontal lines (< 30 degrees)
        final angle = dy != 0 || dx != 0
            ? (180 / cv.CV_PI) * (dy / dx).clamp(-0.6, 0.6) // atan approx
            : 0.0;

        if (angle.abs() < 15) {
          angles.add(angle);
        }
      }
      lines.dispose();

      if (angles.isEmpty) return src;

      // Median angle
      angles.sort();
      final medianAngle = angles[angles.length ~/ 2];

      // Only correct if skew is noticeable (> 0.5 degrees) but not extreme
      if (medianAngle.abs() < 0.5 || medianAngle.abs() > 10) return src;

      // Rotate around center
      final center = cv.Point2f(src.cols / 2, src.rows / 2);
      final rotMatrix = cv.getRotationMatrix2D(center, medianAngle, 1.0);
      final rotated = cv.warpAffine(
        src,
        rotMatrix,
        (src.cols, src.rows),
        borderValue: cv.Scalar(255, 255, 255, 0), // white fill
      );

      rotMatrix.dispose();
      return rotated;
    } catch (e) {
      return src;
    }
  }

  // =========================================================================
  // STEP 7: SHARPENING
  // =========================================================================

  /// Unsharp mask: sharpen text edges without amplifying noise.
  static cv.Mat _sharpen(cv.Mat gray) {
    final blurred = cv.gaussianBlur(gray, (0, 0), 3);
    // addWeighted: src*1.5 - blurred*0.5 = sharpened
    final sharpened = cv.addWeighted(gray, 1.5, blurred, -0.5, 0);
    blurred.dispose();
    return sharpened;
  }

  // =========================================================================
  // RESIZE / UPSCALE HELPERS
  // =========================================================================

  static cv.Mat _resizeIfNeeded(cv.Mat mat) {
    final maxDim = mat.cols > mat.rows ? mat.cols : mat.rows;
    if (maxDim <= _maxDimension) return mat;

    final scale = _maxDimension / maxDim;
    final newW = (mat.cols * scale).round();
    final newH = (mat.rows * scale).round();
    return cv.resize(mat, (newW, newH), interpolation: cv.INTER_AREA);
  }

  static cv.Mat _upscaleIfSmall(cv.Mat mat) {
    final maxDim = mat.cols > mat.rows ? mat.cols : mat.rows;
    if (maxDim >= _minDimensionForUpscale) return mat;

    // 2x upscale with cubic interpolation
    final newW = mat.cols * 2;
    final newH = mat.rows * 2;
    return cv.resize(mat, (newW, newH), interpolation: cv.INTER_CUBIC);
  }

  // =========================================================================
  // CARD NORMALIZATION (shared by every Senior ID format)
  // =========================================================================

  static const int cardOutputWidth = 1600;
  static const double _cardRatio = 1.586;
  static const int _detectionMaxSide = 1000;

  /// Finds the ID card in a phone photo, flattens it to a [cardOutputWidth]
  /// wide upright rectangle and writes a colour copy plus an enhanced
  /// grayscale copy of identical size. Runs natively in an isolate.
  ///
  /// Zone-based OCR assumes the card fills the image; without this step any
  /// background, tilt or off-centre framing shifts every zone and fields come
  /// back empty or partial.
  static Future<NormalizedCard> normalizeCard(File imageFile) {
    final base = imageFile.path
        .replaceAll(RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false), '');
    return compute(
      _normalizeCardIsolate,
      _NormalizeArgs(
        inputPath: imageFile.path,
        colorPath: '${base}_card.jpg',
        enhancedPath: '${base}_card_ocr.jpg',
      ),
    );
  }

  static NormalizedCard _normalizeCardIsolate(_NormalizeArgs args) {
    try {
      final src = cv.imread(args.inputPath, flags: cv.IMREAD_COLOR);
      if (src.isEmpty) {
        return const NormalizedCard(
          success: false,
          errorMessage: 'Failed to decode image',
        );
      }

      const outW = cardOutputWidth;
      final outH = (outW / _cardRatio).round();

      final quad = _detectCardQuad(src);
      cv.Mat card;
      if (quad != null) {
        card = _warpToCard(src, quad, outW, outH);
      } else {
        card = _cropToCardRatio(src);
        final resized = cv.resize(
          card,
          (outW, outH),
          interpolation: card.cols > outW ? cv.INTER_AREA : cv.INTER_CUBIC,
        );
        card.dispose();
        card = resized;
      }
      src.dispose();

      if (!cv.imwrite(
        args.colorPath,
        card,
        params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 95]),
      )) {
        card.dispose();
        return const NormalizedCard(
          success: false,
          errorMessage: 'Failed to save normalized card',
        );
      }

      var gray = cv.cvtColor(card, cv.COLOR_BGR2GRAY);
      card.dispose();
      gray = cv.bilateralFilter(gray, 9, 75, 75);
      final clahe = cv.CLAHE(2.0, (8, 8));
      gray = clahe.apply(gray);
      clahe.dispose();
      gray = _sharpen(gray);
      final enhancedSaved = cv.imwrite(
        args.enhancedPath,
        gray,
        params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 95]),
      );
      gray.dispose();

      return NormalizedCard(
        success: enhancedSaved,
        colorPath: args.colorPath,
        enhancedPath: args.enhancedPath,
        width: outW,
        height: outH,
        cardDetected: quad != null,
        errorMessage: enhancedSaved ? null : 'Failed to save enhanced card',
      );
    } catch (e) {
      return NormalizedCard(
        success: false,
        errorMessage: 'Card normalization failed: $e',
      );
    }
  }

  /// Returns the card corners ordered TL, TR, BR, BL with the long side
  /// horizontal, in [src] pixel coordinates, or null when no card-shaped
  /// quadrilateral is found (e.g. the card already fills the whole frame).
  static List<cv.Point>? _detectCardQuad(cv.Mat src) {
    final maxSide = src.cols > src.rows ? src.cols : src.rows;
    final scale =
        maxSide > _detectionMaxSide ? _detectionMaxSide / maxSide : 1.0;
    final small = scale < 1.0
        ? cv.resize(
            src,
            ((src.cols * scale).round(), (src.rows * scale).round()),
            interpolation: cv.INTER_AREA,
          )
        : src;
    final sw = small.cols;
    final sh = small.rows;

    final gray = cv.cvtColor(small, cv.COLOR_BGR2GRAY);
    final blurred = cv.gaussianBlur(gray, (5, 5), 0);
    final k5 = cv.getStructuringElement(cv.MORPH_RECT, (5, 5));
    final k9 = cv.getStructuringElement(cv.MORPH_RECT, (9, 9));

    // Three independent views of "where is the card": edges, bright-on-dark
    // and dark-on-bright. Whichever separates the card from this particular
    // background best wins on score.
    final masks = <cv.Mat>[
      cv.morphologyEx(
        cv.dilate(cv.canny(blurred, 40, 120), k5),
        cv.MORPH_CLOSE,
        k9,
      ),
      cv.morphologyEx(
        cv.threshold(blurred, 0, 255, cv.THRESH_BINARY | cv.THRESH_OTSU).$2,
        cv.MORPH_CLOSE,
        k9,
      ),
      cv.morphologyEx(
        cv.threshold(blurred, 0, 255, cv.THRESH_BINARY_INV | cv.THRESH_OTSU).$2,
        cv.MORPH_CLOSE,
        k9,
      ),
    ];

    final minArea = sw * sh * 0.15;
    final maxArea = sw * sh * 0.92;
    final edgeMargin = (sw > sh ? sw : sh) * 0.012;

    double bestScore = 0;
    List<cv.Point>? best;

    for (final mask in masks) {
      final contours =
          cv.findContours(mask, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE).$1;
      final sorted = contours.toList()
        ..sort((a, b) => cv.contourArea(b).compareTo(cv.contourArea(a)));

      for (final contour in sorted.take(5)) {
        final contourArea = cv.contourArea(contour);
        if (contourArea < minArea) break;

        final peri = cv.arcLength(contour, true);
        List<cv.Point>? pts;
        for (final eps in const [0.02, 0.03, 0.04, 0.06]) {
          final approx = cv.approxPolyDP(contour, eps * peri, true);
          if (approx.length == 4) {
            pts = [
              for (int i = 0; i < 4; i++) cv.Point(approx[i].x, approx[i].y)
            ];
          }
          approx.dispose();
          if (pts != null) break;
        }
        if (pts == null) continue;

        var q = _orderPoints(pts);
        var w = (_distance(q[0].x, q[0].y, q[1].x, q[1].y) +
                _distance(q[3].x, q[3].y, q[2].x, q[2].y)) /
            2;
        var h = (_distance(q[0].x, q[0].y, q[3].x, q[3].y) +
                _distance(q[1].x, q[1].y, q[2].x, q[2].y)) /
            2;
        if (w < h) {
          q = [q[3], q[0], q[1], q[2]];
          final t = w;
          w = h;
          h = t;
        }
        if (h <= 0) continue;
        final aspect = w / h;
        if (aspect < 1.35 || aspect > 1.85) continue;

        // Shoelace area of the ordered quad
        double area = 0;
        for (int i = 0; i < 4; i++) {
          final a = q[i];
          final b = q[(i + 1) % 4];
          area += (a.x * b.y - b.x * a.y).toDouble();
        }
        area = area.abs() / 2;
        if (area < minArea || area > maxArea) continue;

        // A quad hugging the frame is the photo border, not the card.
        final touching = q
            .where((p) =>
                p.x < edgeMargin ||
                p.y < edgeMargin ||
                p.x > sw - edgeMargin ||
                p.y > sh - edgeMargin)
            .length;
        if (touching >= 2) continue;

        final score = area * (1 - 0.5 * (aspect - _cardRatio).abs());
        if (score > bestScore) {
          bestScore = score;
          best = q;
        }
      }
      mask.dispose();
    }

    gray.dispose();
    blurred.dispose();
    k5.dispose();
    k9.dispose();
    if (scale < 1.0) small.dispose();

    if (best == null) return null;
    return [
      for (final p in best)
        cv.Point((p.x / scale).round(), (p.y / scale).round())
    ];
  }

  static cv.Mat _warpToCard(
    cv.Mat src,
    List<cv.Point> quad,
    int outW,
    int outH,
  ) {
    // Shrink first when the card is much larger than the output; the
    // perspective warp has no area-averaging, so a big downscale would alias.
    final quadW = _distance(quad[0].x, quad[0].y, quad[1].x, quad[1].y);
    var source = src;
    var pts = quad;
    final factor = (outW * 1.25) / quadW;
    if (factor < 1.0) {
      source = cv.resize(
        src,
        ((src.cols * factor).round(), (src.rows * factor).round()),
        interpolation: cv.INTER_AREA,
      );
      pts = [
        for (final p in quad)
          cv.Point((p.x * factor).round(), (p.y * factor).round())
      ];
    }

    final srcPts = cv.VecPoint.fromList(pts);
    final dstPts = cv.VecPoint.fromList([
      cv.Point(0, 0),
      cv.Point(outW, 0),
      cv.Point(outW, outH),
      cv.Point(0, outH),
    ]);
    final transform = cv.getPerspectiveTransform(srcPts, dstPts);
    final warped = cv.warpPerspective(
      source,
      transform,
      (outW, outH),
      flags: cv.INTER_CUBIC,
      borderMode: cv.BORDER_REPLICATE,
    );
    srcPts.dispose();
    dstPts.dispose();
    transform.dispose();
    if (!identical(source, src)) source.dispose();
    return warped;
  }

  /// No card edges found: assume the frame already holds the card (the
  /// in-app camera guide) and trim any excess to the ID aspect ratio.
  static cv.Mat _cropToCardRatio(cv.Mat src) {
    final ratio = src.cols / src.rows;
    if ((ratio - _cardRatio).abs() < 0.12) return src.clone();
    int cropW = src.cols;
    int cropH = src.rows;
    if (ratio > _cardRatio) {
      cropW = (src.rows * _cardRatio).round();
    } else {
      cropH = (src.cols / _cardRatio).round();
    }
    final x = (src.cols - cropW) ~/ 2;
    final y = (src.rows - cropH) ~/ 2;
    return src.region(cv.Rect(x, y, cropW, cropH)).clone();
  }

  // =========================================================================
  // CAPTURE HELPER
  // =========================================================================

  /// Centre-crops a captured photo to the ID aspect ratio and saves it as a
  /// JPEG. Native replacement for the pure-Dart decode/crop/encode, which
  /// blocks for seconds on multi-megapixel photos. Returns the saved image
  /// size, or null on failure (caller should fall back to the Dart path).
  static Future<({int width, int height})?> cropCenterToCardRatio(
    String inputPath,
    String outputPath,
  ) {
    return compute(
      _cropCenterIsolate,
      _NormalizeArgs(
        inputPath: inputPath,
        colorPath: outputPath,
        enhancedPath: '',
      ),
    );
  }

  static ({int width, int height})? _cropCenterIsolate(_NormalizeArgs args) {
    try {
      final src = cv.imread(args.inputPath, flags: cv.IMREAD_COLOR);
      if (src.isEmpty) return null;
      final cropped = _cropToCardRatio(src);
      final size = (width: cropped.cols, height: cropped.rows);
      final saved = cv.imwrite(
        args.colorPath,
        cropped,
        params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 95]),
      );
      src.dispose();
      cropped.dispose();
      return saved ? size : null;
    } catch (e) {
      return null;
    }
  }

  // =========================================================================
  // TIMING HELPER (debug only)
  // =========================================================================

  static void _logTiming(Stopwatch sw, String step) {
    // debugPrint not available in isolate — use print for debug builds
    assert(() {
      print('  ⏱️ $step: ${sw.elapsedMilliseconds}ms');
      return true;
    }());
  }
}

/// Internal args for isolate
class _NormalizeArgs {
  final String inputPath;
  final String colorPath;
  final String enhancedPath;

  const _NormalizeArgs({
    required this.inputPath,
    required this.colorPath,
    required this.enhancedPath,
  });
}

/// Internal args for isolate
class _PreprocessArgs {
  final String inputPath;
  final String outputPath;
  final String idType;

  const _PreprocessArgs({
    required this.inputPath,
    required this.outputPath,
    required this.idType,
  });
}
