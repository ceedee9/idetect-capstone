// =============================================================================
// FILE: lib/presentation/screens/scan/in_app_camera_screen.dart
// PURPOSE: In-app camera with live preview for ID scanning
// FEATURES: Live camera preview, real-time guidance, quality overlay, capture
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_design_system.dart';
import 'processing_screen.dart';

/// In-app camera screen with live preview and guidance overlay
class InAppCameraScreen extends StatefulWidget {
  final String idType; // 'senior' or 'pwd'

  const InAppCameraScreen({super.key, required this.idType});

  @override
  State<InAppCameraScreen> createState() => _InAppCameraScreenState();
}

class _InAppCameraScreenState extends State<InAppCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _flashEnabled = false;

  // Quality guidance
  bool _showGuidance = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    // App state changed before we got the chance to initialize
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  // =============================================================================
  // CAMERA INITIALIZATION
  // =============================================================================

  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No cameras available');
        return;
      }

      // Find the back camera (preferred for ID scanning)
      CameraDescription? backCamera;
      for (var camera in _cameras!) {
        if (camera.lensDirection == CameraLensDirection.back) {
          backCamera = camera;
          break;
        }
      }

      // Fallback to first available camera
      final selectedCamera = backCamera ?? _cameras!.first;

      // Initialize camera controller with high quality settings
      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high, // High quality for OCR
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      // Set optimal settings for document scanning
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      _showError('Camera initialization failed: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =============================================================================
  // CAMERA CONTROLS
  // =============================================================================

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      if (_flashEnabled) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _flashEnabled = !_flashEnabled;
      });
    } catch (e) {
      _showError('Flash toggle failed: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    try {
      setState(() {
        _isCapturing = true;
      });

      // Turn off flash mode before capture (use auto)
      if (_flashEnabled) {
        await _cameraController!.setFlashMode(FlashMode.auto);
      }

      // Capture the image
      final XFile photo = await _cameraController!.takePicture();

      // Process the captured image
      await _processImage(File(photo.path));
    } catch (e) {
      _showError('Capture failed: $e');
      setState(() {
        _isCapturing = false;
      });
    }
  }

  // =============================================================================
  // IMAGE PROCESSING
  // =============================================================================

  Future<void> _processImage(File imageFile) async {
    try {
      // Read image
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        _showError('Failed to process image');
        setState(() {
          _isCapturing = false;
        });
        return;
      }

      // Auto-crop to ID area (standard ID ratio is approximately 1.586:1)
      final croppedImage = _autoCropID(image);

      // Save the processed image
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final processedPath = '${tempDir.path}/id_${timestamp}_processed.jpg';

      // Save with high quality
      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(
        img.encodeJpg(croppedImage, quality: 95),
      );

      // Note: Quality assessment is performed in the processing screen
      // which has access to the full enhanced OCR pipeline

      if (mounted) {
        // Navigate to processing screen with all the OCR enhancements
        // Quality assessment is done internally in the processing screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProcessingScreen(
              imagePath: processedPath,
              idType: widget.idType,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Image processing failed: $e');
      setState(() {
        _isCapturing = false;
      });
    }
  }

  /// Auto-crop to ID area using edge detection
  img.Image _autoCropID(img.Image image) {
    // Standard ID card ratio (CR80: 85.6mm x 53.98mm ≈ 1.586:1)
    const targetRatio = 1.586;
    final imageRatio = image.width / image.height;

    // If image is already close to ID ratio, return as is
    if ((imageRatio - targetRatio).abs() < 0.1) {
      return image;
    }

    int cropWidth = image.width;
    int cropHeight = image.height;

    if (imageRatio > targetRatio) {
      // Image is too wide, crop width
      cropWidth = (image.height * targetRatio).toInt();
    } else {
      // Image is too tall, crop height
      cropHeight = (image.width / targetRatio).toInt();
    }

    // Center crop
    final x = (image.width - cropWidth) ~/ 2;
    final y = (image.height - cropHeight) ~/ 2;

    return img.copyCrop(image,
        x: x, y: y, width: cropWidth, height: cropHeight);
  }

  // Quality assessment is performed in processing_screen.dart which has
  // access to the full enhanced OCR pipeline with advanced preprocessing
  /*
  /// Assess image quality for OCR
  Map<String, dynamic> _assessImageQuality(img.Image image) {
    double score = 0.0;
    List<String> issues = [];

    // 1. Check resolution (need at least 2MP for good OCR)
    final megapixels = (image.width * image.height) / 1000000;
    if (megapixels >= 2) {
      score += 30;
    } else {
      issues.add('Low resolution');
    }

    // 2. Check brightness
    int totalBrightness = 0;
    int sampleCount = 0;
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        totalBrightness += ((r + g + b) / 3).toInt();
        sampleCount++;
      }
    }
    final avgBrightness = totalBrightness / sampleCount;

    if (avgBrightness >= 80 && avgBrightness <= 180) {
      score += 25;
    } else if (avgBrightness < 60) {
      issues.add('Too dark');
    } else if (avgBrightness > 200) {
      issues.add('Too bright');
    }

    // 3. Check sharpness (simplified Laplacian)
    double sharpness = 0;
    for (int y = 1; y < image.height - 1; y += 20) {
      for (int x = 1; x < image.width - 1; x += 20) {
        final center = image.getPixel(x, y);
        final right = image.getPixel(x + 1, y);
        final bottom = image.getPixel(x, y + 1);

        final centerGray = (center.r + center.g + center.b) / 3;
        final rightGray = (right.r + right.g + right.b) / 3;
        final bottomGray = (bottom.r + bottom.g + bottom.b) / 3;

        sharpness += ((centerGray - rightGray).abs() +
                (centerGray - bottomGray).abs())
            .toDouble();
      }
    }
    sharpness /= ((image.width / 20) * (image.height / 20));

    if (sharpness > 30) {
      score += 25;
    } else {
      issues.add('Blurry image');
    }

    // 4. Check contrast
    int minBrightness = 255;
    int maxBrightness = 0;
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        final brightness = ((pixel.r + pixel.g + pixel.b) / 3).toInt();
        minBrightness = brightness < minBrightness ? brightness : minBrightness;
        maxBrightness = brightness > maxBrightness ? brightness : maxBrightness;
      }
    }
    final contrast = maxBrightness - minBrightness;

    if (contrast > 80) {
      score += 20;
    } else {
      issues.add('Low contrast');
    }

    // Build message
    String message;
    if (score >= 80) {
      message = 'Excellent quality!';
    } else if (score >= 60) {
      message = 'Good quality';
    } else if (score >= 40) {
      message = 'Fair quality - ${issues.join(", ")}';
    } else {
      message = 'Poor quality - ${issues.join(", ")}';
    }

    return {
      'score': score,
      'message': message,
      'issues': issues,
    };
  }
  */

  // =============================================================================
  // UI BUILD
  // =============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (_isInitialized && _cameraController != null)
            _buildCameraPreview()
          else
            _buildLoadingState(),

          // Guidance Overlay
          if (_showGuidance) _buildGuidanceOverlay(),

          // Top Bar (Close, Flash)
          _buildTopBar(),

          // Bottom Bar (Capture Button)
          _buildBottomBar(),

          // Capture Progress
          if (_isCapturing) _buildCaptureProgress(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final cameraAspectRatio = _cameraController!.value.aspectRatio;

    return Center(
      child: AspectRatio(
        aspectRatio: cameraAspectRatio,
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppDesignSystem.primaryBlue,
          ),
          SizedBox(height: AppDesignSystem.spaceMD),
          Text(
            'Initializing camera...',
            style: AppDesignSystem.bodyMedium.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceOverlay() {
    return Container(
      color: Colors.black87,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppDesignSystem.spaceLG),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 64,
                  color: AppDesignSystem.primaryBlue,
                ),
                SizedBox(height: AppDesignSystem.spaceLG),
                Text(
                  'ID Scanning Tips',
                  style: AppDesignSystem.heading2.copyWith(
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: AppDesignSystem.spaceLG),
                _buildGuidanceTip(Icons.wb_sunny, 'Use bright lighting'),
                _buildGuidanceTip(
                    Icons.filter_none, 'Place ID on dark surface'),
                _buildGuidanceTip(
                    Icons.center_focus_strong, 'Fill frame with ID'),
                _buildGuidanceTip(Icons.pause, 'Hold steady'),
                _buildGuidanceTip(Icons.straighten, 'Keep ID flat'),
                SizedBox(height: AppDesignSystem.spaceLG),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showGuidance = false;
                    });
                  },
                  style: AppDesignSystem.primaryButton,
                  child: const Text('Got It!'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuidanceTip(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppDesignSystem.spaceSM),
      child: Row(
        children: [
          Icon(icon, color: AppDesignSystem.primaryBlue, size: 24),
          SizedBox(width: AppDesignSystem.spaceSM),
          Text(
            text,
            style: AppDesignSystem.bodyMedium.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppDesignSystem.spaceMD),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Close button
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              color: Colors.white,
              iconSize: 32,
            ),
            // Flash toggle
            if (_isInitialized)
              IconButton(
                onPressed: _toggleFlash,
                icon: Icon(_flashEnabled ? Icons.flash_on : Icons.flash_off),
                color: _flashEnabled ? Colors.yellow : Colors.white,
                iconSize: 32,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.all(AppDesignSystem.spaceLG),
          child: Column(
            children: [
              // ID Frame Guide
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.spaceSM,
                  vertical: AppDesignSystem.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Align ID within frame',
                  style: AppDesignSystem.bodySmall.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: AppDesignSystem.spaceLG),
              // Capture Button
              GestureDetector(
                onTap: _isInitialized && !_isCapturing ? _capturePhoto : null,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: AppDesignSystem.primaryBlue,
                      width: 4,
                    ),
                  ),
                  child: _isCapturing
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            color: AppDesignSystem.primaryBlue,
                            strokeWidth: 3,
                          ),
                        )
                      : Icon(
                          Icons.camera,
                          size: 40,
                          color: AppDesignSystem.primaryBlue,
                        ),
                ),
              ),
              SizedBox(height: AppDesignSystem.spaceSM),
              // Tip toggle
              TextButton(
                onPressed: () {
                  setState(() {
                    _showGuidance = !_showGuidance;
                  });
                },
                child: Text(
                  'Show Tips',
                  style: AppDesignSystem.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureProgress() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppDesignSystem.primaryBlue,
            ),
            SizedBox(height: AppDesignSystem.spaceMD),
            Text(
              'Processing image...',
              style: AppDesignSystem.bodyMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
