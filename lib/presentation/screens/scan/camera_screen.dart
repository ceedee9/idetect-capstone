// =============================================================================
// FILE: lib/presentation/screens/scan/camera_screen.dart
// PURPOSE: Native camera capture with quality guidance for ID scanning
// FEATURES: Native camera, quality preview, auto-crop, real-time feedback
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../../core/constants/app_design_system.dart';
import 'processing_screen.dart';

/// Simplified camera screen using native camera app
/// This provides better performance and quality than custom camera view
class CameraScreen extends StatefulWidget {
  final String idType; // 'senior' or 'pwd'

  const CameraScreen({super.key, required this.idType});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _capturedImage;
  bool _isProcessing = false;

  // Quality assessment results
  String? _qualityMessage;
  Color _qualityColor = Colors.grey;
  double _qualityScore = 0.0;
  bool _isQualityGood = false;

  @override
  void initState() {
    super.initState();
    // Show guidance immediately, then open camera
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showGuidanceDialog();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // =============================================================================
  // GUIDANCE DIALOG
  // =============================================================================

  void _showGuidanceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.camera_alt, color: AppDesignSystem.primaryBlue),
            SizedBox(width: AppDesignSystem.spaceXS),
            const Text('Photography Tips'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTip(
                  Icons.wb_sunny, 'Use BRIGHT LIGHTING or natural daylight'),
              _buildTip(Icons.flash_on, 'Enable flash if indoors'),
              _buildTip(Icons.filter_none, 'Place ID on DARK, FLAT surface'),
              _buildTip(Icons.center_focus_strong, 'Fill entire frame with ID'),
              _buildTip(Icons.pause, 'Hold phone STEADY for 2 seconds'),
              _buildTip(Icons.straighten, 'Keep ID flat and straight'),
              SizedBox(height: AppDesignSystem.spaceMD),
              Container(
                padding: EdgeInsets.all(AppDesignSystem.spaceSM),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: AppDesignSystem.cardRadius,
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber.shade900),
                    SizedBox(width: AppDesignSystem.spaceXS),
                    Expanded(
                      child: Text(
                        'Quality is critical for accurate data extraction!',
                        style: AppDesignSystem.bodySmall.copyWith(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openNativeCamera();
            },
            style: AppDesignSystem.primaryButton,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Open Camera'),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppDesignSystem.spaceSM),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppDesignSystem.primaryBlue),
          SizedBox(width: AppDesignSystem.spaceXS),
          Expanded(
            child: Text(
              text,
              style: AppDesignSystem.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================================
  // NATIVE CAMERA CAPTURE (Better Performance)
  // =============================================================================

  Future<void> _openNativeCamera() async {
    try {
      setState(() {
        _isProcessing = true;
      });

      // Use native camera with HIGH quality
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 95, // High quality for better OCR
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        final imageFile = File(photo.path);

        // Assess quality immediately
        await _assessImageQuality(imageFile);

        setState(() {
          _capturedImage = imageFile;
        });
      } else {
        // User cancelled
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
      _showErrorSnackBar('Failed to capture image: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // =============================================================================
  // IMAGE QUALITY ASSESSMENT
  // =============================================================================

  Future<void> _assessImageQuality(File imageFile) async {
    try {
      debugPrint('📊 Assessing image quality...');

      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        _qualityMessage = 'Failed to read image';
        _qualityColor = Colors.red;
        _qualityScore = 0.0;
        _isQualityGood = false;
        return;
      }

      // Quality checks
      double score = 100.0;
      List<String> issues = [];
      List<String> good = [];

      // 1. Resolution check
      final resolution = image.width * image.height;
      if (resolution < 500000) {
        issues.add('Resolution too low');
        score -= 30;
      } else if (resolution > 2000000) {
        good.add('Excellent resolution');
      } else {
        good.add('Good resolution');
      }

      // 2. Brightness check
      final brightness = _calculateBrightness(image);
      if (brightness < 40) {
        issues.add('Too dark - use flash');
        score -= 25;
      } else if (brightness > 220) {
        issues.add('Too bright - reduce glare');
        score -= 20;
      } else if (brightness >= 80 && brightness <= 180) {
        good.add('Good lighting');
      }

      // 3. Sharpness check
      final sharpness = _calculateSharpness(image);
      if (sharpness < 30) {
        issues.add('Blurry - hold steady');
        score -= 30;
      } else if (sharpness > 80) {
        good.add('Sharp and clear');
      } else {
        good.add('Acceptable sharpness');
      }

      // 4. Contrast check
      final contrast = _calculateContrast(image);
      if (contrast < 20) {
        issues.add('Low contrast - use dark background');
        score -= 15;
      } else if (contrast > 50) {
        good.add('Good contrast');
      }

      _qualityScore = score.clamp(0, 100);
      _isQualityGood = score >= 70;

      if (_isQualityGood) {
        _qualityMessage = good.join(' • ');
        _qualityColor = AppDesignSystem.statusValid;
      } else {
        _qualityMessage = issues.join(' • ');
        _qualityColor = AppDesignSystem.statusInvalid;
      }

      debugPrint('✅ Quality Score: $_qualityScore%');
      debugPrint('📋 Message: $_qualityMessage');
    } catch (e) {
      debugPrint('⚠️ Quality assessment failed: $e');
      _qualityMessage = 'Could not assess quality';
      _qualityColor = Colors.orange;
      _qualityScore = 50.0;
      _isQualityGood = false;
    }
  }

  double _calculateBrightness(img.Image image) {
    int total = 0;
    int count = 0;

    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        final brightness =
            (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
        total += brightness.toInt();
        count++;
      }
    }

    return count > 0 ? total / count : 0;
  }

  double _calculateSharpness(img.Image image) {
    final grayscale = img.grayscale(image);
    double variance = 0;
    int count = 0;

    for (int y = 1; y < grayscale.height - 1; y += 5) {
      for (int x = 1; x < grayscale.width - 1; x += 5) {
        final curr = grayscale.getPixel(x, y).r.toInt();
        final right = grayscale.getPixel(x + 1, y).r.toInt();
        final bottom = grayscale.getPixel(x, y + 1).r.toInt();

        final laplacian = (4 * curr - right - bottom).abs();
        variance += laplacian * laplacian;
        count++;
      }
    }

    return count > 0 ? variance / count : 0;
  }

  double _calculateContrast(img.Image image) {
    int minBrightness = 255;
    int maxBrightness = 0;

    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        final brightness =
            ((0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toInt());
        minBrightness = brightness < minBrightness ? brightness : minBrightness;
        maxBrightness = brightness > maxBrightness ? brightness : maxBrightness;
      }
    }

    return (maxBrightness - minBrightness).toDouble();
  }

  /// Crop the captured image to only the ID area (removes background)
  Future<File> _cropImageToIDArea(File originalImage) async {
    try {
      debugPrint('🔲 Cropping image to ID area...');

      final bytes = await originalImage.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        debugPrint('⚠️ Failed to decode image, returning original');
        return originalImage;
      }

      // Center crop with ID card ratio (1.586:1)
      final imageWidth = image.width;
      final imageHeight = image.height;
      final targetRatio = 0.63;
      final targetWidth = imageWidth * 0.85;
      final targetHeight = targetWidth * targetRatio;

      final cropX = ((imageWidth - targetWidth) / 2).toInt();
      final cropY = ((imageHeight - targetHeight) / 2).toInt();

      final croppedImage = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: targetWidth.toInt(),
        height: targetHeight.toInt(),
      );

      final croppedPath = originalImage.path.replaceAll('.jpg', '_cropped.jpg');
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 95));

      debugPrint('✅ Image cropped successfully');
      return croppedFile;
    } catch (e) {
      debugPrint('⚠️ Crop failed: $e, using original');
      return originalImage;
    }
  }

  // =============================================================================
  // PROCESS IMAGE
  // =============================================================================

  void _processImage() async {
    if (_capturedImage == null) return;

    // Crop image before processing
    final croppedImage = await _cropImageToIDArea(_capturedImage!);

    if (!mounted) return;

    // Navigate to processing screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProcessingScreen(
          imagePath: croppedImage.path,
          idType: widget.idType,
        ),
      ),
    );
  }

  // =============================================================================
  // BUILD UI
  // =============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundLight,
      appBar: AppBar(
        title: Text(
            'Scan ${widget.idType == 'senior' ? 'Senior Citizen' : 'PWD'} ID'),
        backgroundColor: AppDesignSystem.primaryBlue,
        foregroundColor: AppDesignSystem.textOnPrimary,
      ),
      body:
          _capturedImage == null ? _buildWaitingView() : _buildQualityPreview(),
    );
  }

  Widget _buildWaitingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt,
            size: 80,
            color: AppDesignSystem.primaryBlue.withOpacity(0.5),
          ),
          SizedBox(height: AppDesignSystem.spaceMD),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            Text(
              'Opening camera...',
              style: AppDesignSystem.bodyLarge.copyWith(
                color: AppDesignSystem.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQualityPreview() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppDesignSystem.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quality Score Card
          Container(
            padding: EdgeInsets.all(AppDesignSystem.spaceMD),
            decoration: BoxDecoration(
              color: _qualityColor.withOpacity(0.1),
              borderRadius: AppDesignSystem.cardRadius,
              border: Border.all(color: _qualityColor, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _qualityColor.withOpacity(0.2),
                      ),
                      child: Center(
                        child: Text(
                          '${_qualityScore.toInt()}%',
                          style: AppDesignSystem.heading3.copyWith(
                            color: _qualityColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppDesignSystem.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isQualityGood ? 'Good Quality!' : 'Quality Issue',
                            style: AppDesignSystem.heading4.copyWith(
                              color: _qualityColor,
                            ),
                          ),
                          SizedBox(height: AppDesignSystem.spaceXXS),
                          Text(
                            _qualityMessage ?? 'Analyzing...',
                            style: AppDesignSystem.bodySmall.copyWith(
                              color: _qualityColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isQualityGood ? Icons.check_circle : Icons.warning,
                      color: _qualityColor,
                      size: 32,
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: AppDesignSystem.spaceMD),

          // Image Preview
          Container(
            decoration: BoxDecoration(
              borderRadius: AppDesignSystem.cardRadius,
              boxShadow: AppDesignSystem.shadowMD,
            ),
            child: ClipRRect(
              borderRadius: AppDesignSystem.cardRadius,
              child: Image.file(
                _capturedImage!,
                fit: BoxFit.contain,
              ),
            ),
          ),

          SizedBox(height: AppDesignSystem.spaceLG),

          // Action Buttons
          if (_isQualityGood)
            ElevatedButton.icon(
              onPressed: _processImage,
              style: AppDesignSystem.primaryButton,
              icon: const Icon(Icons.check_circle),
              label: const Text('Process This Image'),
            )
          else
            Column(
              children: [
                OutlinedButton.icon(
                  onPressed: _processImage,
                  style: AppDesignSystem.secondaryButton,
                  icon: const Icon(Icons.science),
                  label: const Text('Try Processing Anyway'),
                ),
                SizedBox(height: AppDesignSystem.spaceSM),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _capturedImage = null;
                    });
                    _openNativeCamera();
                  },
                  style: AppDesignSystem.primaryButton,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Retake with Better Quality'),
                ),
              ],
            ),

          SizedBox(height: AppDesignSystem.spaceSM),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // =============================================================================
  // UI HELPER METHODS
  // =============================================================================

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
